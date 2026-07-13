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
import 'package:image_picker/image_picker.dart' show XFile;

import 'api_config.dart';
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
  static const Duration _timeout = Duration(seconds: 90);

  /// Shared base URL — see [ApiConfig]. Override with
  /// `--dart-define=API_BASE_URL=...` at run time.
  static String get baseUrl => ApiConfig.baseUrl;

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
    await _attachFile(request, 'store_pic', model.storePhotoFile);
    await _attachFile(request, 'gst_pdf', model.gstCertificateFile);
    await _attachFile(request, 'drug_lic_copy', model.drugLicenseCopyFile);

    try {
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      debugPrint("=========================");
      debugPrint("REGISTER API RESPONSE");
      debugPrint("STATUS CODE : ${response.statusCode}");
      debugPrint("BODY : ${response.body}");
      debugPrint("=========================");
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

    final ok =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['success'] == true;

    return VendorApiResult(
      success: ok,
      message:
          (body['message'] as String?) ??
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
  ///
  /// Reads the picked file via [XFile.readAsBytes], so it works on every
  /// platform: on mobile/desktop it reads from disk, and on Flutter Web it
  /// fetches the picker's `blob:` URL and returns its bytes (dart:io `File`
  /// is unsupported on web). We attach the raw bytes — never the blob URL
  /// string, which is meaningless to the server.
  static Future<void> _attachFile(
    http.MultipartRequest request,
    String field,
    XFile? file,
  ) async {
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;
    final filename = _safeName(file);
    request.files.add(
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename,
        contentType: _contentTypeFor(filename),
      ),
    );
  }

  /// Ensures the multipart filename carries an extension. The backend derives
  /// the data-URI mime type from the extension (server/utils/datauri.js), so a
  /// name without one (can happen on web) would break the Cloudinary upload.
  static String _safeName(XFile file) {
    final name = file.name;
    if (name.contains('.')) return name;
    final ext = switch (file.mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'application/pdf' => 'pdf',
      _ => 'jpg',
    };
    return '$name.$ext';
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
