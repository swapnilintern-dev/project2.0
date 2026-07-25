// =============================================================================
// MediCaPlus — Customer Models
//
// Plain Dart models (no codegen) for the customer shopping experience.
// Each model exposes fromJson() / toJson() / copyWith() so the repository
// layer can later map straight onto the Express + MongoDB backend
// (server/model/productModel.js -> { title, description, price, category,
// image:[{url, publicId}] }). UI-only fields (rating, badge, mrp ...) default
// to sensible values when the backend doesn't send them.
// =============================================================================

import 'package:flutter/material.dart';

import '../services/product_media.dart';

/// A purchasable medicine / healthcare product.
@immutable
class Product {
  const Product({
    required this.id,
    required this.title,
    required this.brand,
    required this.description,
    required this.price,
    this.mrp,
    required this.category,
    this.imageUrl,
    this.imageUrls = const [],
    this.videoUrl,
    this.icon = Icons.medication_outlined,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.inStock = true,
    this.stockCount = 0,
    this.badge,
    this.packInfo = '',
  });

  final String id;
  final String title;
  final String brand;
  final String description;
  final double price;
  final double? mrp;
  final String category;

  /// The primary image URL (first image), or null. Kept for the many call-sites
  /// that show a single thumbnail.
  final String? imageUrl;

  /// Every product image URL, in display order (drives the details carousel).
  final List<String> imageUrls;

  /// The promotional video URL, or null when the product has none.
  final String? videoUrl;

  final IconData icon;
  final double rating;
  final int reviewCount;
  final bool inStock;
  final int stockCount;
  final String? badge;
  final String packInfo;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  /// Percentage discount versus MRP (0 when there is no MRP).
  int get discountPercent {
    final m = mrp;
    if (m == null || m <= price) return 0;
    return (((m - price) / m) * 100).round();
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // Backend `image` is an ordered array of { url, publicId }; `video` is an
    // optional { url, publicId }. Tolerates a bare string / list of strings and
    // a cached `imageUrls` list (from toJson round-trips) — prefer the full
    // cached list over the scalar `image` so nothing is dropped.
    final cachedList = json['imageUrls'];
    final rawImages = (cachedList is List && cachedList.isNotEmpty)
        ? cachedList
        : json['image'];
    final images = ProductMedia.parseImages(rawImages);
    final imageUrls = images.map((m) => m.url).toList();
    final video = ProductMedia.parseVideo(json['video'] ?? json['videoUrl']);
    return Product(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      brand: (json['brand'] ?? json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _toDouble(json['price']),
      mrp: json['mrp'] == null ? null : _toDouble(json['mrp']),
      category: _normalizeCategory(json['category']),
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      imageUrls: imageUrls,
      videoUrl: video?.url,
      rating: json['rating'] == null ? 4.5 : _toDouble(json['rating']),
      reviewCount: _toInt(json['reviewCount']),
      // Backend sends `stock` (number). Derive availability from it so the
      // server-side decrement (oversell fix) is reflected in the shop.
      inStock: json['inStock'] is bool
          ? json['inStock'] as bool
          : (json['stock'] == null ? true : _toInt(json['stock']) > 0),
      stockCount: json['stockCount'] != null
          ? _toInt(json['stockCount'])
          : _toInt(json['stock']),
      badge: json['badge'] as String?,
      packInfo: (json['packInfo'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'brand': brand,
        'description': description,
        'price': price,
        'mrp': mrp,
        'category': category,
        'image': imageUrl,
        'imageUrls': imageUrls,
        'videoUrl': videoUrl,
        'rating': rating,
        'reviewCount': reviewCount,
        'inStock': inStock,
        'stockCount': stockCount,
        'badge': badge,
        'packInfo': packInfo,
      };

  Product copyWith({
    String? id,
    String? title,
    String? brand,
    String? description,
    double? price,
    double? mrp,
    String? category,
    String? imageUrl,
    List<String>? imageUrls,
    String? videoUrl,
    IconData? icon,
    double? rating,
    int? reviewCount,
    bool? inStock,
    int? stockCount,
    String? badge,
    String? packInfo,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      price: price ?? this.price,
      mrp: mrp ?? this.mrp,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      icon: icon ?? this.icon,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      inStock: inStock ?? this.inStock,
      stockCount: stockCount ?? this.stockCount,
      badge: badge ?? this.badge,
      packInfo: packInfo ?? this.packInfo,
    );
  }
}

/// A promotional banner shown in the home carousel. Designed to be populated
/// by the marketing team via the backend (title, subtitle, CTA + two gradient
/// colours) so new offers appear in the app without a release.
@immutable
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.tag,
    required this.title,
    this.ctaLabel = 'Shop Now',
    this.startColor = const Color(0xFF4CAF82),
    this.endColor = const Color(0xFF2E7D5E),
    this.categoryId,
    this.imageUrl,
  });

  final String id;
  final String tag; // e.g. "BULK OFFER" (fallback text for image-less banners)
  final String title; // e.g. "Flat 20% OFF on orders above ₹5,000" (fallback)
  final String ctaLabel;
  final Color startColor;
  final Color endColor;

  /// Optional deep-link target — when set, tapping opens this category.
  final String? categoryId;

  /// Uploaded creative URL (Cloudinary). When present the app renders the image
  /// edge-to-edge; otherwise it falls back to the gradient + text banner.
  final String? imageUrl;

  /// True when this banner is backed by an uploaded image creative.
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        tag: (json['tag'] ?? 'OFFER').toString(),
        title: (json['title'] ?? '').toString(),
        ctaLabel: (json['ctaLabel'] ?? 'Shop Now').toString(),
        startColor: _toColor(json['startColor']) ?? const Color(0xFF4CAF82),
        endColor: _toColor(json['endColor']) ?? const Color(0xFF2E7D5E),
        categoryId: json['categoryId'] as String?,
        imageUrl: _bannerImageUrl(json['image']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'title': title,
        'ctaLabel': ctaLabel,
        'startColor': '#${startColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'endColor': '#${endColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'categoryId': categoryId,
        'imageUrl': imageUrl,
      };
}

/// Extracts a banner image URL from the backend's `image` field, which is a
/// `{ url, publicId }` object (tolerates a plain string too).
String? _bannerImageUrl(Object? raw) {
  if (raw is Map && raw['url'] is String) {
    final url = raw['url'] as String;
    return url.isEmpty ? null : url;
  }
  if (raw is String && raw.isNotEmpty) return raw;
  return null;
}

/// A product category chip on the home / listing screens.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

/// The app's canonical category taxonomy. Backend products carry a free-form
/// `category` string which [_normalizeCategory] maps onto these three ids, so
/// the chips here always line up with what the server sends.
const List<Category> kCategories = [
  Category(
      id: 'injections',
      name: 'Lifesaving Injections',
      icon: Icons.vaccines,
      color: Color(0xFF3B82F6)),
  Category(
      id: 'vaccines',
      name: 'Vaccines',
      icon: Icons.health_and_safety,
      color: Color(0xFF4CAF82)),
  Category(
      id: 'medicine',
      name: 'Medicine',
      icon: Icons.medication,
      color: Color(0xFF8B5CF6)),
];

/// One line in the cart: a [Product] plus a quantity.
@immutable
class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartItem copyWith({Product? product, int? quantity}) => CartItem(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'productId': product.id,
        'quantity': quantity,
      };
}

/// A saved delivery address.
@immutable
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
  });

  final String id;
  final String label; // Home / Work / Other
  final String fullName;
  final String phone;
  final String line1;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  String get formatted => '$line1, $city, $state - $pincode';

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        label: (json['label'] ?? 'Home').toString(),
        fullName: (json['fullName'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        line1: (json['line1'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        pincode: (json['pincode'] ?? '').toString(),
        isDefault: json['isDefault'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fullName': fullName,
        'phone': phone,
        'line1': line1,
        'city': city,
        'state': state,
        'pincode': pincode,
        'isDefault': isDefault,
      };

  Address copyWith({
    String? id,
    String? label,
    String? fullName,
    String? phone,
    String? line1,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Supported checkout payment methods.
enum PaymentMethod { razorpay, cod }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.razorpay => 'Razorpay',
        PaymentMethod.cod => 'Cash on Delivery',
      };

  String get subtitle => switch (this) {
        PaymentMethod.razorpay => 'UPI, Cards, Net Banking & Wallets',
        PaymentMethod.cod => 'Pay when delivered',
      };

  IconData get icon => switch (this) {
        PaymentMethod.razorpay => Icons.account_balance_wallet_outlined,
        PaymentMethod.cod => Icons.payments_outlined,
      };
}

/// Lifecycle of an order, in display order. Mirrors the backend order status
/// enum: Pending, Confirm Order, Shipped, Out for Delivery, Delivered,
/// Cancelled.
enum OrderStatus { placed, confirmed, shipped, outForDelivery, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.placed => 'Order Placed',
        OrderStatus.confirmed => 'Order Confirmed',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.outForDelivery => 'Out for Delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// Status-pill text. A just-placed order is awaiting the marketing team's
  /// review, so the pill reads "Pending Approval" (the timeline keeps "Order
  /// Placed" as its first completed step).
  String get pillLabel =>
      this == OrderStatus.placed ? 'Pending Approval' : label;

  Color get color => switch (this) {
        OrderStatus.delivered => const Color(0xFF2E7D5E),
        OrderStatus.cancelled => const Color(0xFFE53935),
        OrderStatus.outForDelivery => const Color(0xFFF59E0B),
        _ => const Color(0xFF4CAF82),
      };

  bool get isActive =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;
}

/// A single line within a placed order (snapshot of price at purchase time).
@immutable
class OrderItem {
  const OrderItem({
    required this.title,
    required this.brand,
    required this.price,
    required this.quantity,
    this.icon = Icons.medication_outlined,
  });

  final String title;
  final String brand;
  final double price;
  final int quantity;
  final IconData icon;

  double get lineTotal => price * quantity;

  factory OrderItem.fromCartItem(CartItem item) => OrderItem(
        title: item.product.title,
        brand: item.product.brand,
        price: item.product.price,
        quantity: item.quantity,
        icon: item.product.icon,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'brand': brand,
        'price': price,
        'quantity': quantity,
      };
}

/// A placed order with its full invoice + timeline information.
@immutable
class Order {
  const Order({
    required this.id,
    required this.placedAt,
    required this.status,
    required this.items,
    required this.address,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.gst,
    required this.discount,
    this.invoiceUrl,
    this.invoiceNumber,
  });

  final String id;
  final DateTime placedAt;
  final OrderStatus status;
  final List<OrderItem> items;
  final Address address;
  final PaymentMethod paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double gst;
  final double discount;

  /// Server-hosted invoice PDF (Cloudinary URL from the backend), when the
  /// backend generated one. Null → the app builds the invoice on-device.
  final String? invoiceUrl;

  /// The REAL invoice number issued by the backend (e.g. "INV-1720340…"),
  /// available once the backend populates the order's `invoice` document.
  /// Null → the UI falls back to a derived reference.
  final String? invoiceNumber;

  /// BUSINESS RULE: the invoice exists only after the marketing team ACCEPTS
  /// the order. While the order is still Pending (placed) — or was cancelled —
  /// no invoice is shown anywhere: no button, no section, no invoice number.
  bool get invoiceAvailable => switch (status) {
        OrderStatus.confirmed ||
        OrderStatus.shipped ||
        OrderStatus.outForDelivery ||
        OrderStatus.delivered =>
          true,
        _ => false,
      };

  double get total => subtotal + deliveryFee + gst - discount;

  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  String get summaryLine {
    if (items.isEmpty) return 'No items';
    final first = items.first.title;
    if (items.length == 1) return first;
    return '$first +${items.length - 1} more';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'placedAt': placedAt.toIso8601String(),
        'status': status.name,
        'items': items.map((i) => i.toJson()).toList(),
        'address': address.toJson(),
        'paymentMethod': paymentMethod.name,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'gst': gst,
        'discount': discount,
      };

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        placedAt: placedAt,
        status: status ?? this.status,
        items: items,
        address: address,
        paymentMethod: paymentMethod,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        gst: gst,
        discount: discount,
        invoiceUrl: invoiceUrl,
        invoiceNumber: invoiceNumber,
      );
}

/// A discount coupon that can be applied at checkout.
@immutable
class Coupon {
  const Coupon({
    required this.code,
    required this.description,
    required this.percentOff,
    this.maxDiscount,
  });

  final String code;
  final String description;
  final double percentOff;
  final double? maxDiscount;

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        code: (j['code'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        percentOff: _toDouble(j['percentOff']),
        maxDiscount: j['maxDiscount'] == null ? null : _toDouble(j['maxDiscount']),
      );

  /// Computes the rupee discount for a given [subtotal].
  double discountFor(double subtotal) {
    var value = subtotal * percentOff / 100;
    final cap = maxDiscount;
    if (cap != null && value > cap) value = cap;
    return double.parse(value.toStringAsFixed(2));
  }
}

// --- small parse helpers (tolerant of String/num backend values) -------------

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _toInt(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Normalises a category (a human label like "Medicine" or an id like
/// "medicine") to the canonical id the category filter chips use
/// ('injections' / 'vaccines' / 'medicine').
String _normalizeCategory(Object? v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  if (s.contains('inject')) return 'injections';
  if (s.contains('vaccin')) return 'vaccines';
  if (s.contains('medic')) return 'medicine';
  return s.isEmpty ? 'medicine' : s;
}

/// Parses a hex colour string ("#4CAF82", "4CAF82" or "0xFF4CAF82").
Color? _toColor(Object? v) {
  if (v is! String || v.isEmpty) return null;
  var hex = v.replaceAll('#', '').replaceAll('0x', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(value);
}
