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

  /// Accept renders the invoice PDF on the server inline; give that one call a
  /// longer window so a cold-started PDF engine can't fail the confirmation.
  static const Duration _slowTimeout = Duration(seconds: 60);
  static String get baseUrl => ApiConfig.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  /// Cancels an order as ADMIN (PUT /vsArogya/cancel-order/:id, staff token).
  /// Allowed only BEFORE delivery — the backend rejects Delivered orders and
  /// restores any stock deducted at accept time (see the contract in
  /// MarketingOrdersApi / ORDER_INVOICE_STOCK_INTEGRATION.md). Returns null on
  /// success or a user-facing error message.
  Future<String?> cancelOrder(String id) async {
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl/vsArogya/cancel-order/$id'),
              headers: _headers)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      try {
        final b = jsonDecode(res.body);
        if (b is Map && b['message'] != null) return b['message'].toString();
      } catch (_) {
        // non-JSON body
      }
      return 'Cancel failed (HTTP ${res.statusCode}) — try again';
    } catch (_) {
      return 'Network error — check your connection and try again';
    }
  }

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

  /// Creates a delivery agent (POST /vsArogya/agent-create).
  /// Body the backend expects: { fullName, email, mobile }. The SERVER
  /// generates the 6-digit password itself and returns it on the created
  /// agent, so the login id IS the mobile number and the password is whatever
  /// the server made.
  ///
  /// Returns `(password, error)`:
  ///  • password → the server-generated password to show/share with the agent.
  ///  • error    → a user-facing message when the create failed.
  Future<(String?, String?)> createDeliveryAgent({
    required String name,
    required String mobile,
    required String email,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/agent-create'),
            headers: _headers,
            body: jsonEncode({
              'fullName': name,
              'email': email,
              'mobile': mobile,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final agent = body['agentDetails'];
        final pwd = (agent is Map ? agent['password'] : null)?.toString();
        return (pwd ?? '', null);
      }
      // Surface the server's own message (e.g. missing field / duplicate).
      try {
        final b = jsonDecode(res.body);
        if (b is Map && b['message'] != null) {
          return (null, b['message'].toString());
        }
      } catch (_) {
        // non-JSON body
      }
      return (null, 'Could not create agent (HTTP ${res.statusCode}).');
    } catch (_) {
      return (null, 'Could not reach the server. Check your connection.');
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

  /// The master catalogue (GET /all-products) — the same list the customer
  /// shop sells from — mapped into admin rows. Returns null on failure so the
  /// screen can keep its current list / show an error state.
  Future<List<AdminProduct>?> getAllProducts() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-products'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['products'] as List?) ?? const [];
      return list.whereType<Map<String, dynamic>>().map((j) {
        final id = (j['_id'] ?? '').toString();
        final stock = (j['quantity'] as num?)?.toInt() ?? 0;
        return AdminProduct(
          id: id,
          name: (j['title'] ?? 'Product').toString(),
          // No SKU field server-side — show the tail of the Mongo id so rows
          // are still individually identifiable/searchable.
          sku: id.length >= 6 ? id.substring(id.length - 6).toUpperCase() : id,
          price: _numOf(j['price']),
          stock: stock,
          category: (j['category'] ?? '').toString(),
          active: stock > 0,
        );
      }).toList();
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
    // Accept renders the invoice PDF (Puppeteer) inline on the server before it
    // replies, so that transition gets a longer timeout to survive a cold start.
    final timeout =
        next == AdminOrderStatus.confirmed ? _slowTimeout : _timeout;
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(timeout);
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
        category: (p['category'] ?? '').toString(),
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
      city: (addr['city'] ?? '').toString().trim(),
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
      // Absent on pre-existing documents → treated as admin-registered.
      registrationSource:
          (j['registrationSource'] ?? 'admin').toString().toLowerCase(),
      createdAt:
          j['createdAt'] is String ? DateTime.tryParse(j['createdAt']) : null,
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
