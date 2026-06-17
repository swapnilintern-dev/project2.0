// =============================================================================
// MediCaPlus — Vendor API Service
//
// Sends the vendor registration to the Express + MongoDB backend:
//   POST {baseUrl}/vsArogya/register-vendor   (multipart/form-data)
//
// Field names and the multipart file keys below MUST match the backend
// controller exactly (server/controller/userController.js) — do not rename them.
// The backend is intentionally left untouched; this client adapts to it.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../vendor_registration_screen.dart' show VendorRegistrationModel;

/// Outcome of a registration attempt — success flag, a user-facing message and
/// the created vendor document (when the server returns one).
class VendorApiResult {
  const VendorApiResult({
    required this.success,
    required this.message,
    this.vendor,
  });

  final bool success;
  final String message;
  final Map<String, dynamic>? vendor;
}

class VendorApiService {
  const VendorApiService();

  /// How long to wait before giving up on the request.
  static const Duration _timeout = Duration(seconds: 30);

  /// Resolves the backend base URL for the current platform.
  ///
  /// - Android emulator cannot reach the host machine via `localhost`; it maps
  ///   the host to the special address `10.0.2.2`.
  /// - iOS simulator / desktop can use `localhost` directly.
  /// - On a physical device, neither works — pass your machine's LAN IP at
  ///   build time:  `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000`
  ///
  /// NOTE: This is plain HTTP for local development only. In production point
  /// API_BASE_URL at an HTTPS endpoint.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static Uri get _registerVendorUri =>
      Uri.parse('$baseUrl/vsArogya/register-vendor');

  /// Submits [model] to the backend. Never throws — always returns a result.
  Future<VendorApiResult> registerVendor(VendorRegistrationModel model) async {
    final request = http.MultipartRequest('POST', _registerVendorUri);

    // --- Text fields (names mirror the Express controller's req.body) ---
    request.fields.addAll({
      'vendor_type': model.vendorType ?? '',
      'shop_type': model.shopType ?? '',
      'store_name': model.storeName,
      'contact_person_name': model.contactPerson,
      'mobile_no': model.mobile,
      'email': model.email,
      'full_address': model.fullAddress,
      'city': model.city,
      'state': model.state,
      'pin_code': model.pinCode,
      // Backend schema enforces enum ["yes","no"], so map the UI label.
      'gst_status': _gstStatusForApi(model.gstStatus),
      'drug_lic_no': model.drugLicenseNumber,
      if (model.drugLicenseExpiry != null)
        'drug_lic_ex_date': model.drugLicenseExpiry!.toIso8601String(),
    });

    // --- File fields (multer keys: store_pic, gst_pdf, drug_lic_copy) ---
    await _attachFile(request, 'store_pic', model.storePhotoPath);
    await _attachFile(request, 'gst_pdf', model.gstCertificatePath);
    await _attachFile(request, 'drug_lic_copy', model.drugLicenseCopyPath);

    try {
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _parseResponse(response);
    } on TimeoutException {
      return const VendorApiResult(
        success: false,
        message: 'Request timed out. Please check your connection and retry.',
      );
    } on SocketException {
      return VendorApiResult(
        success: false,
        message: 'Cannot reach the server. Is it running at $baseUrl?',
      );
    } catch (e) {
      return VendorApiResult(
        success: false,
        message: 'Something went wrong while submitting. ($e)',
      );
    }
  }

  VendorApiResult _parseResponse(http.Response response) {
    Map<String, dynamic> body = const {};
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Non-JSON body (e.g. an HTML error page) — fall back to status code.
    }

    final ok = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['success'] == true;

    return VendorApiResult(
      success: ok,
      message: (body['message'] as String?) ??
          (ok
              ? 'Vendor registered successfully'
              : 'Registration failed (HTTP ${response.statusCode})'),
      vendor: body['vendor'] is Map<String, dynamic>
          ? body['vendor'] as Map<String, dynamic>
          : null,
    );
  }

  /// Adds a file part with the correct Content-Type. The backend's multer
  /// fileFilter only accepts jpeg/png/webp images and PDFs.
  static Future<void> _attachFile(
    http.MultipartRequest request,
    String field,
    String? path,
  ) async {
    if (path == null || path.isEmpty) return;
    // `dart:io` File is unavailable on Flutter Web (it throws
    // "Unsupported operation: _Namespace"). Skip path-based attachment there;
    // web uploads would need the picker's bytes (XFile) instead.
    // TODO(web): attach via http.MultipartFile.fromBytes using XFile bytes.
    if (kIsWeb) return;
    final file = File(path);
    if (!file.existsSync()) return;
    request.files.add(
      await http.MultipartFile.fromPath(
        field,
        path,
        contentType: _contentTypeFor(path),
      ),
    );
  }

  static MediaType _contentTypeFor(String path) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'pdf' => MediaType('application', 'pdf'),
      _ => MediaType('image', 'jpeg'), // jpg/jpeg and unknowns default to jpeg
    };
  }

  /// Maps the UI's GST status label to the backend enum ["yes","no"].
  static String _gstStatusForApi(String? uiValue) {
    if (uiValue == null) return 'no';
    return uiValue.startsWith('Registered') ? 'yes' : 'no';
  }
}
