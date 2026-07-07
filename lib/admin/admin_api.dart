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

  /// Approve / reject vendor calls are pinned to the local backend only — they
  /// do NOT use [baseUrl]/[ApiConfig]. Every other admin call still uses baseUrl.
  static const String _approvalBaseUrl = 'http://localhost:3000';

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

  /// Every vendor in the directory (GET /all-vendors), mapped with their real
  /// approval status. Returns null on failure so the screen can stay as-is.
  Future<List<Vendor>?> getAllVendors() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-vendors'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) return const <Vendor>[];
      final list = (body['all_vendors'] as List?) ?? const [];
      return list.whereType<Map<String, dynamic>>().map(_fromBackend).toList();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // USER DIRECTORY  (Admin · User Management)
  //   Every account lives in one collection (GET /vsArogya/all-vendors). The
  //   `role` field marks staff: "delivery" → a delivery agent, "admin" /
  //   "marketing" → platform staff (hidden here), everything else → a vendor.
  // ---------------------------------------------------------------------------

  /// The full platform directory split into vendors + delivery agents, mapped
  /// from the single backend user collection. Admin / marketing staff are
  /// excluded (they aren't part of the vendor or agent tabs). Returns null on a
  /// real failure so the screen can show a retry; an empty list means the
  /// collection is empty.
  Future<List<PlatformUser>?> getAllPlatformUsers() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-vendors'), headers: _headers)
          .timeout(_timeout);
      // The backend answers 402 when the collection is empty — not an error.
      if (res.statusCode == 402) return const <PlatformUser>[];
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) return const <PlatformUser>[];
      final list = (body['all_vendors'] as List?) ?? const [];
      final users = <PlatformUser>[];
      for (final j in list.whereType<Map<String, dynamic>>()) {
        final role = (j['role'] ?? '').toString().toLowerCase();
        if (role == 'admin' || role == 'marketing') continue;
        users.add(_platformUserFromBackend(j, isAgent: role == 'delivery'));
      }
      return users;
    } catch (_) {
      return null;
    }
  }

  /// Approves a vendor (PUT /approval-mail/:id). The backend emails the vendor
  /// their login credentials. Returns true on success.
  Future<bool> approveVendor(String id) async {
    try {
      final res = await _client
          .put(Uri.parse('$_approvalBaseUrl/vsArogya/approval-mail/$id'),
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
          .put(Uri.parse('$_approvalBaseUrl/vsArogya/reject-vendor/$id'),
              headers: _headers)
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Creates a delivery agent and emails them their login credentials.
  ///   POST /vsArogya/create-delivery-agent  (pinned to the local backend)
  /// Body: { contact_person_name, mobile_no, email, password, role:"delivery" }
  /// The login id IS the mobile number; [password] is the generated 6-digit
  /// code (created once, shown to the admin and mailed to the agent).
  /// Returns true on success. The backend owns the actual mail send.
  Future<bool> createDeliveryAgent({
    required String name,
    required String mobile,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_approvalBaseUrl/vsArogya/create-delivery-agent'),
            headers: _headers,
            body: jsonEncode({
              'contact_person_name': name,
              'mobile_no': mobile,
              'email': email,
              'password': password,
              'role': 'delivery',
            }),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ORDERS  (marketplace-wide monitor + status advance)
  //   GET /vsArogya/all-orders            all orders (populated, newest first)
  //   PUT /vsArogya/confirm-order/:id      Pending          -> Confirm Order
  //   PUT /vsArogya/shipped-order/:id      Confirm Order    -> Shipped
  //   PUT /vsArogya/outof-delivery/:id     Shipped          -> Out for Delivery
  //   PUT /vsArogya/delivered-prder/:id    Out for Delivery -> Delivered
  // ---------------------------------------------------------------------------

  /// Every order across the marketplace (newest first), fully populated with
  /// buyer + product details. Empty (₹0 / 0-item) legacy orders are filtered
  /// out. Returns null on failure so the screen keeps what it has.
  Future<List<AdminOrder>?> getAllOrders() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-orders'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['allOrders'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(_orderFromBackend)
          .where((o) => o.itemCount > 0)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Server-confirmed total for one order (GET /single-order/:id). The backend
  /// returns only the first line item + the order total, so the full item list
  /// still comes from [getAllOrders]; this is used to show an authoritative,
  /// freshly-fetched total on the order detail sheet. Returns null on failure.
  Future<double?> getSingleOrderAmount(String id) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/single-order/$id'),
              headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) return null;
      final amt = body['amount'];
      if (amt is num) return amt.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Realised revenue = sum of Delivered order totals (GET /total-revenue).
  /// Returns null on failure.
  Future<double?> getTotalRevenue() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/total-revenue'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final v = body['totalRevenue'];
      if (v is num) return v.toDouble();
      // Fallback to the raw aggregate shape if the flat field is absent.
      final agg = (body['all_orders'] as List?) ?? const [];
      if (agg.isNotEmpty && agg.first is Map) {
        final r = (agg.first as Map)['totalRevenue'];
        if (r is num) return r.toDouble();
      }
      return 0;
    } catch (_) {
      return null;
    }
  }

  /// Count of approved (active) vendors (GET /active-vendors). Null on failure.
  Future<int?> getActiveVendorCount() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/active-vendors'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final c = body['count'];
      if (c is num) return c.toInt();
      final list = body['active_vendor'] as List?;
      return list?.length ?? 0;
    } catch (_) {
      return null;
    }
  }

  /// Advances an order to [next] via the matching backend endpoint. Only the
  /// forward transitions the server supports are mapped. Returns true on ok.
  Future<bool> advanceOrder(String id, AdminOrderStatus next) async {
    final path = switch (next) {
      AdminOrderStatus.confirmed => '/vsArogya/confirm-order/$id',
      AdminOrderStatus.shipped => '/vsArogya/shipped-order/$id',
      AdminOrderStatus.outForDelivery => '/vsArogya/outof-delivery/$id',
      AdminOrderStatus.delivered => '/vsArogya/delivered-prder/$id',
      _ => null,
    };
    if (path == null) return false;
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static AdminOrder _orderFromBackend(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    final itemsRaw = (j['orderItems'] as List?) ?? const [];
    final lines = <AdminOrderLine>[];
    int itemCount = 0;
    for (final it in itemsRaw.whereType<Map>()) {
      final p = it['product'] is Map ? it['product'] as Map : const {};
      final qty = (it['quantity'] as num?)?.toInt() ?? 0;
      itemCount += qty;
      lines.add(AdminOrderLine(
        name: (p['title'] ?? 'Item').toString(),
        brand: (p['brand'] ?? p['category'] ?? '').toString(),
        quantity: qty,
        price: _numOf(it['orderPrice'] ?? p['price']),
      ));
    }
    final addr =
        j['shippingAddress'] is Map ? j['shippingAddress'] as Map : const {};
    final address =
        [addr['address'], addr['city'], addr['state'], addr['pincode']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(', ');
    return AdminOrder(
      id: (j['_id'] ?? '').toString(),
      buyer:
          (user['store_name'] ?? user['contact_person_name'] ?? 'Customer')
              .toString(),
      amount: _numOf(j['totalAmount']),
      itemCount: itemCount,
      status: _orderStatusFrom((j['orderStatus'] ?? 'Pending').toString()),
      lines: lines,
      placedAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      phone: (addr['phoneNo'] ?? user['mobile_no'] ?? '').toString(),
      address: address,
      paymentMethod: (j['paymentMethod'] ?? '').toString(),
    );
  }

  static AdminOrderStatus _orderStatusFrom(String s) => switch (s) {
        'Confirm Order' => AdminOrderStatus.confirmed,
        'Shipped' => AdminOrderStatus.shipped,
        'Out for Delivery' => AdminOrderStatus.outForDelivery,
        'Delivered' => AdminOrderStatus.delivered,
        'Cancelled' => AdminOrderStatus.cancelled,
        _ => AdminOrderStatus.pending,
      };

  static double _numOf(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "12 Jan 2024" from an ISO timestamp; empty when unparseable.
  static String _monthDate(Object? v) {
    if (v is! String) return '';
    final d = DateTime.tryParse(v);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')} '
        '${_monthNames[d.month - 1]} ${d.year}';
  }

  /// Maps one backend user document into a [PlatformUser] for the admin
  /// directory. [isAgent] switches the framing between a delivery partner and a
  /// pharmacy vendor. Only real, present fields become detail rows.
  static PlatformUser _platformUserFromBackend(
    Map<String, dynamic> j, {
    required bool isAgent,
  }) {
    String s(String key) => (j[key] ?? '').toString().trim();
    String? docUrl(String key) {
      if (j[key] is! Map) return null;
      final u = (j[key] as Map)['url'];
      return (u is String && u.isNotEmpty) ? u : null;
    }

    final store = s('store_name');
    final contact = s('contact_person_name');
    final city = s('city');
    final state = s('state');
    final approval = s('approvalStatus');
    final joined = _monthDate(j['createdAt']);
    final fullAddress = s('full_address');

    // Uploaded verification documents (Cloudinary URLs) — only those present.
    final storePhoto = docUrl('store_pic');
    final documents = <VendorDoc>[
      if (storePhoto != null) VendorDoc('Store Photo', true, url: storePhoto),
      if (docUrl('gst_pdf') != null)
        VendorDoc('GST Certificate', true, url: docUrl('gst_pdf')),
      if (docUrl('drug_lic_copy') != null)
        VendorDoc('Drug License Copy', true, url: docUrl('drug_lic_copy')),
    ];

    final name = isAgent
        ? (contact.isNotEmpty
            ? contact
            : (store.isNotEmpty ? store : 'Delivery Agent'))
        : (store.isNotEmpty
            ? store
            : (contact.isNotEmpty ? contact : 'Vendor'));

    final location = fullAddress.isNotEmpty
        ? fullAddress
        : [city, state].where((e) => e.isNotEmpty).join(', ');

    final tag = isAgent
        ? UserTag.active
        : switch (approval) {
            'Approved' => UserTag.active,
            'Rejected' => UserTag.suspended,
            _ => UserTag.pending,
          };

    final meta = isAgent
        ? [if (city.isNotEmpty) city, 'Delivery Partner'].join(' · ')
        : [if (city.isNotEmpty) city, if (approval.isNotEmpty) approval]
            .join(' · ');

    final info = <InfoPair>[
      if (isAgent)
        const InfoPair('Role', 'Delivery Partner')
      else ...[
        if (s('vendor_type').isNotEmpty)
          InfoPair('Vendor Type', s('vendor_type')),
        if (s('shop_type').isNotEmpty) InfoPair('Shop Type', s('shop_type')),
      ],
      if (contact.isNotEmpty) InfoPair('Contact Person', contact),
      if (city.isNotEmpty) InfoPair('City', city),
      if (state.isNotEmpty) InfoPair('State', state),
      if (s('pin_code').isNotEmpty) InfoPair('Pincode', s('pin_code')),
      if (!isAgent && s('gst_status').isNotEmpty)
        InfoPair('GST Registered', s('gst_status') == 'yes' ? 'Yes' : 'No'),
      if (!isAgent && s('drug_lic_no').isNotEmpty)
        InfoPair('Drug License', s('drug_lic_no')),
      if (!isAgent && approval.isNotEmpty)
        InfoPair('Approval Status', approval),
      if (joined.isNotEmpty) InfoPair('Member Since', joined),
    ];

    return PlatformUser(
      id: (j['_id'] ?? '').toString(),
      name: name,
      kind: isAgent ? UserKind.agent : UserKind.customer,
      meta: meta.isEmpty ? (isAgent ? 'Delivery Partner' : 'Vendor') : meta,
      tag: tag,
      phone: s('mobile_no').isNotEmpty ? s('mobile_no') : '—',
      email: s('email').isNotEmpty ? s('email') : '—',
      location: location.isNotEmpty ? location : '—',
      joinedOn: joined.isNotEmpty ? joined : '—',
      info: info,
      photoUrl: storePhoto,
      documents: documents,
    );
  }

  static Vendor _fromBackend(Map<String, dynamic> j) {
    String? docUrl(String key) =>
        j[key] is Map ? (j[key] as Map)['url'] as String? : null;
    bool hasDoc(String key) => docUrl(key) != null;
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
      status: _statusFrom((j['approvalStatus'] ?? 'Pending').toString()),
      mobile: (j['mobile_no'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      fullAddress: (j['full_address'] ?? '').toString(),
      state: (j['state'] ?? '').toString(),
      pincode: (j['pin_code'] ?? '').toString(),
      storePhotoUrl: docUrl('store_pic'),
      vendorType: (j['vendor_type'] ?? '').toString(),
      shopType: (j['shop_type'] ?? '').toString(),
      docs: [
        VendorDoc('Store Photo', hasDoc('store_pic'),
            url: docUrl('store_pic')),
        VendorDoc('Drug License Copy', hasDoc('drug_lic_copy'),
            url: docUrl('drug_lic_copy')),
        VendorDoc('GST Certificate', hasDoc('gst_pdf'),
            url: docUrl('gst_pdf')),
      ],
    );
  }

  static VendorStatus _statusFrom(String s) => switch (s) {
        'Approved' => VendorStatus.active,
        'Rejected' => VendorStatus.suspended,
        _ => VendorStatus.pending,
      };

  static String _date(Object? v) {
    if (v is! String) return '';
    final d = DateTime.tryParse(v);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
