// =============================================================================
// MediCaPlus — Customer API Service
//
// Thin repository over the existing Express backend. It mirrors the base-URL
// resolution used by VendorApiService and talks to the routes that already
// exist (server/routes/postRouter.js):
//
//   GET    /vsArogya/all-products          -> getAllProducts()
//   POST   /vsArogya/add-cart/:id          -> addToCart()        (auth cookie)
//
// Endpoints that are not built on the server yet (orders, profile, addresses)
// have clearly-marked TODO stubs returning mock data, so the UI is fully
// functional today and can be wired to real routes by deleting the fallback.
//
// The service NEVER throws — every method degrades to mock data when the
// server is unreachable, so the app runs with or without the backend.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'catalog.dart';
import 'customer_models.dart';
import 'customer_mock_data.dart';
import 'invoice_pdf.dart';

/// The details returned by the backend when a Razorpay order is created —
/// everything the checkout sheet needs to open. Amount is in paise.
class OnlinePayment {
  const OnlinePayment({
    required this.razorpayOrderId,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  final String razorpayOrderId;
  final int amount; // paise
  final String currency;
  final String keyId; // Razorpay publishable key id (rzp_test_… / rzp_live_…)
}

class CustomerApi {
  CustomerApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 12);

  /// Order placement + invoice generation can be slow when the (free-tier)
  /// backend is cold-starting, so these calls wait much longer than the snappy
  /// cart calls — a cold start must not be mistaken for a failure.
  static const Duration _slowTimeout = Duration(seconds: 60);

  /// Shared base URL — see [ApiConfig]. (Previously pointed at localhost:3000,
  /// which made the customer app talk to a different server than the rest.)
  static String get baseUrl => ApiConfig.baseUrl;

  /// Headers for every call. The session cookie (captured by AuthService at
  /// login) is attached so authenticated routes like the cart accept the call.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // Token auth (works on web + mobile) — preferred.
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        // Cookie auth (mobile fallback).
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  // ---------------------------------------------------------------------------
  // PRODUCTS
  // ---------------------------------------------------------------------------

  /// Loads the catalogue from the backend (GET /vsArogya/all-products), maps it
  /// to [Product]s and fills the shared [Catalog] cache so every screen sees the
  /// same list. Falls back to the cached list (or mock data) if the server is
  /// unreachable, so the shop is never empty offline.
  Future<List<Product>> getProducts() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-products'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['products'] as List?) ?? const [];
        final products = list
            .whereType<Map<String, dynamic>>()
            .map(Product.fromJson)
            .toList();
        Catalog.setProducts(products);
        return products;
      }
    } catch (_) {
      // ignored — fall through to the cache / mock data below
    }
    if (Catalog.all.isNotEmpty) return Catalog.all;
    Catalog.setProducts(MockData.products); // offline seed
    return MockData.products;
  }

  /// Promotional banners for the home carousel.
  /// TODO backend: GET /vsArogya/promo-banners (managed by the marketing team).
  /// Falls back to local banners when the server is unreachable.
  Future<List<PromoBanner>> getPromoBanners() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/promo-banners'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['banners'] as List?) ?? const [];
        final parsed = list
            .whereType<Map<String, dynamic>>()
            .map(PromoBanner.fromJson)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {
      // ignored — fall through to mock banners
    }
    return MockData.banners;
  }

  // ---------------------------------------------------------------------------
  // SAVED ITEMS (wishlist) + SHARE
  //   GET  /all-saved          -> the user's saved products (populated)
  //   POST /save-prod/:id      -> toggle a product's saved state
  //   GET  /share-prod/:id     -> a shareable URL for a product
  // All require auth.
  // ---------------------------------------------------------------------------

  /// The FULL products the user has saved (GET /all-saved, populated). Returns
  /// null on failure so callers keep their current list. Returning full
  /// products (not just ids) means the Saved screen shows them even if they
  /// aren't in the currently-loaded catalogue.
  Future<List<Product>?> getSavedProducts() async {
    final url = '$baseUrl/vsArogya/all-saved';
    debugPrint('[Saved] GET $url (hasToken=${AuthService.authToken != null})');
    try {
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      debugPrint('[Saved] status=${res.statusCode}  '
          'body=${res.body.length > 400 ? '${res.body.substring(0, 400)}…' : res.body}');
      if (!_isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final saved = body['all_save'];
      final list =
          (saved is Map ? saved['savedProducts'] : null) as List? ?? const [];
      final products =
          list.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
      debugPrint('[Saved] parsed ${products.length} saved products');
      return products;
    } catch (e) {
      debugPrint('[Saved] getSavedProducts failed: $e');
      return null;
    }
  }

  /// Toggles a product's saved state on the backend (POST /save-prod/:id).
  /// The server saves it if absent, removes it if present. Offline-safe.
  Future<bool> toggleSavedProduct(String productId) async {
    final url = '$baseUrl/vsArogya/save-prod/$productId';
    debugPrint('[Saved] POST $url (hasToken=${AuthService.authToken != null})');
    try {
      final res =
          await _client.post(Uri.parse(url), headers: _headers).timeout(_timeout);
      debugPrint('[Saved] toggle status=${res.statusCode}  body=${res.body}');
      return _isOk(res);
    } catch (e) {
      debugPrint('[Saved] toggle failed: $e');
      return false;
    }
  }

  /// A shareable URL for [productId] (GET /share-prod/:id). Null on failure so
  /// the caller can fall back to a locally-built link.
  Future<String?> getShareUrl(String productId) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/share-prod/$productId'),
              headers: _headers)
          .timeout(_timeout);
      if (!_isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final url = (body['shareUrl'] ?? '').toString().trim();
      return url.isEmpty ? null : url;
    } catch (_) {
      return null;
    }
  }

  /// A single product by id, read from the [Catalog] cache (populated by
  /// [getProducts]). The backend has no GET /products/:id route.
  Future<Product?> getProduct(String id) async => Catalog.byId(id);

  // ---------------------------------------------------------------------------
  // CART
  //
  // The backend keeps the cart on the logged-in vendor document and identifies
  // products by their Mongo _id (the same id the shop now loads). All routes
  // require the auth cookie. These methods are a BEST-EFFORT mirror of the
  // local CartController: they never throw and never block the UI, so the cart
  // keeps working offline / when not logged in (and on web, where the cookie
  // can't be sent — see AuthService.sessionCookie).
  //   POST   /add-cart/:id          add (or +1 if present)
  //   GET    /getCart-product       fetch cart + total
  //   POST   /increase-cart-item/:id
  //   POST   /dec-cart-itm/:id
  //   DELETE /remove-cart-item/:id
  //   POST   /clear-cart
  // ---------------------------------------------------------------------------

  /// Adds [quantity] of a product. The backend adds 1 per call, so we issue one
  /// add plus (quantity - 1) increases. Returns true on success.
  Future<bool> addToCart(String productId, {int quantity = 1}) async {
    final ok = await _postCart('/vsArogya/add-cart/$productId');
    for (var i = 1; i < quantity; i++) {
      await increaseCartItem(productId);
    }
    return ok;
  }

  Future<bool> increaseCartItem(String productId) =>
      _postCart('/vsArogya/increase-cart-item/$productId');

  Future<bool> decreaseCartItem(String productId) =>
      _postCart('/vsArogya/dec-cart-itm/$productId');

  Future<bool> clearCart() => _postCart('/vsArogya/clear-cart');

  /// Removes a line from the cart (DELETE /remove-cart-item/:id).
  Future<bool> removeFromCart(String productId) async {
    try {
      final res = await _client
          .delete(
            Uri.parse('$baseUrl/vsArogya/remove-cart-item/$productId'),
            headers: _headers,
          )
          .timeout(_timeout);
      return _isOk(res);
    } catch (_) {
      return true; // offline-safe
    }
  }

  /// Fetches the server-side cart as [CartItem]s (GET /getCart-product).
  /// Returns an empty list when offline / not logged in.
  Future<List<CartItem>> getCart() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/getCart-product'),
              headers: _headers)
          .timeout(_timeout);
      if (!_isOk(res)) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = (body['cart'] as List?) ?? const [];
      final items = <CartItem>[];
      for (final entry in raw.whereType<Map<String, dynamic>>()) {
        final productJson = entry['product'];
        if (productJson is! Map<String, dynamic>) continue;
        final qty = (entry['quantity'] as num?)?.toInt() ?? 1;
        items.add(CartItem(
          product: Product.fromJson(productJson),
          quantity: qty,
        ));
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  /// Replaces the server cart with the given local items, AWAITING each call so
  /// the server cart is correct BEFORE /place-order builds an order from it.
  /// Without this, a not-yet-synced cart produces an empty (₹0) order that then
  /// won't show meaningfully in history.
  Future<void> syncCartToServer(List<CartItem> items) async {
    await clearCart();
    for (final item in items) {
      await addToCart(item.product.id, quantity: item.quantity);
    }
  }

  /// Shared POST helper for the cart endpoints (offline-safe, never throws).
  Future<bool> _postCart(String path) async {
    try {
      final res = await _client
          .post(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(_timeout);
      return _isOk(res);
    } catch (_) {
      return true; // keep the local cart authoritative
    }
  }

  /// True when an HTTP response is 2xx and (if it has a JSON body) success:true.
  static bool _isOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    if (res.body.isEmpty) return true;
    try {
      final body = jsonDecode(res.body);
      return body is! Map || body['success'] != false;
    } catch (_) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // ORDERS & PAYMENT
  //   POST   /place-order            create order from the SERVER cart
  //   POST   /create-payment/:id     COD or ONLINE (Razorpay) payment
  //   GET    /get-order              order history
  //   PUT    /cancel-order/:id       cancel an order
  // All require the auth cookie → effectively mobile-only (see AuthService).
  // ---------------------------------------------------------------------------

  /// Places an order from the (already-synced) server cart.
  ///
  /// Returns a record `(orderId, error)`:
  ///  • `orderId` set  → order created on the backend.
  ///  • `error` set    → the server EXPLICITLY rejected the order (e.g. item
  ///    out of stock, coupon already used/expired) — show this to the user and
  ///    do NOT fall back to a local order.
  ///  • both null      → plain network failure (offline / web), callers keep
  ///    their existing offline fallbacks.
  Future<(String?, String?)> placeOrderFromCart(Address address,
      {String? couponCode}) async {
    final url = '$baseUrl/vsArogya/place-order';
    debugPrint('[PlaceOrder] POST $url  (hasToken=${AuthService.authToken != null})');
    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              'address': address.line1,
              'city': address.city,
              'state': address.state,
              'pincode': address.pincode,
              'country': 'India', // backend requires it; app has no country field
              'phoneNo': address.phone,
              // Backend applies the coupon's percentOff to the subtotal.
              if (couponCode != null && couponCode.isNotEmpty)
                'coupan_discount': couponCode,
            }),
          )
          .timeout(_slowTimeout);
      debugPrint('[PlaceOrder] status=${res.statusCode}  body=${res.body.length > 300 ? '${res.body.substring(0, 300)}…' : res.body}');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final order = body['Order'];
        if (order is Map && order['_id'] != null) {
          debugPrint('[PlaceOrder] ✅ backend orderId=${order['_id']}');
          return (order['_id'].toString(), null);
        }
        debugPrint('[PlaceOrder] ⚠️ 2xx but no Order._id in body');
        return (null, null);
      }
      // Explicit rejection — surface the backend's reason (stock / coupon).
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] != null) {
          return (null, body['message'].toString());
        }
      } catch (_) {
        // fall through
      }
      return (null, null);
    } catch (e) {
      debugPrint('[PlaceOrder] ❌ request failed: $e');
      return (null, null);
    }
  }

  /// Places an EXPRESS single-unit order for [productId] straight from the
  /// product page (POST /place-single-ord/:id) — it skips the cart entirely.
  /// The backend fixes quantity to 1 and charges the unit price only (no GST /
  /// coupon), so callers should route multi-quantity buys through the cart /
  /// checkout flow instead. Returns the new order's id, or null when the
  /// backend rejects it (offline / not logged in) so the caller can fall back.
  Future<String?> placeSingleOrder(String productId, Address address) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/place-single-ord/$productId'),
            headers: _headers,
            body: jsonEncode({
              'address': address.line1,
              'city': address.city,
              'state': address.state,
              'pincode': address.pincode,
              'country': 'India', // backend requires it; app has no country field
              'phoneNo': address.phone,
            }),
          )
          .timeout(_timeout);
      if (!_isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final order = body['singleOrder'];
      if (order is Map && order['_id'] != null) return order['_id'].toString();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Records the payment method for [orderId]. Use this for COD — it finalises
  /// the order server-side. For online payments use [createOnlinePayment] +
  /// [verifyPayment] instead (the secure Razorpay flow).
  Future<bool> payForOrder(String orderId,
      {required PaymentMethod method}) async {
    final pm = method == PaymentMethod.cod ? 'COD' : 'ONLINE';
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/create-payment/$orderId'),
            headers: _headers,
            body: jsonEncode({'paymentMethod': pm}),
          )
          .timeout(_timeout);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// Step 1 of the secure online-payment flow: asks the backend to create a
  /// Razorpay order for the already-placed app order [orderId]
  /// (POST /create-payment/:id, paymentMethod ONLINE). Returns the details the
  /// Razorpay checkout sheet needs (order id, amount in paise, currency, key),
  /// or null when the server rejects it / is unreachable.
  Future<OnlinePayment?> createOnlinePayment(String orderId) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/create-payment/$orderId'),
            headers: _headers,
            body: jsonEncode({'paymentMethod': 'ONLINE'}),
          )
          .timeout(_timeout);
      if (!_isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      // Trim defensively — a stray space/newline in the RAZORPAY_KEY_ID env var
      // makes the checkout reject the key with a generic "something went wrong".
      final rzpOrderId = (body['razorpayOrderId'] ?? '').toString().trim();
      final keyId = (body['razorpayKeyId'] ?? '').toString().trim();
      if (rzpOrderId.isEmpty || keyId.isEmpty) return null;
      return OnlinePayment(
        razorpayOrderId: rzpOrderId,
        amount: (body['amount'] as num?)?.toInt() ?? 0,
        currency: (body['currency'] ?? 'INR').toString().trim(),
        keyId: keyId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Step 2 of the secure online-payment flow: sends the Razorpay success
  /// callback fields to the backend (POST /verify-payment), which recomputes and
  /// checks the signature before marking the order paid. Returns true only when
  /// the server confirms the signature is valid.
  Future<bool> verifyPayment({
    required String razorpayOrderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/verify-payment'),
            headers: _headers,
            body: jsonEncode({
              'razorpay_order_id': razorpayOrderId,
              'razorpay_payment_id': paymentId,
              'razorpay_signature': signature,
            }),
          )
          .timeout(_timeout);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// Order history (GET /get-order). Returns null when the call fails (offline /
  /// not logged in) so the caller can keep showing local/mock orders.
  Future<List<Order>?> getOrders() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/get-order'), headers: _headers)
          .timeout(_timeout);
      if (!_isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['orders'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(_orderFromBackend)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Cancels an order (PUT /cancel-order/:id). Offline-safe.
  Future<bool> cancelOrder(String orderId) async {
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl/vsArogya/cancel-order/$orderId'),
              headers: _headers)
          .timeout(_timeout);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// RECOVERY: jab place-order ka response kho jaye (timeout / cold start) par
  /// order server pe ban chuka ho. [knownIds] = placement se PEHLE ke saare
  /// order ids. Server se orders laa ke, sabse naya order dhundta hai jo
  /// [knownIds] me NAHI hai aur pichhle 10 min me bana ho — wahi abhi wala
  /// order hai. Kuch na mile toh null (caller local fallback rakhe).
  /// Purana order kabhi nahi uthayega (diff + time-window dono guards hain).
  Future<String?> recoverPlacedOrderId(Set<String> knownIds) async {
    final orders = await getOrders();
    if (orders == null || orders.isEmpty) return null;
    orders.sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    for (final o in orders) {
      if (o.placedAt.isBefore(cutoff)) break; // newest-first — aage sab purane
      if (knownIds.contains(o.id)) continue;
      debugPrint('[PlaceOrder] 🔁 recovered lost orderId=${o.id}');
      return o.id;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // INVOICE — triple-fallback PDF resolver (used by preview + download)
  // ---------------------------------------------------------------------------

  /// Fetches ONLY the SERVER's invoice PDF for [order] — the `prev-invoice/:id`
  /// endpoint first (it 302-redirects to the hosted PDF, which we follow), then
  /// the stored [Order.invoiceUrl]. Returns `(bytes, error)`:
  ///  • `bytes` → the server produced a real PDF (this is the API's output).
  ///  • `error` → a short reason (HTTP status / message), so the preview can
  ///    SHOW what the server said instead of silently masking it on-device.
  Future<(Uint8List?, String?)> fetchServerInvoice(Order order) async {
    // DEBUG: which order id are we about to use for the invoice?
    debugPrint('[Invoice] order.id="${order.id}"  invoiceUrl=${order.invoiceUrl}');

    // Only a real backend order (24-hex Mongo ObjectId) has a server invoice.
    // Sending a local fallback id (e.g. "MCP-32790") to the server just causes a
    // Mongoose CastError/500, so short-circuit with a clear message here.
    if (!RegExp(r'^[a-f0-9]{24}$').hasMatch(order.id)) {
      debugPrint('[Invoice] "${order.id}" is NOT a backend id → skipping server call');
      final viaUrl = await _urlPdf(order);
      if (viaUrl != null) return (viaUrl, null);
      return (
        null,
        "This order isn't synced with the server yet, so its invoice isn't "
        "available. It'll appear once the order is placed successfully on the "
        "server.",
      );
    }
    final url = '$baseUrl/vsArogya/prev-invoice/${order.id}';
    try {
      debugPrint('[Invoice] GET $url');
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 30));
      debugPrint('[Invoice] status=${res.statusCode}  bytes=${res.bodyBytes.length}  '
          'isPdf=${InvoicePdf.looksLikePdf(res.bodyBytes)}  finalUrl=${res.request?.url}');
      if (res.statusCode == 200 && InvoicePdf.looksLikePdf(res.bodyBytes)) {
        return (res.bodyBytes, null);
      }
      // Endpoint didn't return a PDF — try the stored url, else report why so
      // the UI can show the exact server reason.
      final viaUrl = await _urlPdf(order);
      if (viaUrl != null) return (viaUrl, null);
      return (null, _errorMessage(res));
    } catch (e) {
      debugPrint('[Invoice] request failed: $e');
      final viaUrl = await _urlPdf(order);
      if (viaUrl != null) return (viaUrl, null);
      return (null, 'Could not reach the invoice server. Check your connection.');
    }
  }

  /// The PDF from the order's stored [Order.invoiceUrl] (public), or null.
  Future<Uint8List?> _urlPdf(Order order) async {
    final url = order.invoiceUrl;
    if (url != null && url.startsWith('http')) {
      return _getPdfBytes(Uri.parse(url));
    }
    return null;
  }

  static String _errorMessage(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['message'] != null) return b['message'].toString();
    } catch (_) {
      // non-JSON body
    }
    return 'Server returned HTTP ${res.statusCode}.';
  }

  /// GETs [uri] and returns the body only if it is a real PDF (`%PDF` magic),
  /// following redirects. Null on any failure — callers fall back.
  Future<Uint8List?> _getPdfBytes(Uri uri, {Map<String, String>? headers}) async {
    try {
      final res = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && InvoicePdf.looksLikePdf(res.bodyBytes)) {
        return res.bodyBytes;
      }
    } catch (_) {
      // fall through
    }
    return null;
  }

  /// Maps a backend order document onto the app's [Order]. The backend stores a
  /// single totalAmount (no coupon/GST/delivery split), so it's folded into
  /// subtotal with the rest zeroed.
  static Order _orderFromBackend(Map<String, dynamic> j) {
    final itemsRaw = (j['orderItems'] as List?) ?? const [];
    final items = <OrderItem>[];
    for (final it in itemsRaw.whereType<Map<String, dynamic>>()) {
      final prod = it['product'];
      final pm = prod is Map ? prod : const {};
      items.add(OrderItem(
        title: (pm['title'] ?? '').toString(),
        brand: (pm['category'] ?? '').toString(),
        price: _num(it['orderPrice'] ?? pm['price']),
        quantity: (it['quantity'] as num?)?.toInt() ?? 1,
      ));
    }
    final addr = (j['shippingAddress'] as Map?) ?? const {};
    final total = _num(j['totalAmount']);
    return Order(
      id: (j['_id'] ?? '').toString(),
      placedAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      status: _statusFromBackend((j['orderStatus'] ?? 'Pending').toString()),
      items: items,
      address: Address(
        id: '',
        label: 'Delivery',
        fullName: '',
        phone: (addr['phoneNo'] ?? '').toString(),
        line1: (addr['address'] ?? '').toString(),
        city: (addr['city'] ?? '').toString(),
        state: (addr['state'] ?? '').toString(),
        pincode: (addr['pincode'] ?? '').toString(),
      ),
      paymentMethod: (j['paymentMethod'] ?? '').toString() == 'COD'
          ? PaymentMethod.cod
          : PaymentMethod.razorpay,
      subtotal: total,
      deliveryFee: 0,
      gst: 0,
      discount: 0,
      // Server-hosted invoice PDF, when the backend saved one on the order.
      invoiceUrl: () {
        final u = (j['invoiceUrl'] ?? '').toString().trim();
        return u.isEmpty ? null : u;
      }(),
    );
  }

  static OrderStatus _statusFromBackend(String s) => switch (s) {
        'Confirm Order' => OrderStatus.confirmed,
        'Shipped' => OrderStatus.shipped,
        'Out for Delivery' => OrderStatus.outForDelivery,
        'Delivered' => OrderStatus.delivered,
        'Cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.placed,
      };

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  // ---------------------------------------------------------------------------
  // ADDRESSES  (TODO backend: CRUD under /vsArogya/addresses)
  // ---------------------------------------------------------------------------

  Future<List<Address>> getAddresses() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return MockData.addresses;
  }

  // ---------------------------------------------------------------------------
  // COUPONS  (GET /vsArogya/coupons — only active, non-expired are returned)
  // ---------------------------------------------------------------------------

  /// Active coupons the customer can apply at checkout. Falls back to the local
  /// mock coupons when the server is unreachable.
  Future<List<Coupon>> getCoupons() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/coupons'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['coupons'] as List?) ?? const [];
        final parsed = list
            .whereType<Map<String, dynamic>>()
            .where((c) => c['active'] != false && c['expired'] != true)
            .map(Coupon.fromJson)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {
      // ignored — fall back to mock coupons
    }
    return MockData.coupons;
  }

  void dispose() => _client.close();
}
