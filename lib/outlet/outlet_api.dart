// =============================================================================
// VS Arogya — Outlet Staff · Backend API
//
// The live endpoints the Outlet role has today:
//   POST /vsArogya/outlet-login              → { success, token, role, outlet }
//   GET  /vsArogya/outlet-products/:id       → the stock marketing assigned
//   GET  /vsArogya/outlet-orders/:id         → orders this outlet placed
//   POST /vsArogya/outlet/orders/:id/razorpay → on-device checkout order
//   POST /vsArogya/outlet/orders/:id/verify   → signature check → PAID
//   POST /vsArogya/outlet/orders/:id/payment  → Razorpay payment link (QR/link)
//   GET  /vsArogya/outlet/orders/:id/status   → outlet-vocabulary status poll
//
// Outlets live in their OWN collection (server/model/outletregistersModel.js),
// so they do NOT go through /vsArogya/login (which only reads Vendor) — this is
// their separate login path. The payment endpoints are scoped server-side to
// order.outlet == the session's outlet id (rolePaymentController.js).
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../customer/invoice_pdf.dart' show InvoicePdf;
import '../services/api_config.dart';
import 'outlet_enums.dart';
import 'outlet_models.dart';
import 'outlet_session.dart';

class OutletApi {
  OutletApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// A cold-started free-tier server can take a while on the first call.
  static const Duration _timeout = Duration(seconds: 45);

  /// Placing an order renders the invoice server-side — give it longer.
  static const Duration _slowTimeout = Duration(seconds: 90);

  static String get baseUrl => ApiConfig.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (OutletSession.instance.token != null)
          'Authorization': 'Bearer ${OutletSession.instance.token}',
        if (OutletSession.instance.cookie != null)
          'Cookie': OutletSession.instance.cookie!,
      };

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  /// Signs an outlet in. Returns `(outlet, error)` — the outlet on success,
  /// else a user-facing message.
  ///
  /// On success this also captures the session token/cookie so the stock call
  /// can authenticate. The server sets an httpOnly cookie AND echoes the token
  /// in the body; the body token is the reliable path (the cookie is
  /// sameSite:strict and unreadable on web).
  Future<(OutletAccount?, String?)> login({
    required String mobileNo,
    required String password,
  }) async {
    final url = '$baseUrl/vsArogya/outlet-login';
    try {
      debugPrint('[OutletAuth] POST $url mobile=$mobileNo');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mobileNo': mobileNo, 'password': password}),
          )
          .timeout(_timeout);

      debugPrint('[OutletAuth] status=${res.statusCode}');

      Map<String, dynamic> body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return (null, 'Unexpected response from the server. Please try again.');
      }

      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          body['success'] != true) {
        // The server answers "Data mismatch" / "Somthing is wrong" for a bad
        // mobile/password — neither is showable, so map them to one clear line.
        return (null, 'Incorrect mobile number or password');
      }

      final outletJson = body['outlet'];
      if (outletJson is! Map<String, dynamic>) {
        return (
          null,
          'Login succeeded but the server did not return the outlet. '
              'Please contact support.',
        );
      }

      final account = OutletAccount.fromJson(outletJson);
      if (account.id.isEmpty) {
        return (null, 'The server did not return an outlet id.');
      }

      final setCookie = res.headers['set-cookie'];
      OutletSession.instance.signIn(
        outletId: account.id,
        name: account.ownerName,
        outlet: account.outletName,
        district: account.city,
        token: body['token']?.toString(),
        cookie: setCookie?.split(';').first,
      );

      return (account, null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletAuth] failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  /// The signed-in outlet's own profile — GET /vsArogya/outlet-profile/:id.
  /// The server returns `{ success, outlet }` with the full Outlet document
  /// (minus password/cart), so the Profile tab always shows current data.
  ///
  /// Returns `(outlet, error)`.
  Future<(OutletAccount?, String?)> fetchProfile(String outletId) async {
    final url = '$baseUrl/vsArogya/outlet-profile/$outletId';
    try {
      debugPrint('[OutletProfile] GET $url');
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (null, 'Server returned HTTP ${res.statusCode} — please try again.');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        return (null, (body['message'] ?? 'Could not load profile').toString());
      }

      final outletJson = body['outlet'];
      if (outletJson is! Map<String, dynamic>) {
        return (null, 'The server did not return the outlet profile.');
      }

      return (OutletAccount.fromJson(outletJson), null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletProfile] failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // STOCK
  // ---------------------------------------------------------------------------

  /// The stock marketing has assigned to [outletId].
  ///
  /// The server returns OutletStock rows with `product` populated:
  ///   { success, count, products: [ { _id, product: {...}, quantity } ] }
  /// Rows whose product was deleted come back with a null `product` and are
  /// skipped rather than rendered as a blank line.
  ///
  /// Returns `(items, error)`.
  Future<(List<OutletStockItem>?, String?)> fetchStock(String outletId) async {
    final url = '$baseUrl/vsArogya/outlet-products/$outletId';
    try {
      debugPrint('[OutletStock] GET $url');
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (null, 'Server returned HTTP ${res.statusCode} — please try again.');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        return (null, (body['message'] ?? 'Could not load stock').toString());
      }

      final rows = (body['products'] as List?) ?? const [];
      final session = OutletSession.instance;
      final items = <OutletStockItem>[];

      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final p = row['product'];
        if (p is! Map) continue; // product deleted from the catalog

        items.add(OutletStockItem(
          id: (p['_id'] ?? '').toString(),
          name: (p['title'] ?? '').toString(),
          packSize: (p['packInfo'] ?? '').toString(),
          category: (p['category'] ?? '').toString(),
          price: _num(p['price']),
          qtyAvailable: _int(row['quantity']),
          // This endpoint only ever returns the outlet's OWN rows — there is no
          // district-stock endpoint yet, so nothing here is read-only.
          isOwnOutlet: true,
          outletName: session.outletName ?? '',
          district: session.district ?? '',
          // Billing / POS display fields — the product is fully populated, so
          // the image, MRP, batch, expiry and GST are all available here.
          mrp: _num(p['mrp']),
          imageUrl: _firstImageUrl(p['image']),
          // The lot THIS OUTLET sells next: the server attaches its own
          // FEFO-front batch on `row['batch']`. The product's batch_no/exp_date
          // are the CATALOG's front lot, which the outlet may not hold at all —
          // they are only the fallback for stock that predates batching.
          expiry: _date(row['batch']?['expiry_date'] ?? p['exp_date']),
          batch: (row['batch']?['batch_number'] ?? p['batch_no'] ?? '')
              .toString(),
          batchCount: _int(row['batch_count']),
          gstPercent: _num(p['gstPercent']),
          discountPercent: _num(p['discountPercent']),
          hsnCode: (p['hsnCode'] ?? '').toString(),
        ));
      }

      return (items, null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletStock] failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // VENDORS (the approved buyers an order can be placed for)
  // ---------------------------------------------------------------------------

  /// Approved vendor accounts, read from GET /vsArogya/all-vendors with the
  /// staff roles filtered out — the same source and filter the marketing
  /// manual-order picker uses.
  ///
  /// `/active-vendors` would be the more direct endpoint but it 404s on an
  /// empty list and returns the password field, so /all-vendors is used here.
  ///
  /// Returns `(vendors, error)`.
  Future<(List<OutletVendor>?, String?)> fetchVendors() async {
    const staffRoles = {'admin', 'delivery', 'marketing', 'outlet', 'agent'};
    final url = '$baseUrl/vsArogya/all-vendors';
    try {
      debugPrint('[OutletVendors] GET $url');
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (null, 'Server returned HTTP ${res.statusCode} — please try again.');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['all_vendors'] as List?) ?? const [];

      final vendors = list
          .whereType<Map<String, dynamic>>()
          .where((j) =>
              !staffRoles.contains((j['role'] ?? '').toString().toLowerCase()))
          .where((j) => (j['approvalStatus'] ?? '').toString() == 'Approved')
          .map((j) => OutletVendor(
                id: (j['_id'] ?? '').toString(),
                storeName: (j['store_name'] ?? '').toString(),
                contactPerson: (j['contact_person_name'] ?? '').toString(),
                phone: (j['mobile_no'] ?? '').toString(),
                address: (j['full_address'] ?? '').toString(),
                city: (j['city'] ?? '').toString(),
                state: (j['state'] ?? '').toString(),
                pincode: (j['pin_code'] ?? '').toString(),
              ))
          .toList();

      return (vendors, null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletVendors] failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // MANUAL ORDER — reuses the marketing manual-order API
  // ---------------------------------------------------------------------------

  /// Places [request] as an order on the selected vendor's behalf, using the
  /// SAME two-step API the marketing role uses:
  ///   POST /vsArogya/manual-cart/:vendorId/:productId  → adds ONE unit,
  ///        body `{ allocations }` pins the lot the line is issued from
  ///   POST /vsArogya/manual-order/:vendorId            → places the order,
  ///        body `{ outletId }` makes it deduct THIS outlet's batches
  ///
  /// With `outletId` set, the server allocates each line across the OUTLET's own
  /// lots (allocateOutletFEFO), honours the pinned `allocations` after
  /// re-validating them against live availability, records the exact lots on
  /// `orderItems.allocations` and keeps `outletStock.quantity` in step — so the
  /// stock this outlet holds really does come down, batch-wise.
  ///
  /// Caveats, all inherent to that API (see the notes in LiveOutletDataSource):
  ///  • the order is created against the VENDOR, so its address comes from the
  ///    vendor's profile (`outletId` is the only link back to this outlet);
  ///  • it ignores `idempotencyKey`, so the caller must guard double-submits.
  ///
  /// Returns `(order, error)`.
  Future<(OutletOrder?, String?)> createManualOrder(
      CreateOrderRequest request) async {
    final vendorId = request.customer.vendorId;
    if (vendorId.isEmpty) {
      return (null, 'Pick a vendor before placing the order.');
    }

    try {
      // 1) Build the vendor's cart. The server adds ONE unit per call, so each
      //    quantity becomes that many calls. They run in SERIES on purpose:
      //    every call re-reads and saves the same vendor document, so firing
      //    them in parallel would race and drop increments.
      //
      //    BATCH PIN: each call carries the line's chosen lot as `allocations`.
      //    The server REPLACES the line's allocations on every call (they
      //    describe the whole line, not one unit), so the quantity sent is the
      //    line's FINAL quantity and the last call leaves exactly the right pin
      //    behind. A line with no lot chosen omits the field entirely, which is
      //    the pre-existing pure-FEFO behaviour.
      for (final line in request.lines) {
        final body = line.hasBatch
            ? jsonEncode({'allocations': [line.allocation.toJson()]})
            : null;
        for (var i = 0; i < line.qty; i++) {
          final url =
              '$baseUrl/vsArogya/manual-cart/$vendorId/${line.productId}';
          final res = await _client
              .post(Uri.parse(url), headers: _headers, body: body)
              .timeout(_timeout);
          if (res.statusCode < 200 || res.statusCode >= 300) {
            return (
              null,
              _serverMessage(res) ??
                  'Could not add ${line.name} to the order '
                      '(HTTP ${res.statusCode}).',
            );
          }
        }
      }

      // 2) Place the order from that cart, tagging it with this outlet so it
      //    can be found again — order.user is the VENDOR, so `outletId` is the
      //    only thing that links the order back here.
      final url = '$baseUrl/vsArogya/manual-order/$vendorId';
      debugPrint('[OutletOrder] POST $url lines=${request.lines.length}');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({'outletId': OutletSession.instance.outletId}),
          )
          .timeout(_slowTimeout);

      debugPrint('[OutletOrder] status=${res.statusCode}');

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (
          null,
          _serverMessage(res) ??
              'The server could not place this order (HTTP ${res.statusCode}).',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['Order'] ?? body['order'];
      if (raw is! Map) {
        return (null, 'The server did not return the created order.');
      }

      return (_orderFromBackend(raw, request), null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletOrder] failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Maps the backend order document onto [OutletOrder].
  ///
  /// The response echoes `orderItems` with un-populated product refs, so the
  /// display lines are taken from the [request] we just sent — the server
  /// snapshotted the same products at the same prices.
  static OutletOrder _orderFromBackend(Map raw, CreateOrderRequest request) {
    final serverStatus = (raw['orderStatus'] ?? 'Pending').toString();
    return OutletOrder(
      id: (raw['_id'] ?? '').toString(),
      type: request.type,
      status: _statusFromServer(serverStatus),
      paymentMethod: request.paymentMethod,
      lines: [
        for (final l in request.lines)
          OutletOrderLine(
            name: l.name,
            packSize: l.packSize,
            qty: l.qty,
            price: l.price,
          ),
      ],
      customer: request.customer,
      total: _num(raw['totalAmount']),
      createdAt:
          DateTime.tryParse((raw['createdAt'] ?? '').toString()) ??
              DateTime.now(),
      idempotencyKey: request.idempotencyKey,
      teamFulfilled: true,
      serverStatusLabel: serverStatus,
    );
  }

  /// Fetches the server-generated invoice PDF for [orderId] using the OUTLET's
  /// own session token — GET /prev-invoice/:id. (The shared staff viewer keys on
  /// AuthService, which an outlet login never populates, so the outlet role
  /// needs its own authenticated fetch.) Returns `(bytes, error)`; the error is
  /// "Invoice not found" while the server is still generating the PDF.
  Future<(Uint8List?, String?)> fetchInvoicePdf(String orderId) async {
    final url = '$baseUrl/vsArogya/prev-invoice/$orderId';
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && InvoicePdf.looksLikePdf(res.bodyBytes)) {
        return (res.bodyBytes, null);
      }
      return (null, _serverMessage(res) ?? 'Server returned HTTP ${res.statusCode}.');
    } catch (e) {
      debugPrint('[OutletInvoice] failed: $e');
      return (null, 'Could not reach the invoice server. Check your connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // BILLING (POS) — instant, stock-deducting counter bill
  //
  // Places a walk-in bill directly from inline line items + the customer's
  // details — POST /outlet/bill. The server checks + DEDUCTS outlet stock,
  // creates the order (with `outlet` set, so it's payable via the outlet
  // Razorpay endpoints) and renders the invoice from the HTML template. It needs
  // NO pre-registered vendor, so the customer's vendor registration can be
  // submitted separately in the background without blocking the bill.
  // ---------------------------------------------------------------------------

  /// The outlet's sellable batches for a product (available > 0, not expired,
  /// FEFO order) — GET /outlet/product/:id/available-batches. Powers the manual
  /// batch-override picker. Returns `(batches, error)`.
  Future<(List<OutletBatch>?, String?)> getOutletAvailableBatches(
    String productId,
  ) async {
    final url = '$baseUrl/vsArogya/outlet/product/$productId/available-batches';
    try {
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300 || body['success'] != true) {
        return (null, (body['message'] ?? 'Could not load batches').toString());
      }
      final list = (body['batches'] as List?) ?? const [];
      return (
        list.whereType<Map<String, dynamic>>().map(OutletBatch.fromJson).toList(),
        null,
      );
    } catch (_) {
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Everything the Medicine Details screen shows, in ONE request — the same
  /// endpoint as above with `?all=1`, which widens it from "sellable lots" to
  /// EVERY lot this outlet holds and attaches the catalog product + the
  /// outlet's stock totals.
  ///
  /// Outlet-scoped server-side (the session's outlet id), so this can only ever
  /// return the signed-in outlet's own inventory. Returns `(detail, error)`.
  Future<(OutletMedicineDetail?, String?)> fetchMedicineDetail(
    String productId,
  ) async {
    final url =
        '$baseUrl/vsArogya/outlet/product/$productId/available-batches?all=1';
    try {
      debugPrint('[OutletStock] GET $url');
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      // A deleted medicine, an expired session or a proxy error can all answer
      // with a non-JSON body — read the status before trusting the payload.
      if (res.statusCode == 401 || res.statusCode == 403) {
        return (null, 'Your session has expired. Please sign in again.');
      }
      if (res.statusCode == 404) {
        return (
          null,
          _serverMessage(res) ??
              'This medicine is no longer in the catalogue.'
        );
      }

      Map<String, dynamic> body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return (
          null,
          'Server returned HTTP ${res.statusCode} — please try again.'
        );
      }

      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          body['success'] != true) {
        return (
          null,
          (body['message'] ?? 'Could not load the medicine details').toString()
        );
      }
      if (body['product'] is Map) {
        return (OutletMedicineDetail.fromJson(body), null);
      }

      // The server predates `?all=1`: it ignored the flag and answered with the
      // SELLABLE lots and no product. Rather than dead-end the screen, rebuild
      // the same shape from what IS deployed — the lots it did return, plus the
      // product document read live from /all-products. Still zero invented
      // data; the only thing missing is the expired/emptied lots, which
      // [showsAllLots] tells the screen to disclose.
      final (productJson, productError) = await _fetchProductJson(productId);
      if (productJson == null) return (null, productError);

      final legacyBatches = (body['batches'] as List?) ?? const [];
      return (
        OutletMedicineDetail.fromJson(
          {
            'product': productJson,
            'batches': legacyBatches,
            // This server sends no totals, so they are summed over the lots it
            // returned — the server's own quantities, just added up here.
            'stock': _sumAvailable(legacyBatches),
            'total_stock': _sumAvailable(legacyBatches),
            'batch_count': legacyBatches.length,
          },
          showsAllLots: false,
        ),
        null,
      );
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletStock] medicine detail failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// The catalog document for [productId], read live from GET /all-products —
  /// the only deployed endpoint that returns a full product. Used ONLY on the
  /// pre-`?all=1` fallback path above, so the common case still costs one call.
  /// Returns `(product, error)`.
  Future<(Map<String, dynamic>?, String?)> _fetchProductJson(
    String productId,
  ) async {
    final url = '$baseUrl/vsArogya/all-products';
    try {
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (
          null,
          'Server returned HTTP ${res.statusCode} — please try again.'
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      for (final p in ((body['products'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()) {
        if ((p['_id'] ?? '').toString() == productId) return (p, null);
      }
      return (null, 'This medicine is no longer in the catalogue.');
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletStock] product lookup failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Total units across a raw `batches` payload, using the server's own
  /// per-lot quantities.
  static int _sumAvailable(List<dynamic> batches) => batches
      .whereType<Map>()
      .fold(0, (sum, b) => sum + _int(b['available_quantity']));

  /// Asks the backend for the FEFO batch allocation of [quantity] for a product,
  /// honouring any manual [overrides] — POST /outlet/allocate-preview. The
  /// backend is the single source of truth: it validates, auto-fills the
  /// remainder FEFO and returns the corrected breakdown. NON-mutating.
  ///
  /// Returns `(allocations, remaining, availableBatches, error)`.
  Future<(List<OutletBatchAllocation>, int, List<OutletBatch>, String?)>
      previewAllocation(
    String productId,
    int quantity, {
    List<OutletBatchAllocation> overrides = const [],
  }) async {
    final url = '$baseUrl/vsArogya/outlet/allocate-preview';
    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              'productId': productId,
              'quantity': quantity,
              if (overrides.isNotEmpty)
                'overrides': overrides.map((o) => o.toJson()).toList(),
            }),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300 || body['success'] != true) {
        return (
          <OutletBatchAllocation>[],
          quantity,
          <OutletBatch>[],
          (body['message'] ?? 'Could not allocate batches').toString(),
        );
      }
      final allocs = ((body['allocations'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OutletBatchAllocation.fromJson)
          .toList();
      final avail = ((body['availableBatches'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OutletBatch.fromJson)
          .toList();
      final remaining = (body['remaining'] as num?)?.toInt() ?? 0;
      return (allocs, remaining, avail, null);
    } catch (_) {
      return (
        <OutletBatchAllocation>[],
        quantity,
        <OutletBatch>[],
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Places the bill. [customer] carries the walk-in's details (name/firm/
  /// address/city/state/pincode/phone/gstin) for the invoice; [items] is a list
  /// of `{productId, quantity, allocations?}` — when a line carries `allocations`
  /// the backend honours that manual FEFO override (after validating it).
  /// Returns `(orderId, totalAmount, error)`.
  Future<(String?, double?, String?)> placeOutletBill({
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
  }) async {
    final url = '$baseUrl/vsArogya/outlet/bill';
    try {
      debugPrint('[OutletBilling] POST $url items=${items.length}');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({'customer': customer, 'items': items}),
          )
          .timeout(_slowTimeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          body['success'] != true) {
        return (
          null,
          null,
          (body['message'] ?? 'Could not place the bill (HTTP ${res.statusCode}).')
              .toString()
        );
      }
      final created = body['createOrder'];
      if (created is! Map) {
        return (null, null, 'The server did not return the created order.');
      }
      return (
        (created['_id'] ?? '').toString(),
        _num(created['totalAmount']),
        null
      );
    } on TimeoutException {
      return (null, null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletBilling] bill failed: $e');
      return (null, null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Files the walk-in customer as a PENDING vendor for admin approval, tagged
  /// registrationSource:"outlet". JSON only — NO file uploads (the counter now
  /// records GST + drug-license NUMBERS, not documents). This is independent of
  /// the bill/invoice: a failure here never affects the placed order.
  ///
  /// [customer] mirrors the backend body of POST /vsArogya/outlet/register-vendor
  /// (snake_case keys). Returns `(success, message)`.
  Future<(bool, String)> registerOutletVendor(
      Map<String, dynamic> customer) async {
    final url = '$baseUrl/vsArogya/outlet/register-vendor';
    try {
      final res = await _client
          .post(Uri.parse(url), headers: _headers, body: jsonEncode(customer))
          .timeout(_timeout);
      Map<String, dynamic> body = const {};
      try {
        if (res.body.isNotEmpty) {
          body = jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {}
      final ok = res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body['success'] == true;
      return (
        ok,
        (body['message'] as String?) ??
            (ok
                ? 'Registration submitted for admin approval.'
                : 'Registration failed (HTTP ${res.statusCode}).')
      );
    } on TimeoutException {
      return (false, 'Request timed out. Please retry.');
    } catch (e) {
      debugPrint('[OutletBilling] register-vendor failed: $e');
      return (false, 'Could not reach the server. Check your connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // ORDERS THIS OUTLET PLACED
  // ---------------------------------------------------------------------------

  /// Orders placed by [outletId] — GET /vsArogya/outlet-orders/:id, newest
  /// first, with `orderItems.product` and `user` populated.
  ///
  /// Returns `(orders, error)`.
  Future<(List<OutletOrder>?, String?)> fetchOrders(String outletId) async {
    final url = '$baseUrl/vsArogya/outlet-orders/$outletId';
    try {
      debugPrint('[OutletOrders] GET $url');
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (null, 'Server returned HTTP ${res.statusCode} — please try again.');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        return (null, (body['message'] ?? 'Could not load orders').toString());
      }

      final rows = (body['orders'] as List?) ?? const [];
      return (
        rows.whereType<Map<String, dynamic>>().map(_listedOrder).toList(),
        null
      );
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletOrders] failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Maps a listed backend order (product + user populated) onto [OutletOrder].
  static OutletOrder _listedOrder(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    final addr =
        j['shippingAddress'] is Map ? j['shippingAddress'] as Map : const {};

    final lines = <OutletOrderLine>[];
    for (final it in ((j['orderItems'] as List?) ?? const []).whereType<Map>()) {
      final p = it['product'] is Map ? it['product'] as Map : const {};
      lines.add(OutletOrderLine(
        name: (p['title'] ?? 'Item').toString(),
        packSize: (p['packInfo'] ?? '').toString(),
        qty: _int(it['quantity'], 1),
        price: _num(it['orderPrice'] ?? p['price']),
      ));
    }

    final address = [addr['address'], addr['city'], addr['state'], addr['pincode']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(', ');

    final serverStatus = (j['orderStatus'] ?? 'Pending').toString();

    // The fulfilment status alone can't say whether the money arrived: an order
    // the outlet has already collected Razorpay payment for stays "Pending"
    // until the team confirms it. paymentInfo.status is the server's OWN paid
    // flag (rolePaymentController's isPaid), so read it and never offer to
    // collect payment twice.
    final payInfo = j['paymentInfo'] is Map ? j['paymentInfo'] as Map : const {};
    final paid = (payInfo['status'] ?? '').toString() == 'Completed';
    final mapped = _statusFromServer(serverStatus);

    return OutletOrder(
      id: (j['_id'] ?? '').toString(),
      // The vendor pipeline has no counter/delivery notion — these orders are
      // shipped to the vendor's registered address.
      type: OutletOrderType.delivery,
      status: paid && mapped == OutletOrderStatus.awaitingPayment
          ? OutletOrderStatus.paid
          : mapped,
      paymentMethod: OutletPaymentMethod.fromApi(null),
      lines: lines,
      customer: OutletCustomerInfo(
        name: (user['store_name'] ?? user['contact_person_name'] ?? 'Vendor')
            .toString(),
        phone: (addr['phoneNo'] ?? user['mobile_no'] ?? '').toString(),
        address: address.isEmpty ? null : address,
        vendorId: (user['_id'] ?? '').toString(),
      ),
      total: _num(j['totalAmount']),
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      paidAt: DateTime.tryParse((j['paidAt'] ?? '').toString()),
      teamFulfilled: true,
      serverStatusLabel: serverStatus,
    );
  }

  /// Maps the SERVER's order vocabulary onto the outlet's.
  ///
  /// These are two different lifecycles: the server's is about fulfilment
  /// (Pending → Confirm Order → Shipped → …) while the outlet's is about
  /// payment (AWAITING_PAYMENT → PAID → HANDED_OVER). There is no exact
  /// correspondence, so this is a DISPLAY approximation only — which is safe
  /// because these orders are [OutletOrder.teamFulfilled] and the outlet is
  /// never offered an action based on the mapped value.
  static OutletOrderStatus _statusFromServer(String s) => switch (s) {
        'Confirm Order' => OutletOrderStatus.paid,
        'Shipped' => OutletOrderStatus.readyForPickup,
        'Out for Delivery' => OutletOrderStatus.outForDelivery,
        'Delivered' => OutletOrderStatus.delivered,
        'Cancelled' => OutletOrderStatus.cancelled,
        _ => OutletOrderStatus.awaitingPayment, // "Pending"
      };

  // ---------------------------------------------------------------------------
  // PAYMENT (all server-owned; the app never marks anything paid — rule #3)
  // ---------------------------------------------------------------------------

  /// Creates the Razorpay order the razorpay_flutter checkout sheet needs —
  /// POST /vsArogya/outlet/orders/:id/razorpay. Returns `(payment, error)`.
  Future<(OutletOnlinePayment?, String?)> createRazorpayOrder(
      String orderId) async {
    final url = '$baseUrl/vsArogya/outlet/orders/$orderId/razorpay';
    try {
      debugPrint('[OutletPay] POST $url');
      final res = await _client
          .post(Uri.parse(url), headers: _headers)
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          body['success'] != true) {
        return (
          null,
          (body['message'] ?? 'Could not start the payment').toString()
        );
      }
      return (OutletOnlinePayment.fromJson(body), null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletPay] razorpay failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Sends the checkout sheet's success callback for server-side signature
  /// verification — POST /vsArogya/outlet/orders/:id/verify. Returns
  /// `(verified, error)`; only the server flips the order to PAID.
  Future<(bool?, String?)> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String paymentId,
    required String signature,
  }) async {
    final url = '$baseUrl/vsArogya/outlet/orders/$orderId/verify';
    try {
      debugPrint('[OutletPay] POST $url');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              'razorpay_order_id': razorpayOrderId,
              'razorpay_payment_id': paymentId,
              'razorpay_signature': signature,
            }),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (
          null,
          (body['message'] ?? 'Payment verification failed').toString()
        );
      }
      return (body['verified'] == true, null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletPay] verify failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Creates (or returns the outstanding) Razorpay payment-link session for the
  /// QR / share-a-link flow — POST /vsArogya/outlet/orders/:id/payment.
  /// Returns `(info, error)`.
  Future<(OutletPaymentInfo?, String?)> createPaymentSession(
    String orderId,
    OutletPaymentMethod method,
  ) async {
    final url = '$baseUrl/vsArogya/outlet/orders/$orderId/payment';
    try {
      debugPrint('[OutletPay] POST $url method=${method.api}');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({'method': method.api}),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          body['success'] != true) {
        return (
          null,
          (body['message'] ?? 'Could not create the payment session').toString()
        );
      }
      return (OutletPaymentInfo.fromJson(body), null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletPay] session failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// The cheap status poll — GET /vsArogya/outlet/orders/:id/status. Also the
  /// moment the server reconciles a pending payment link against Razorpay.
  /// Returns `(status, error)`.
  Future<(OutletOrderStatus?, String?)> fetchOrderStatus(String orderId) async {
    final url = '$baseUrl/vsArogya/outlet/orders/$orderId/status';
    try {
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          body['success'] != true) {
        return (
          null,
          (body['message'] ?? 'Could not read the order status').toString()
        );
      }
      return (OutletOrderStatus.fromApi(body['status']?.toString()), null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[OutletPay] status failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  static String? _serverMessage(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['message'] != null) return b['message'].toString();
    } catch (_) {
      // non-JSON body
    }
    return null;
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _int(Object? v, [int d = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? d;
    return d;
  }

  /// A parsed date from a backend value, or null when absent/invalid.
  static DateTime? _date(Object? v) {
    if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return null;
  }

  /// The first image URL from a product's `image: [{ url, publicId }]` array.
  static String _firstImageUrl(Object? images) {
    if (images is List) {
      for (final img in images) {
        if (img is Map && (img['url'] ?? '').toString().isNotEmpty) {
          return img['url'].toString();
        }
      }
    }
    return '';
  }
}

/// The outlet account returned by POST /outlet-login and GET /outlet-profile.
/// Mirrors the server's Outlet document (model/outletregistersModel.js) minus
/// the password.
class OutletAccount {
  const OutletAccount({
    required this.id,
    required this.outletName,
    required this.ownerName,
    this.mobileNo = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.gstNumber = '',
    this.status = 'Active',
  });

  final String id;
  final String outletName;
  final String ownerName;
  final String mobileNo;
  final String email;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String gstNumber;
  final String status;

  bool get isActive => status.toLowerCase() != 'inactive';

  /// "address, city, state — pincode", skipping any empty parts.
  String get fullAddress {
    final line = [address, city, state]
        .where((e) => e.trim().isNotEmpty)
        .join(', ');
    if (pincode.trim().isEmpty) return line;
    return line.isEmpty ? pincode : '$line — $pincode';
  }

  factory OutletAccount.fromJson(Map<String, dynamic> j) => OutletAccount(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        outletName: (j['outletName'] ?? '').toString(),
        ownerName: (j['ownerName'] ?? '').toString(),
        mobileNo: (j['mobileNo'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        state: (j['state'] ?? '').toString(),
        pincode: (j['pincode'] ?? '').toString(),
        gstNumber: (j['gstNumber'] ?? '').toString(),
        status: (j['status'] ?? 'Active').toString(),
      );
}