// =============================================================================
// MediCaPlus — Admin API Service
//
// Vendor approval flow:
//   GET /vsArogya/pending-vendor      -> vendors awaiting approval
//   PUT /vsArogya/approval-mail/:id   -> approve (emails the vendor credentials)
//
// Maps the backend vendor document -> the admin Vendor model.
// =============================================================================

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'admin_models.dart';

class AdminApi {
  AdminApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);
  static String get baseUrl => ApiConfig.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  /// Vendors with approvalStatus "Pending". Returns null on failure (so the
  /// screen keeps whatever it has), or an empty list when there are none.
  Future<List<Vendor>?> getPendingVendors() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/pending-vendor'),
              headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) return const <Vendor>[];
      final list = (body['pendingUser'] as List?) ?? const [];
      return list.whereType<Map<String, dynamic>>().map(_fromBackend).toList();
    } catch (_) {
      return null;
    }
  }

  /// Approves a vendor (PUT /approval-mail/:id). The backend emails the vendor
  /// their login credentials. Returns true on success.
  Future<bool> approveVendor(String id) async {
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl/vsArogya/approval-mail/$id'),
              headers: _headers)
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Rejects a vendor (PUT /reject-vendor/:id). The backend marks the vendor
  /// "Rejected" and emails them. Returns true on success.
  Future<bool> rejectVendor(String id) async {
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl/vsArogya/reject-vendor/$id'),
              headers: _headers)
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Vendor _fromBackend(Map<String, dynamic> j) {
    bool hasDoc(String key) =>
        j[key] is Map && (j[key] as Map)['url'] != null;
    return Vendor(
      id: (j['_id'] ?? '').toString(),
      name: (j['store_name'] ?? '').toString(),
      legalName: (j['contact_person_name'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      // No GSTIN field is stored; show the drug-license no. as the key id.
      gstin: (j['drug_lic_no'] ?? j['gst_status'] ?? '—').toString(),
      orders: 0,
      rating: 0,
      appliedOn: _date(j['createdAt']),
      status: VendorStatus.pending,
      docs: [
        VendorDoc('Store Photo', hasDoc('store_pic')),
        VendorDoc('Drug License Copy', hasDoc('drug_lic_copy')),
        VendorDoc('GST Certificate', hasDoc('gst_pdf')),
      ],
    );
  }

  static String _date(Object? v) {
    if (v is! String) return '';
    final d = DateTime.tryParse(v);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
