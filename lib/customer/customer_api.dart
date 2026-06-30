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

import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'catalog.dart';
import 'customer_models.dart';
import 'customer_mock_data.dart';

class CustomerApi {
  CustomerApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 12);

  /// Shared base URL — see [ApiConfig]. (Previously pointed at localhost:3000,
  /// which made the customer app talk to a different server than the rest.)
  static String get baseUrl => ApiConfig.baseUrl;

  /// Headers for every call. The session cookie (captured by AuthService at
  /// login) is attached so authenticated routes like the cart accept the call.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
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

  /// Places an order from the (already-synced) server cart. Returns the new
  /// order's id, or null if the backend didn't accept it (offline / web / empty
  /// server cart) so the caller can fall back to a local order.
  Future<String?> placeOrderFromCart(Address address) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/place-order'),
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
      final order = body['Order'];
      if (order is Map && order['_id'] != null) return order['_id'].toString();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Records the payment method for [orderId]. COD finalises the order; ONLINE
  /// makes the backend create a Razorpay order (verifying it needs a server
  /// verify route — not wired yet).
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
    );
  }

  static OrderStatus _statusFromBackend(String s) => switch (s) {
        'Confirm Order' => OrderStatus.confirmed,
        'Shipped' => OrderStatus.packed,
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
