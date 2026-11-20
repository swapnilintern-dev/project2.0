// =============================================================================
// VS Arogya — Marketing · Bulk product upload API
//
// Posts a spreadsheet to POST /vsArogya/bulk-upload (multipart `file`) and maps
// the server's per-row result back into typed objects.
//
// The endpoint is role-guarded server-side (marketing/admin, from the signed
// JWT), so the request carries the session token.
//
// The server validates EVERY row independently and never fails the whole sheet
// because of one bad line: valid rows are inserted, invalid ones come back in
// `failedProducts` with the Excel row number and a reason. This service keeps
// that distinction rather than flattening it to a single success/failure, so
// the screen can show the user exactly what to fix.
//
// NEVER THROWS — failures come back as an [BulkUploadResult] with `success:
// false` and a user-safe message, matching the rest of the app's services.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import '../services/auth_service.dart';

/// One row the server refused, with the reason it gave.
class BulkUploadFailure {
  const BulkUploadFailure({
    this.row,
    this.title,
    this.batchNo,
    required this.reason,
  });

  /// 1-based row number in the Excel sheet (header is row 1). Absent for
  /// failures found during the database duplicate check rather than per-row
  /// parsing.
  final int? row;
  final String? title;
  final String? batchNo;
  final String reason;

  factory BulkUploadFailure.fromJson(Map<String, dynamic> j) =>
      BulkUploadFailure(
        row: j['row'] is num ? (j['row'] as num).toInt() : null,
        title: j['title']?.toString(),
        batchNo: j['batchNo']?.toString(),
        reason: (j['reason'] ?? 'Rejected').toString(),
      );

  /// "Row 4 · Title is required" — what the user needs to find the line.
  String get label {
    final where = row != null ? 'Row $row' : (batchNo ?? title ?? 'Row');
    final what = [title, batchNo].where((v) => (v ?? '').isNotEmpty).join(' · ');
    return what.isEmpty ? where : '$where · $what';
  }
}

/// The outcome of one upload.
class BulkUploadResult {
  const BulkUploadResult({
    required this.success,
    required this.message,
    this.totalRows = 0,
    this.uploaded = 0,
    this.failed = 0,
    this.failures = const [],
  });

  final bool success;
  final String message;
  final int totalRows;
  final int uploaded;
  final int failed;
  final List<BulkUploadFailure> failures;

  /// True when the server accepted the sheet but rejected some rows — the
  /// common case worth calling out, since it is neither a clean success nor a
  /// failure.
  bool get isPartial => uploaded > 0 && failed > 0;

  factory BulkUploadResult._error(String message) =>
      BulkUploadResult(success: false, message: message);
}

class BulkUploadApi {
  const BulkUploadApi();

  /// Parsing a large sheet and inserting hundreds of rows takes real time, and
  /// the host pays a cold start on the first request after an idle period.
  /// Generous, but BOUNDED.
  static const Duration _timeout = Duration(seconds: 120);

  /// Uploads [bytes] (an .xlsx/.xls/.csv file named [filename]).
  ///
  /// Bytes rather than a path because file_picker returns in-memory bytes on
  /// web and on Android's scoped storage, where a plain path may not be
  /// readable.
  Future<BulkUploadResult> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = AuthService.authToken;
    if (token == null || token.isEmpty) {
      return BulkUploadResult._error(
          'Your session has expired. Please sign in again.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.bulkUploadProducts),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename));

    if (AuthService.sessionCookie != null) {
      request.headers['Cookie'] = AuthService.sessionCookie!;
    }

    http.Response response;
    try {
      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      return BulkUploadResult._error(
          'The upload took too long. The sheet may be very large — try splitting it.');
    } catch (_) {
      return BulkUploadResult._error(
          'Cannot reach the server. Check your internet connection and try again.');
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return BulkUploadResult._error(
            'The server sent an unexpected response. Please try again.');
      }
      body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // A 401/403/500 from a middleware can arrive as HTML rather than JSON.
      if (response.statusCode == 401 || response.statusCode == 403) {
        return BulkUploadResult._error(
            'You are not allowed to upload products. Sign in as Marketing.');
      }
      return BulkUploadResult._error(
          'The server sent an unexpected response. Please try again.');
    }

    final failures = (body['failedProducts'] is List)
        ? (body['failedProducts'] as List)
            .whereType<Map>()
            .map((e) => BulkUploadFailure.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <BulkUploadFailure>[];

    return BulkUploadResult(
      success: body['success'] == true,
      message: (body['message'] ?? 'Upload finished').toString(),
      totalRows: _int(body['totalRows']),
      uploaded: _int(body['uploaded']),
      failed: _int(body['failed']),
      failures: failures,
    );
  }

  static int _int(Object? v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
}
