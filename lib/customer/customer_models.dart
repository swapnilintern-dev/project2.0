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
  final String? imageUrl;
  final IconData icon;
  final double rating;
  final int reviewCount;
  final bool inStock;
  final int stockCount;
  final String? badge;
  final String packInfo;

  /// Percentage discount versus MRP (0 when there is no MRP).
  int get discountPercent {
    final m = mrp;
    if (m == null || m <= price) return 0;
    return (((m - price) / m) * 100).round();
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // Backend image is an array of { url, publicId }.
    String? image;
    final raw = json['image'];
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map && first['url'] is String) image = first['url'] as String;
    } else if (raw is String) {
      image = raw;
    }
    return Product(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      brand: (json['brand'] ?? json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _toDouble(json['price']),
      mrp: json['mrp'] == null ? null : _toDouble(json['mrp']),
      category: (json['category'] ?? 'General').toString(),
      imageUrl: image,
      rating: json['rating'] == null ? 4.5 : _toDouble(json['rating']),
      reviewCount: _toInt(json['reviewCount']),
      inStock: json['inStock'] is bool ? json['inStock'] as bool : true,
      stockCount: _toInt(json['stockCount']),
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
  });

  final String id;
  final String tag; // e.g. "BULK OFFER"
  final String title; // e.g. "Flat 20% OFF on orders above ₹5,000"
  final String ctaLabel;
  final Color startColor;
  final Color endColor;

  /// Optional deep-link target — when set, tapping opens this category.
  final String? categoryId;

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        tag: (json['tag'] ?? 'OFFER').toString(),
        title: (json['title'] ?? '').toString(),
        ctaLabel: (json['ctaLabel'] ?? 'Shop Now').toString(),
        startColor: _toColor(json['startColor']) ?? const Color(0xFF4CAF82),
        endColor: _toColor(json['endColor']) ?? const Color(0xFF2E7D5E),
        categoryId: json['categoryId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'title': title,
        'ctaLabel': ctaLabel,
        'startColor': '#${startColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'endColor': '#${endColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'categoryId': categoryId,
      };
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

/// Lifecycle of an order, in display order.
enum OrderStatus { placed, confirmed, packed, outForDelivery, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.placed => 'Order Placed',
        OrderStatus.confirmed => 'Order Confirmed',
        OrderStatus.packed => 'Packed',
        OrderStatus.outForDelivery => 'Out for Delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

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

/// Parses a hex colour string ("#4CAF82", "4CAF82" or "0xFF4CAF82").
Color? _toColor(Object? v) {
  if (v is! String || v.isEmpty) return null;
  var hex = v.replaceAll('#', '').replaceAll('0x', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(value);
}
