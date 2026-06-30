// =============================================================================
// MediCaPlus — Marketing API Service
//
// Talks to the product endpoints the marketing team owns:
//   POST   /vsArogya/add-product      (multipart: fields + `image`)
//   GET    /vsArogya/all-products     (shared with the customer shop)
//   DELETE /vsArogya/delete-product/:id
//
// Maps the backend product document <-> the InventoryProduct UI model.
// Reads the shared base URL from ApiConfig.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../services/api_config.dart';
import '../customer/customer_models.dart' show PromoBanner;
import 'marketing_models.dart';

class MarketingApi {
  MarketingApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 30);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Creates a product on the backend. Returns true on success.
  /// The backend requires the `image` file part.
  Future<bool> addProduct(InventoryProduct p, XFile image) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/vsArogya/add-product'),
      );
      req.fields.addAll({
        'title': p.name,
        'description': p.description,
        'price': p.price.toString(),
        'category': _categoryToId(p.category), // store canonical id
        'mrp': p.mrp?.toString() ?? '',
        'brand': p.brand,
        'code': p.code,
        'manufacturer': p.manufacturer,
        'marketedBy': p.marketedBy,
        'stock': p.stock.toString(),
        'active': p.active.toString(),
        'packOf': p.packOf.toString(),
        'hsnCode': p.hsnCode,
        'gstPercent': p.gstPercent.toString(),
        'discountPercent': p.discountPercent.toString(),
        'lowThreshold': p.lowThreshold.toString(),
        'prescriptionRequired': p.prescriptionRequired.toString(),
        'packInfo': p.packInfo,
        if (p.badge != null) 'badge': p.badge!,
      });

      final bytes = await image.readAsBytes();
      final name = _safeName(image);
      req.files.add(http.MultipartFile.fromBytes(
        'image', // backend multer field: upload.single("image")
        bytes,
        filename: name,
        contentType: _contentTypeFor(name),
      ));

      final streamed = await req.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// Updates a product (PUT /update-product/:id). Sends all fields; only a new
  /// image part is included when [image] is provided. Returns true on success.
  Future<bool> updateProduct(InventoryProduct p, {XFile? image}) async {
    try {
      final req = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/vsArogya/update-product/${p.id}'),
      );
      req.fields.addAll({
        'title': p.name,
        'description': p.description,
        'price': p.price.toString(),
        'category': _categoryToId(p.category),
        'mrp': p.mrp?.toString() ?? '',
        'brand': p.brand,
        'code': p.code,
        'manufacturer': p.manufacturer,
        'marketedBy': p.marketedBy,
        'stock': p.stock.toString(),
        'active': p.active.toString(),
        'packOf': p.packOf.toString(),
        'hsnCode': p.hsnCode,
        'gstPercent': p.gstPercent.toString(),
        'discountPercent': p.discountPercent.toString(),
        'lowThreshold': p.lowThreshold.toString(),
        'prescriptionRequired': p.prescriptionRequired.toString(),
        'packInfo': p.packInfo,
        if (p.badge != null) 'badge': p.badge!,
      });
      if (image != null) {
        final bytes = await image.readAsBytes();
        final name = _safeName(image);
        req.files.add(http.MultipartFile.fromBytes('image', bytes,
            filename: name, contentType: _contentTypeFor(name)));
      }
      final streamed = await req.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// Toggles only a product's active flag (PUT /update-product/:id).
  Future<bool> setActive(String id, bool active) async {
    try {
      final req = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/vsArogya/update-product/$id'),
      );
      req.fields['active'] = active.toString();
      final streamed = await req.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// All products from the backend, mapped to [InventoryProduct]. Returns null
  /// on failure so callers can keep the local list.
  Future<List<InventoryProduct>?> getProducts() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-products'))
          .timeout(_timeout);
      if (!_isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['products'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(_toInventory)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Deletes a product by id. Offline-safe.
  Future<bool> deleteProduct(String id) async {
    try {
      final res = await _client
          .delete(Uri.parse('$baseUrl/vsArogya/delete-product/$id'))
          .timeout(_timeout);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  // --- mapping & helpers ------------------------------------------------------

  static InventoryProduct _toInventory(Map<String, dynamic> j) {
    String? image;
    final raw = j['image'];
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      image = (raw.first as Map)['url'] as String?;
    }
    return InventoryProduct(
      id: (j['_id'] ?? '').toString(),
      name: (j['title'] ?? '').toString(),
      brand: (j['brand'] ?? '').toString(),
      code: (j['code'] ?? '').toString(),
      manufacturer: (j['manufacturer'] ?? '').toString(),
      marketedBy: (j['marketedBy'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      price: _num(j['price']),
      mrp: j['mrp'] == null ? null : _num(j['mrp']),
      stock: _int(j['stock']),
      active: j['active'] is bool ? j['active'] as bool : true,
      category: _categoryToLabel(j['category']),
      packOf: _int(j['packOf'], 1),
      hsnCode: (j['hsnCode'] ?? '').toString(),
      gstPercent: _num(j['gstPercent']),
      discountPercent: _num(j['discountPercent']),
      lowThreshold: _int(j['lowThreshold'], 10),
      prescriptionRequired: j['prescriptionRequired'] == true,
      rating: j['rating'] == null ? 4.5 : _num(j['rating']),
      reviewCount: _int(j['reviewCount']),
      badge: j['badge'] as String?,
      packInfo: (j['packInfo'] ?? '').toString(),
      imageUrl: image,
    );
  }

  /// Marketing uses human labels (kMedicineCategories); the backend + customer
  /// filter use short ids. These two keep both sides in sync regardless of
  /// which form a stored value is in.
  static String _categoryToId(String value) {
    final s = value.trim().toLowerCase();
    if (s.contains('inject')) return 'injections';
    if (s.contains('vaccin')) return 'vaccines';
    if (s.contains('medic')) return 'medicine';
    return s.isEmpty ? 'medicine' : s;
  }

  static String _categoryToLabel(Object? value) {
    switch (_categoryToId((value ?? '').toString())) {
      case 'injections':
        return 'Lifesaving Injections';
      case 'vaccines':
        return 'Vaccines';
      default:
        return 'Medicine';
    }
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

  static String _safeName(XFile file) {
    final name = file.name;
    if (name.contains('.')) return name;
    final ext = switch (file.mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    return '$name.$ext';
  }

  static MediaType _contentTypeFor(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }

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
}

/// Promo banners (customer home carousel), managed by marketing.
///   GET    /vsArogya/promo-banners
///   POST   /vsArogya/promo-banners
///   DELETE /vsArogya/promo-banners/:id
class BannerApi {
  BannerApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);
  static String get baseUrl => ApiConfig.baseUrl;

  Future<List<PromoBanner>?> getBanners() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/promo-banners'))
          .timeout(_timeout);
      if (!MarketingApi._isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['banners'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(PromoBanner.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> addBanner(PromoBanner b) async {
    try {
      final j = b.toJson();
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/promo-banners'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tag': j['tag'],
              'title': j['title'],
              'ctaLabel': j['ctaLabel'],
              'startColor': j['startColor'],
              'endColor': j['endColor'],
              if (j['categoryId'] != null) 'categoryId': j['categoryId'],
            }),
          )
          .timeout(_timeout);
      return MarketingApi._isOk(res);
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteBanner(String id) async {
    try {
      final res = await _client
          .delete(Uri.parse('$baseUrl/vsArogya/promo-banners/$id'))
          .timeout(_timeout);
      return MarketingApi._isOk(res);
    } catch (_) {
      return false;
    }
  }
}

/// Discount coupons (marketing manages; customers apply at checkout).
///   GET    /vsArogya/coupons
///   POST   /vsArogya/coupons
///   PUT    /vsArogya/coupons/:code/toggle
///   DELETE /vsArogya/coupons/:code
class CouponApi {
  CouponApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);
  static String get baseUrl => ApiConfig.baseUrl;

  Future<List<MarketingCoupon>?> getCoupons() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/coupons'))
          .timeout(_timeout);
      if (!MarketingApi._isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['coupons'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MarketingCoupon.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Creates a coupon. Returns null on success, or a user-facing error message.
  Future<String?> addCoupon({
    required String code,
    String description = '',
    required double percentOff,
    double? maxDiscount,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/vsArogya/coupons'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': code,
              'description': description,
              'percentOff': percentOff,
              'maxDiscount': ?maxDiscount,
            }),
          )
          .timeout(_timeout);
      if (MarketingApi._isOk(res)) return null;
      try {
        final b = jsonDecode(res.body);
        if (b is Map && b['message'] != null) return b['message'].toString();
      } catch (_) {}
      return 'Could not create coupon';
    } catch (_) {
      return 'Network error — try again';
    }
  }

  Future<bool> toggleCoupon(String code) async {
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl/vsArogya/coupons/$code/toggle'))
          .timeout(_timeout);
      return MarketingApi._isOk(res);
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCoupon(String code) async {
    try {
      final res = await _client
          .delete(Uri.parse('$baseUrl/vsArogya/coupons/$code'))
          .timeout(_timeout);
      return MarketingApi._isOk(res);
    } catch (_) {
      return false;
    }
  }
}

/// Incoming orders for the marketing fulfilment view.
///   GET /vsArogya/all-orders
///   PUT /vsArogya/confirm-order/:id     (Accept)
///   PUT /vsArogya/shipped-order/:id     (Ship)
///   PUT /vsArogya/delivered-prder/:id   (Mark Done)
class MarketingOrdersApi {
  MarketingOrdersApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);
  static String get baseUrl => ApiConfig.baseUrl;

  Future<List<MarketingOrder>?> getOrders() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-orders'))
          .timeout(_timeout);
      if (!MarketingApi._isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['allOrders'] as List?) ?? const [];
      return list.whereType<Map<String, dynamic>>().map(_fromBackend).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> confirmOrder(String id) => _put('/vsArogya/confirm-order/$id');
  Future<bool> shipOrder(String id) => _put('/vsArogya/shipped-order/$id');
  Future<bool> deliverOrder(String id) => _put('/vsArogya/delivered-prder/$id');

  Future<bool> _put(String path) async {
    try {
      final res =
          await _client.put(Uri.parse('$baseUrl$path')).timeout(_timeout);
      return MarketingApi._isOk(res);
    } catch (_) {
      return false;
    }
  }

  static MarketingOrder _fromBackend(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    final itemsRaw = (j['orderItems'] as List?) ?? const [];
    final items = <MarketingOrderLine>[];
    for (final it in itemsRaw.whereType<Map>()) {
      final p = it['product'] is Map ? it['product'] as Map : const {};
      items.add(MarketingOrderLine(
        name: (p['title'] ?? 'Item').toString(),
        brand: (p['brand'] ?? p['category'] ?? '').toString(),
        quantity: (it['quantity'] as num?)?.toInt() ?? 1,
        price: _num(it['orderPrice'] ?? p['price']),
      ));
    }
    final addr = j['shippingAddress'] is Map ? j['shippingAddress'] as Map : const {};
    final addressStr = [addr['address'], addr['city'], addr['state'], addr['pincode']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(', ');
    return MarketingOrder(
      id: (j['_id'] ?? '').toString(),
      buyer: (user['store_name'] ??
              user['contact_person_name'] ??
              'Customer')
          .toString(),
      placedAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      amount: _num(j['totalAmount']),
      status: _statusFromBackend((j['orderStatus'] ?? 'Pending').toString()),
      items: items,
      phone: (addr['phoneNo'] ?? '').toString(),
      address: addressStr,
    );
  }

  static MarketingOrderStatus _statusFromBackend(String s) => switch (s) {
        'Confirm Order' => MarketingOrderStatus.packing,
        'Shipped' => MarketingOrderStatus.shipped,
        'Out for Delivery' => MarketingOrderStatus.shipped,
        'Delivered' => MarketingOrderStatus.done,
        'Cancelled' => MarketingOrderStatus.done,
        _ => MarketingOrderStatus.pending,
      };

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
