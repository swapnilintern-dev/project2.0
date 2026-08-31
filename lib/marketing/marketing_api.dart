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
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/product_media.dart';
import '../customer/customer_models.dart' show PromoBanner;
import '../customer/invoice_pdf.dart' show InvoicePdf;
import '../shared/api_date.dart';
import '../widgets/batch_selector.dart' show BatchOption, BatchAllocation;
import 'marketing_models.dart';

class MarketingApi {
  MarketingApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 30);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Uploads can be large (up to 10 images + a 100 MB video); give them room.
  static const Duration _uploadTimeout = Duration(minutes: 5);

  /// The scalar (non-media) product fields.
  ///
  /// [includeInventory] carries the legacy single-batch fields (stock / batch_no
  /// / exp_date). It is TRUE on create (the backend materialises them into the
  /// product's first batch) but FALSE on update — an existing product's stock is
  /// owned by its batches (managed via [BatchApi]), so an edit must never write
  /// a scalar stock/batch/expiry that would fight the batch model.
  Map<String, String> _productFields(
    InventoryProduct p, {
    bool includeInventory = true,
  }) =>
      {
        'title': p.name,
        'description': p.description,
        'price': p.price.toString(),
        'category': _categoryToId(p.category), // store canonical id
        'mrp': p.mrp?.toString() ?? '',
        'brand': p.brand,
        'code': p.code,
        'manufacturer': p.manufacturer,
        'marketedBy': p.marketedBy,
        'active': p.active.toString(),
        'packOf': p.packOf.toString(),
        'hsnCode': p.hsnCode,
        'gstPercent': p.gstPercent.toString(),
        'discountPercent': p.discountPercent.toString(),
        'lowThreshold': p.lowThreshold.toString(),
        'prescriptionRequired': p.prescriptionRequired.toString(),
        'packInfo': p.packInfo,
        if (includeInventory) 'stock': p.stock.toString(),
        if (includeInventory) 'batch_no': p.batchNo,
        // Send an ISO date the backend parses with `new Date(...)`; omit when
        // absent so an edit that doesn't touch expiry leaves it unchanged.
        if (includeInventory && p.expiryDate != null)
          'exp_date': apiCalendarDate(p.expiryDate!),
        if (p.badge != null) 'badge': p.badge!,
      };

  /// Creates a product on the backend with one or more [images] (the first is
  /// the primary) and an optional promotional [video]. [onProgress] reports
  /// upload progress in the range 0.0–1.0. Returns true on success.
  Future<bool> addProduct(
    InventoryProduct p, {
    required List<XFile> images,
    XFile? video,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/vsArogya/add-product'),
      );
      req.fields.addAll(_productFields(p));
      for (final img in images) {
        req.files.add(await _imagePart('images', img));
      }
      if (video != null) req.files.add(await _videoPart(video));

      final res = await _sendWithProgress(req, onProgress);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// Updates a product (PUT /update-product/:id).
  ///
  /// [keptImages] is the ordered set of EXISTING images the edit retains — the
  /// backend deletes any current image not in this list (orphan-free) and keeps
  /// these in the given order. [newImages] are freshly picked files, appended
  /// after the kept ones. For the video: pass [video] to replace it,
  /// [removeVideo] to delete it, or neither to leave it unchanged.
  ///
  /// [onProgress] reports 0.0–1.0. Returns true on success.
  Future<bool> updateProduct(
    InventoryProduct p, {
    required List<ProductMedia> keptImages,
    List<XFile> newImages = const [],
    XFile? video,
    bool removeVideo = false,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final req = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/vsArogya/update-product/${p.id}'),
      );
      // Inventory (stock/batch/expiry) is owned by the batch model on an edit —
      // see BatchApi — so it is intentionally left out here.
      req.fields.addAll(_productFields(p, includeInventory: false));
      req.fields['keptImages'] = ProductMedia.encodeKept(keptImages);
      if (removeVideo) req.fields['removeVideo'] = 'true';
      for (final img in newImages) {
        req.files.add(await _imagePart('images', img));
      }
      if (video != null) req.files.add(await _videoPart(video));

      final res = await _sendWithProgress(req, onProgress);
      return _isOk(res);
    } catch (_) {
      return false;
    }
  }

  /// Builds an image multipart part under [field] with the right filename +
  /// content-type.
  Future<http.MultipartFile> _imagePart(String field, XFile image) async {
    final bytes = await image.readAsBytes();
    final name = _safeName(image);
    return http.MultipartFile.fromBytes(field, bytes,
        filename: name, contentType: _contentTypeFor(name));
  }

  /// Builds the `video` multipart part.
  Future<http.MultipartFile> _videoPart(XFile video) async {
    final bytes = await video.readAsBytes();
    final name = _safeVideoName(video);
    return http.MultipartFile.fromBytes('video', bytes,
        filename: name, contentType: _videoContentTypeFor(name));
  }

  /// Sends [req], reporting byte-level upload progress (0.0–1.0) via
  /// [onProgress] by wrapping the finalized body in a counting stream. Falls
  /// back to a plain send when no callback is supplied.
  Future<http.Response> _sendWithProgress(
    http.MultipartRequest req,
    void Function(double progress)? onProgress,
  ) async {
    if (onProgress == null) {
      final streamed = await req.send().timeout(_uploadTimeout);
      return http.Response.fromStream(streamed);
    }

    final total = req.contentLength;
    var sent = 0;
    final wrapped = _ProgressRequest(req, (chunk) {
      sent += chunk;
      if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
    });
    final streamed = await _client.send(wrapped).timeout(_uploadTimeout);
    onProgress(1.0);
    return http.Response.fromStream(streamed);
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
    final images = ProductMedia.parseImages(j['image']);
    final video = ProductMedia.parseVideo(j['video']);
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
      batchNo: (j['batch_no'] ?? '').toString(),
      expiryDate: _date(j['exp_date']),
      // Live flag computed server-side from the current date; default false so
      // older products (no expiry stored) never show the alert.
      isExpiringSoon: j['isExpiringSoon'] == true,
      // No fabricated rating — 0 when the backend doesn't provide one.
      rating: j['rating'] == null ? 0 : _num(j['rating']),
      reviewCount: _int(j['reviewCount']),
      badge: j['badge'] as String?,
      packInfo: (j['packInfo'] ?? '').toString(),
      images: images,
      video: video,
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

  /// Parses a backend date (ISO string, or a null) into a [DateTime], or null.
  static DateTime? _date(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty || s == 'N/A') return null;
    return DateTime.tryParse(s);
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

  static String _safeVideoName(XFile file) {
    final name = file.name;
    if (name.contains('.')) return name;
    final ext = switch (file.mimeType) {
      'video/quicktime' => 'mov',
      'video/x-matroska' => 'mkv',
      'video/webm' => 'webm',
      _ => 'mp4',
    };
    return '$name.$ext';
  }

  static MediaType _videoContentTypeFor(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'mov' => MediaType('video', 'quicktime'),
      'mkv' => MediaType('video', 'x-matroska'),
      'webm' => MediaType('video', 'webm'),
      _ => MediaType('video', 'mp4'),
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

/// Multi-batch inventory for a product (Marketing "Add New Batch" workflow).
///   GET    /vsArogya/product/:id/batches
///   POST   /vsArogya/product/:id/batches
///   PUT    /vsArogya/batch/:batchId
///   DELETE /vsArogya/batch/:batchId
///
/// Every mutation is applied on the backend immediately; the server recomputes
/// the product's total stock (= SUM of batch available quantities) so the shop
/// and inventory list stay in sync after a refresh.
class BatchApi {
  BatchApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 30);
  static String get baseUrl => ApiConfig.baseUrl;

  /// Same staff-session headers the other marketing endpoints send (the routes
  /// are unauthenticated like product CRUD, but sending the token is harmless).
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  /// All batches for [productId], in FEFO order. Returns `(batches, error)` —
  /// batches on success, else a user-facing message.
  Future<(List<ProductBatch>?, String?)> getBatches(String productId) async {
    final url = '$baseUrl/vsArogya/product/$productId/batches';
    try {
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (!MarketingApi._isOk(res)) {
        return (
          null,
          MarketingOrdersApi._serverMessage(res) ?? 'Could not load batches',
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['batches'] as List?) ?? const [];
      final batches = list
          .whereType<Map<String, dynamic>>()
          .map(ProductBatch.fromJson)
          .toList();
      return (batches, null);
    } catch (_) {
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// The product's SELLABLE catalog batches — available > 0 and not expired —
  /// in the backend's FEFO order (nearest expiry first). This is the list every
  /// batch picker shows: an expired or emptied lot is filtered out server-side,
  /// so it can never be selected.
  ///
  /// Returns `(batches, error)`.
  Future<(List<BatchOption>?, String?)> getAvailableBatches(
      String productId) async {
    final url = '$baseUrl/vsArogya/product/$productId/available-batches';
    try {
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (!MarketingApi._isOk(res)) {
        return (
          null,
          MarketingOrdersApi._serverMessage(res) ?? 'Could not load batches',
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['batches'] as List?) ?? const [];
      return (
        list
            .whereType<Map<String, dynamic>>()
            .map(BatchOption.fromJson)
            .toList(),
        null,
      );
    } catch (_) {
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Asks the backend to allocate [quantity] of [productId] across its catalog
  /// batches FEFO, honouring any [overrides] the user pinned. Nothing is
  /// deducted — this is the dry run that keeps the app from ever computing
  /// inventory itself.
  ///
  /// Returns `(allocations, remaining, error)`; `remaining` > 0 means the
  /// catalog cannot cover the quantity from sellable lots.
  Future<(List<BatchAllocation>, int, String?)> previewAllocation(
    String productId,
    int quantity, {
    List<BatchAllocation> overrides = const [],
  }) async {
    final url = '$baseUrl/vsArogya/allocate-preview';
    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              'productId': productId,
              'quantity': quantity,
              if (overrides.isNotEmpty)
                'overrides': overrides.map((a) => a.toJson()).toList(),
            }),
          )
          .timeout(_timeout);

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (!MarketingApi._isOk(res)) {
        return (
          const <BatchAllocation>[],
          quantity,
          (body['message'] ?? 'Could not allocate batches').toString(),
        );
      }
      final allocs = ((body['allocations'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BatchAllocation.fromJson)
          .toList();
      final remaining = (body['remaining'] as num?)?.toInt() ?? 0;
      return (allocs, remaining, null);
    } catch (_) {
      return (
        const <BatchAllocation>[],
        quantity,
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Adds a new batch to [productId]. Returns null on success, else a
  /// user-facing error (the server explains duplicates / bad quantities).
  Future<String?> addBatch(String productId, ProductBatch b) async {
    final url = '$baseUrl/vsArogya/product/$productId/batches';
    try {
      final res = await _client
          .post(Uri.parse(url), headers: _headers, body: jsonEncode(b.toJson()))
          .timeout(_timeout);
      if (MarketingApi._isOk(res)) return null;
      return MarketingOrdersApi._serverMessage(res) ?? 'Could not add batch';
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  /// Updates the batch [batchId]. Returns null on success, else an error.
  Future<String?> updateBatch(String batchId, ProductBatch b) async {
    final url = '$baseUrl/vsArogya/batch/$batchId';
    try {
      final res = await _client
          .put(Uri.parse(url), headers: _headers, body: jsonEncode(b.toJson()))
          .timeout(_timeout);
      if (MarketingApi._isOk(res)) return null;
      return MarketingOrdersApi._serverMessage(res) ?? 'Could not update batch';
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  /// Deletes the batch [batchId]. Returns null on success, else an error.
  Future<String?> deleteBatch(String batchId) async {
    final url = '$baseUrl/vsArogya/batch/$batchId';
    try {
      final res = await _client
          .delete(Uri.parse(url), headers: _headers)
          .timeout(_timeout);
      if (MarketingApi._isOk(res)) return null;
      return MarketingOrdersApi._serverMessage(res) ?? 'Could not delete batch';
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }
}

/// Wraps a [http.MultipartRequest] so byte-level upload progress can be
/// observed. The finalized body is piped through a counting transformer that
/// calls [_onChunk] with the size of each chunk as it is written to the socket.
///
/// The multipart content-type (with its boundary) and content-length are only
/// known after [http.MultipartRequest.finalize], so both are copied across
/// inside [finalize] — which the HTTP client invokes before it reads the
/// request headers.
class _ProgressRequest extends http.BaseRequest {
  _ProgressRequest(this._inner, this._onChunk)
      : super(_inner.method, _inner.url);

  final http.MultipartRequest _inner;
  final void Function(int bytes) _onChunk;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  http.ByteStream finalize() {
    super.finalize();
    final byteStream = _inner.finalize();
    // Now that the boundary + content-type are set, mirror the inner headers.
    headers.addAll(_inner.headers);
    final counted = byteStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          _onChunk(data.length);
          sink.add(data);
        },
      ),
    );
    return http.ByteStream(counted);
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

  /// Creates a banner via multipart (POST /promo-banners). When [image] is
  /// provided it is uploaded as the `image` file part (a full-image creative);
  /// when null a text/gradient banner is created (backend needs a title then).
  Future<bool> addBanner(PromoBanner b, [XFile? image]) async {
    try {
      final j = b.toJson();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/vsArogya/promo-banners'),
      );
      req.fields.addAll({
        'tag': (j['tag'] ?? 'OFFER').toString(),
        'title': (j['title'] ?? '').toString(),
        'ctaLabel': (j['ctaLabel'] ?? 'Shop Now').toString(),
        'startColor': (j['startColor'] ?? '#4CAF82').toString(),
        'endColor': (j['endColor'] ?? '#2E7D5E').toString(),
        if (j['categoryId'] != null) 'categoryId': j['categoryId'].toString(),
      });

      if (image != null) {
        final bytes = await image.readAsBytes();
        final name = MarketingApi._safeName(image);
        req.files.add(http.MultipartFile.fromBytes(
          'image', // backend multer field: upload.single("image")
          bytes,
          filename: name,
          contentType: MarketingApi._contentTypeFor(name),
        ));
      }

      final streamed = await req.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
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
///
/// ═══════════════════════════════════════════════════════════════════════════
/// BACKEND CONTRACT — order accept · invoice · stock · manual orders
/// (Full copy with JSON examples: ORDER_INVOICE_STOCK_INTEGRATION.md, repo
/// root. The server folder is intentionally untouched by the app team — the
/// backend developer implements these against the routes named below.)
///
/// 1) ACCEPT + INVOICE + STOCK DEDUCT — PUT /vsArogya/confirm-order/:id
///    Expected server behaviour (single source of truth for stock):
///      • Validate stock for EVERY line first. If any line has
///        product.stock < quantity, do NOT change anything and reply
///        409 { "success": false,
///              "message": "Insufficient stock for <title>: available X, ordered Y" }
///        (this client surfaces `message` verbatim to the marketing user).
///      • Otherwise atomically decrement each product's stock, set
///        orderStatus = "Confirm Order", generate the invoice document + PDF
///        NOW (move the invoice block out of placeOrder), link it on the
///        order, and reply
///        200 { "success": true, "message": "order confirmed",
///              "order": { …updated order, "invoice": {
///                 "invoiceNumber": "INV-…", "pdfUrl": "https://…" } } }
///
/// 2) CANCEL + STOCK RESTORE — PUT /vsArogya/cancel-order/:id
///      • Must also accept STAFF (marketing/admin) tokens, not only the
///        order's owner, so marketing can cancel before delivery.
///      • If the order had been accepted (stock deducted), add each line's
///        quantity back to product.stock. Never below the Delivered guard:
///        Delivered orders stay non-cancellable (already enforced).
///      • Reply 200 { "success": true, "message": "order cancel successfully" }.
///
/// 3) MANUAL ORDER BY MARKETING — POST /vsArogya/manual-order  (NEW route)
///    Auth: isAuthenticated (marketing/admin token). Request:
///      { "vendorId": "`<Vendor _id>`",
///        "items": [ { "productId": "`<product _id>`", "quantity": 2 }, … ],
///        "source": "MANUAL_BY_MARKETING",
///        "clientOrderId": "MO-1720340000000-4821" }
///    Server behaviour:
///      • createdBy = req.id (the authenticated marketing user) — audit trail.
///      • order.user = vendorId, shippingAddress from the vendor's registered
///        profile (full_address / city / state / pincode / mobile_no), prices
///        snapshotted from each product like placeOrder does.
///      • `clientOrderId` is an IDEMPOTENCY key: if an order with the same
///        clientOrderId already exists, return it (200) instead of creating a
///        duplicate — the app retries safely after a mid-submit network drop.
///      • Order starts as "Pending" and flows through the SAME lifecycle as a
///        vendor-placed order (no invoice / stock change until accept).
///      • Reply 201 { "success": true, "Order": { …order document… } }.
///    Until the route exists the app shows the server's error and offers a
///    retry — nothing is created client-side.
///
/// 4) INVOICE FETCH (staff) — GET /vsArogya/prev-invoice/:id
///    Already exists: 302 → hosted PDF. Requires only isAuthenticated, so the
///    logged-in marketing/admin token works. 404 "Invoice not found" until the
///    invoice has been generated.
/// ═══════════════════════════════════════════════════════════════════════════
class MarketingOrdersApi {
  MarketingOrdersApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);

  /// Manual-order creation can hit a cold-started free-tier server — wait
  /// longer so a slow start isn't mistaken for a failure.
  static const Duration _slowTimeout = Duration(seconds: 60);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Auth headers for the endpoints that need the logged-in staff session
  /// (manual order, invoice fetch, cancel). Mirrors CustomerApi.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  Future<List<MarketingOrder>?> getOrders() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-orders'))
          .timeout(_timeout);
      if (!MarketingApi._isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['allOrders'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(_fromBackend)
          // Skip empty (₹0 / 0-item) orders — these are unfulfillable garbage
          // from before the cart-sync fix and shouldn't clutter the pipeline.
          .where((o) => o.items.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// The real delivery-partner directory (users with role == "delivery"),
  /// read from GET /vsArogya/all-vendors and filtered by role. Returns null on
  /// failure so the picker can show a retry; never returns dummy data.
  Future<List<DeliveryAgent>?> getDeliveryAgents() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-vendors'))
          .timeout(_timeout);
      if (!MarketingApi._isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['all_vendors'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .where((j) => (j['role'] ?? '').toString().toLowerCase() == 'delivery')
          .map(DeliveryAgent.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Each status transition returns null on success or a USER-FACING error
  /// message (the server's own `message` when it explains the rejection —
  /// e.g. "Insufficient stock for Paracetamol 500: available 4, ordered 10").
  /// Accept — the server renders the invoice (Puppeteer) inline before
  /// replying, so this call gets the longer timeout to survive a cold start.
  Future<String?> confirmOrder(String id) =>
      _put('/vsArogya/confirm-order/$id', timeout: _slowTimeout);
  Future<String?> shipOrder(String id) => _put('/vsArogya/shipped-order/$id');
  Future<String?> outForDeliveryOrder(String id) =>
      _put('/vsArogya/outof-delivery/$id');
  Future<String?> deliverOrder(String id) =>
      _put('/vsArogya/delivered-prder/$id');

  /// Cancels an order as STAFF (marketing/admin) — PUT /cancel-order/:id with
  /// the staff auth token (see contract #2 above: the backend must honour
  /// staff tokens and restore any deducted stock). Null on success, else a
  /// user-facing error message.
  Future<String?> cancelOrder(String id) =>
      _put('/vsArogya/cancel-order/$id');

  /// Shared PUT: null = success, else the server's message / a generic error.
  /// [timeout] overrides the default for slow endpoints (e.g. accept, which
  /// renders the invoice PDF inline on the server).
  Future<String?> _put(String path, {Duration? timeout}) async {
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(timeout ?? _timeout);
      if (MarketingApi._isOk(res)) return null;
      return _serverMessage(res) ?? 'Update failed — try again';
    } catch (_) {
      return 'Network error — check your connection and try again';
    }
  }

  // ---------------------------------------------------------------------------
  // VENDOR DIRECTORY (manual-order "on behalf of" picker)
  // ---------------------------------------------------------------------------

  /// Registered buyer/vendor accounts (GET /all-vendors with the staff roles
  /// filtered out). Returns null on failure so the picker can offer a retry —
  /// never dummy data.
  Future<List<VendorAccount>?> getVendors() async {
    const staffRoles = {'admin', 'delivery', 'marketing', 'outlet', 'agent'};
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-vendors'))
          .timeout(_timeout);
      if (!MarketingApi._isOk(res)) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['all_vendors'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .where((j) =>
              !staffRoles.contains((j['role'] ?? '').toString().toLowerCase()))
          .map(VendorAccount.fromJson)
          .where((v) => v.approved)
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // MANUAL ORDER (created by marketing on a vendor's behalf) — contract #3
  // ---------------------------------------------------------------------------

  /// Creates an order on [vendorId]'s behalf. [items] maps productId ->
  /// quantity. [clientOrderId] is the idempotency key — the caller keeps it
  /// stable across retries so a mid-submit network drop can't duplicate the
  /// order once the backend honours it.
  ///
  /// Returns `(orderId, error)`: orderId set on success; error set with a
  /// user-facing message when the server rejected the call or was unreachable.
  /// [batches] optionally pins the lots each product must be drawn from, keyed
  /// by product id — the batches the user chose in the FEFO picker. They ride on
  /// the cart line and are re-validated by the server when the order is placed;
  /// a product with no entry is allocated pure FEFO.
  Future<(String?, String?)> createManualOrder({
    required String vendorId,
    required Map<String, int> items,
    required String clientOrderId,
    Map<String, List<BatchAllocation>> batches = const {},
  }) async {
    try {
      // 1) Build the selected vendor's cart — the server adds ONE unit per
      //    manual-cart call, so each quantity is sent as that many calls. They
      //    run in series on purpose: every call re-reads and saves the same
      //    vendor document, so firing them in parallel would race and drop
      //    increments.
      for (final entry in items.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        for (var i = 0; i < quantity; i++) {
          final cartUrl =
              '$baseUrl/vsArogya/manual-cart/$vendorId/$productId';
          // The pinned batches describe the WHOLE line, so they are sent once
          // with the LAST unit — by then the line's quantity is final and the
          // server stores the allocation against it (a later call replaces it,
          // never appends).
          final isLastUnit = i == quantity - 1;
          final pinned = batches[productId] ?? const <BatchAllocation>[];
          final res = await _client
              .post(
                Uri.parse(cartUrl),
                headers: _headers,
                body: (isLastUnit && pinned.isNotEmpty)
                    ? jsonEncode({
                        'allocations':
                            pinned.map((a) => a.toJson()).toList(),
                      })
                    : null,
              )
              .timeout(_timeout);
          if (!MarketingApi._isOk(res)) {
            return (
              null,
              _serverMessage(res) ??
                  'Could not add a product to the order '
                      '(HTTP ${res.statusCode}). Please try again.',
            );
          }
        }
      }

      // 2) Place the order from that cart — the server generates the invoice.
      final orderUrl = '$baseUrl/vsArogya/manual-order/$vendorId';
      debugPrint(
          '[ManualOrder] POST $orderUrl vendor=$vendorId lines=${items.length}');
      final res = await _client
          .post(Uri.parse(orderUrl), headers: _headers)
          .timeout(_slowTimeout);
      debugPrint(
          '[ManualOrder] status=${res.statusCode} body=${res.body.length > 300 ? '${res.body.substring(0, 300)}…' : res.body}');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final order = body['Order'] ?? body['order'];
        if (order is Map && order['_id'] != null) {
          return (order['_id'].toString(), null);
        }
        // The invoice-success path echoes the invoice (which refs the order).
        final inv = body['createdInvoice'];
        if (inv is Map && inv['order'] != null) {
          return (inv['order'].toString(), null);
        }
        // 2xx + success but no id echoed — still a success for the caller.
        if (body['success'] == true) return ('', null);
      }
      return (
        null,
        _serverMessage(res) ??
            'The server could not place this order (HTTP ${res.statusCode}). '
                'Please try again.',
      );
    } catch (e) {
      debugPrint('[ManualOrder] failed: $e');
      return (
        null,
        'Could not reach the server. Check your connection and retry.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // INVOICE (staff view) — GET /prev-invoice/:id → 302 → hosted PDF
  // ---------------------------------------------------------------------------

  /// Fetches the server-generated invoice PDF for [orderId]. Returns
  /// `(bytes, error)` — bytes on success, else a user-facing reason (e.g.
  /// "Invoice not found" while the PDF is still being generated).
  Future<(Uint8List?, String?)> fetchInvoicePdf(String orderId) async {
    final url = '$baseUrl/vsArogya/prev-invoice/$orderId';
    try {
      debugPrint('[StaffInvoice] GET $url');
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && InvoicePdf.looksLikePdf(res.bodyBytes)) {
        return (res.bodyBytes, null);
      }
      return (
        null,
        _serverMessage(res) ?? 'Server returned HTTP ${res.statusCode}.',
      );
    } catch (e) {
      debugPrint('[StaffInvoice] failed: $e');
      return (null, 'Could not reach the invoice server. Check your connection.');
    }
  }

  /// The server's own `message` field, when the body is JSON — so rejection
  /// reasons (insufficient stock, unauthorized, …) reach the user verbatim.
  static String? _serverMessage(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['message'] != null) return b['message'].toString();
    } catch (_) {
      // non-JSON body
    }
    return null;
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
      paymentTerm: (j['paymentMethod'] ?? '').toString(),
      // Audit flag for manually-created orders (see the manual-order
      // contract). Absent on vendor-placed orders.
      source: (j['source'] ?? '').toString(),
    );
  }

  static MarketingOrderStatus _statusFromBackend(String s) => switch (s) {
        'Confirm Order' => MarketingOrderStatus.confirmed,
        'Shipped' => MarketingOrderStatus.shipped,
        'Out for Delivery' => MarketingOrderStatus.outForDelivery,
        'Delivered' => MarketingOrderStatus.delivered,
        'Cancelled' => MarketingOrderStatus.cancelled,
        _ => MarketingOrderStatus.pending,
      };

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

// =============================================================================
// OUTLETS (Marketing → Register Outlet screen)
//
// A physical outlet the company runs. The marketing head registers one from the
// app; the outlet then logs in with the mobile number + the password set here.
//
//   POST /vsArogya/outlet-register
//   GET  /vsArogya/outlet-products/:id   (that outlet's assigned stock)
//
// Outlets live in their OWN collection (model/outletregistersModel.js), not in
// Vendor — so they are not part of the vendor directory or the approval flow.
// =============================================================================

class OutletApi {
  OutletApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// A cold-started free-tier server can take a while to answer the first call.
  static const Duration _timeout = Duration(seconds: 45);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Same staff-session headers the other marketing endpoints send.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  /// The outlet directory — every outlet, or only those in [pincode].
  ///
  /// Returns null on failure so the caller can offer a retry; an empty list
  /// means "no outlets in that pincode", which is not an error.
  Future<List<MarketingOutlet>?> getOutlets({String? pincode}) async {
    final query = (pincode == null || pincode.isEmpty) ? '' : '?pincode=$pincode';
    final url = '$baseUrl/vsArogya/outlets$query';
    try {
      debugPrint('[Outlet] GET $url');
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (!MarketingApi._isOk(res)) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['outlets'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MarketingOutlet.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[Outlet] getOutlets failed: $e');
      return null;
    }
  }

  /// Moves [quantity] of [productId] out of the global catalog and into
  /// [outletId]'s stock (POST /outlet-stock).
  ///
  /// The server takes ONE product per call and ADDS to whatever the outlet
  /// already holds (`quantity += n`), deducting the same amount from
  /// `product.stock`. It rejects the call when the catalog doesn't have enough.
  ///
  /// [allocations] are the batches the head explicitly chose to send. The server
  /// re-validates them against live availability and consumes exactly those
  /// lots, recording the same batch identity on the outlet's own stock — so the
  /// outlet knows precisely which lots it received. Passing an empty list falls
  /// back to pure FEFO.
  ///
  /// Returns null on success, or a user-facing error message.
  Future<String?> assignStock({
    required String outletId,
    required String productId,
    required int quantity,
    List<BatchAllocation> allocations = const [],
  }) async {
    final url = '$baseUrl/vsArogya/outlet-stock';
    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              'outletId': outletId,
              'productId': productId,
              'quantity': quantity,
              if (allocations.isNotEmpty)
                'allocations': allocations.map((a) => a.toJson()).toList(),
            }),
          )
          .timeout(_timeout);

      if (MarketingApi._isOk(res)) return null;
      // The server explains its own rejections ("Insufficient stock available",
      // "Product not found") — show those verbatim.
      return MarketingOrdersApi._serverMessage(res) ??
          'Could not update stock (HTTP ${res.statusCode})';
    } on TimeoutException {
      return 'Server is taking too long to respond';
    } catch (e) {
      debugPrint('[Outlet] assignStock failed: $e');
      return 'Could not reach the server';
    }
  }

  /// Registers an outlet. Every field the server requires is non-optional here
  /// — the backend rejects the whole call with "Missing fields" if any one of
  /// them is blank, so the form validates them all before we get this far.
  ///
  /// Returns null on success, or a user-facing error message.
  Future<String?> registerOutlet({
    required String outletName,
    required String ownerName,
    required String mobileNo,
    required String email,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String gstNumber,
    required String password,
  }) async {
    final url = '$baseUrl/vsArogya/outlet-register';
    try {
      debugPrint('[Outlet] POST $url name=$outletName');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              'outletName': outletName,
              'ownerName': ownerName,
              'mobileNo': mobileNo,
              'email': email,
              'address': address,
              'city': city,
              'state': state,
              'pincode': pincode,
              'gstNumber': gstNumber,
              'password': password,
            }),
          )
          .timeout(_timeout);

      debugPrint('[Outlet] status=${res.statusCode} body=${res.body}');
      if (MarketingApi._isOk(res)) return null;

      return MarketingOrdersApi._serverMessage(res) ??
          'Could not register the outlet (HTTP ${res.statusCode}). '
              'Please try again.';
    } on TimeoutException {
      return 'Server is taking too long to respond — please try again.';
    } catch (e) {
      debugPrint('[Outlet] failed: $e');
      return 'Could not reach the server. Check your connection and try again.';
    }
  }
}

// =============================================================================
// AREA AGENTS (Marketing → Register Agent screen)
//
// An Area Agent monitors every order delivering to one pincode. The marketing
// head creates one here; the agent then signs in with the mobile number + the
// password set on the form (the normal sign-in screen).
//
//   POST /vsArogya/agent-register  { name, mobileNo, email, pincode, password }
//
// Agents ARE Vendor documents (role "agent" + pin_code), created Approved so
// they can log in immediately — unlike outlets, which live in their own table.
// =============================================================================

class MarketingAgentApi {
  MarketingAgentApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// A cold-started free-tier server can take a while to answer the first call.
  static const Duration _timeout = Duration(seconds: 45);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Same staff-session headers the other marketing endpoints send.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  /// Registers an Area Agent. Returns null on success, or a user-facing error
  /// message (the server's own message when it explains the rejection, e.g.
  /// "A user with this mobile number already exists").
  Future<String?> registerAgent({
    required String name,
    required String mobileNo,
    required String email,
    required String pincode,
    required String password,
  }) async {
    final url = '$baseUrl/vsArogya/agent-register';
    try {
      debugPrint('[Agent] POST $url name=$name pin=$pincode');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'mobileNo': mobileNo,
              'email': email,
              'pincode': pincode,
              'password': password,
            }),
          )
          .timeout(_timeout);

      debugPrint('[Agent] status=${res.statusCode} body=${res.body}');
      if (MarketingApi._isOk(res)) return null;

      return MarketingOrdersApi._serverMessage(res) ??
          'Could not register the agent (HTTP ${res.statusCode}). '
              'Please try again.';
    } on TimeoutException {
      return 'Server is taking too long to respond — please try again.';
    } catch (e) {
      debugPrint('[Agent] registerAgent failed: $e');
      return 'Could not reach the server. Check your connection and try again.';
    }
  }
}

// =============================================================================
// EXCEL REPORTS (Marketing → Reports screen)
//
// The backend already builds the spreadsheets (controller/xlsheetController.js
// via routes/xlshRoute.js) — the app only downloads the ready-made file:
//   GET /vsArogya/order-report   → .xlsx of every order (vendor, amount,
//                                  status, date)
//   GET /vsArogya/vendor-report  → .xlsx of every registered vendor
//
// Both return the raw file bytes with an Excel Content-Type. No JSON parsing —
// the bytes are handed straight to the share sheet.
// =============================================================================

class MarketingReportsApi {
  MarketingReportsApi({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Generous timeout: a cold-started free-tier server plus a full-table
  /// export can take a while.
  static const Duration _timeout = Duration(seconds: 60);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Same staff-session headers the other marketing endpoints send.
  Map<String, String> get _headers => {
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  /// Downloads one of the server's Excel reports.
  ///
  /// [path] is the endpoint path, e.g. `/vsArogya/order-report`.
  /// Returns `(bytes, null)` on success, or `(null, user-facing error)`.
  Future<(Uint8List?, String?)> downloadExcel(String path) async {
    final url = '$baseUrl$path';
    try {
      debugPrint('[Reports] GET $url');
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (res.statusCode != 200) {
        return (
          null,
          MarketingOrdersApi._serverMessage(res) ??
              'Server returned HTTP ${res.statusCode} — please try again.',
        );
      }

      // Every .xlsx file is really a ZIP archive, and ZIP files always start
      // with the two bytes "PK". Anything else (an HTML/JSON error page) means
      // the server did not send a spreadsheet.
      final bytes = res.bodyBytes;
      if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        return (null, 'Server did not return an Excel file — please try again.');
      }
      return (bytes, null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[Reports] failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }
}
