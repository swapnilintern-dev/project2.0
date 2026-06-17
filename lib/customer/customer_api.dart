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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'customer_models.dart';
import 'customer_mock_data.dart';

class CustomerApi {
  CustomerApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 12);

  /// Same host resolution strategy as VendorApiService.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  /// Session cookie returned by the login endpoint, attached to authed calls.
  /// The login screen can set this after a successful POST /vsArogya/login.
  static String? authCookie;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authCookie != null) 'Cookie': ?authCookie,
      };

  // ---------------------------------------------------------------------------
  // PRODUCTS
  // ---------------------------------------------------------------------------

  /// GET /vsArogya/all-products
  /// Falls back to the local catalogue when the server is unreachable.
  Future<List<Product>> getProducts() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-products'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['products'] as List?) ?? const [];
        final parsed =
            list.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } on TimeoutException {
      // ignored — fall through to mock data
    } on SocketException {
      // ignored — server not running
    } catch (_) {
      // ignored — malformed response
    }
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

  /// GET /vsArogya/all-products then filter by id.
  /// (The backend has no single-product route yet — TODO: GET /products/:id.)
  Future<Product?> getProduct(String id) async {
    final all = await getProducts();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // CART  (POST /vsArogya/add-cart/:id — requires the auth cookie)
  // ---------------------------------------------------------------------------

  /// Returns true when the item was accepted by the server. When the backend
  /// is offline this optimistically returns true so the local cart still works.
  Future<bool> addToCart(String productId, {int quantity = 1}) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/add-cart/$productId'),
            headers: _headers,
            body: jsonEncode({'quantity': quantity}),
          )
          .timeout(_timeout);
      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : const {};
      return res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body['success'] == true;
    } catch (_) {
      // Offline / not logged in: keep the local cart authoritative.
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // ORDERS  (TODO backend: POST /vsArogya/orders, GET /vsArogya/orders)
  // ---------------------------------------------------------------------------

  /// TODO: POST /vsArogya/orders — currently returns the order unchanged so the
  /// confirmation flow works locally.
  Future<Order> placeOrder(Order order) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return order;
  }

  /// TODO: GET /vsArogya/orders — currently seeded from mock data.
  Future<List<Order>> getOrders() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return MockData.seedOrders();
  }

  // ---------------------------------------------------------------------------
  // ADDRESSES  (TODO backend: CRUD under /vsArogya/addresses)
  // ---------------------------------------------------------------------------

  Future<List<Address>> getAddresses() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return MockData.addresses;
  }

  void dispose() => _client.close();
}
