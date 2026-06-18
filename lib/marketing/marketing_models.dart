// =============================================================================
// MediCaPlus — Marketing Head Models
//
// Plain Dart models (no codegen) for the Marketing Head role: incoming orders
// (with the purchased line items), the medicine inventory and coupons. These
// are intentionally separate from the customer models because the marketing
// workflow is fulfilment / inventory shaped.
//
// Colours reuse the shared `AppColors`; `MarketingColors` adds a couple of
// status-only accents (orange for low/pending, blue for ready).
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;

/// Status-only accent colours not present in the shared palette.
class MarketingColors {
  MarketingColors._();
  static const Color orange = Color(0xFFF59E0B); // pending / low stock
  static const Color blue = Color(0xFF3B82F6); // ready to ship
}

/// The medicine categories used by both the inventory filter chips and the
/// Add / Edit Medicine category dropdown.
const List<String> kMedicineCategories = [
  'Lifesaving Injections',
  'Vaccines',
  'Medicine',
];

/// Formats a [DateTime] as a short "time ago" string (5 min ago / 1h ago …).
String formatTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// =============================================================================
// ORDERS
// =============================================================================

/// The fulfilment pipeline for an incoming order, in display order. The tab
/// labels in the UI are: New, Packing, Ready, Shipped, Done.
enum MarketingOrderStatus { pending, packing, ready, shipped, done }

extension MarketingOrderStatusX on MarketingOrderStatus {
  String get label => switch (this) {
        MarketingOrderStatus.pending => 'New',
        MarketingOrderStatus.packing => 'Packing',
        MarketingOrderStatus.ready => 'Ready',
        MarketingOrderStatus.shipped => 'Shipped',
        MarketingOrderStatus.done => 'Done',
      };

  Color get color => switch (this) {
        MarketingOrderStatus.pending => AppColors.primary,
        MarketingOrderStatus.packing => MarketingColors.orange,
        MarketingOrderStatus.ready => MarketingColors.blue,
        MarketingOrderStatus.shipped => AppColors.darkGreen,
        MarketingOrderStatus.done => AppColors.greyText,
      };

  /// The contextual action that advances the order, or null when it is Done.
  String? get actionLabel => switch (this) {
        MarketingOrderStatus.pending => 'Accept',
        MarketingOrderStatus.packing => 'Pack',
        MarketingOrderStatus.ready => 'Ship',
        MarketingOrderStatus.shipped => 'Mark Done',
        MarketingOrderStatus.done => null,
      };

  /// The status this order moves to when the action button is tapped.
  MarketingOrderStatus? get next => switch (this) {
        MarketingOrderStatus.pending => MarketingOrderStatus.packing,
        MarketingOrderStatus.packing => MarketingOrderStatus.ready,
        MarketingOrderStatus.ready => MarketingOrderStatus.shipped,
        MarketingOrderStatus.shipped => MarketingOrderStatus.done,
        MarketingOrderStatus.done => null,
      };
}

/// A single purchased line within an order.
@immutable
class MarketingOrderLine {
  const MarketingOrderLine({
    required this.name,
    required this.brand,
    required this.quantity,
    required this.price,
    this.icon = Icons.medication_outlined,
  });

  final String name;
  final String brand;
  final int quantity;
  final double price;
  final IconData icon;

  double get lineTotal => price * quantity;
}

/// An incoming wholesale order from a pharmacy / distributor.
@immutable
class MarketingOrder {
  const MarketingOrder({
    required this.id,
    required this.buyer,
    required this.placedAt,
    required this.amount,
    required this.status,
    this.items = const [],
    this.phone = '',
    this.address = '',
    this.paymentTerm = 'Credit · Net 30',
    this.urgent = false,
    this.isNew = false,
  });

  final String id; // e.g. MCP-48210
  final String buyer; // e.g. Apollo Pharmacy
  final DateTime placedAt;
  final double amount; // grand total
  final MarketingOrderStatus status;
  final List<MarketingOrderLine> items;
  final String phone;
  final String address;
  final String paymentTerm;
  final bool urgent;
  final bool isNew;

  int get itemCount => items.length;
  int get unitCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  /// Taxes / fees implied by the difference between the line subtotal and the
  /// quoted grand total (kept non-negative for display).
  double get taxesAndFees {
    final diff = amount - subtotal;
    return diff > 0 ? diff : 0;
  }

  /// Two-letter avatar initials derived from the buyer name (Apollo Pharmacy -> AP).
  String get initials {
    final parts =
        buyer.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get timeAgo => formatTimeAgo(placedAt);

  MarketingOrder copyWith({MarketingOrderStatus? status}) => MarketingOrder(
        id: id,
        buyer: buyer,
        placedAt: placedAt,
        amount: amount,
        status: status ?? this.status,
        items: items,
        phone: phone,
        address: address,
        paymentTerm: paymentTerm,
        urgent: urgent,
        isNew: isNew,
      );
}

// =============================================================================
// MEDICINE INVENTORY
// =============================================================================

/// Derived stock level used for the per-row badge and the catalogue stats.
enum StockStatus { inStock, low, out }

extension StockStatusX on StockStatus {
  String get label => switch (this) {
        StockStatus.inStock => 'In Stock',
        StockStatus.low => 'Low Stock',
        StockStatus.out => 'Out of Stock',
      };

  Color get color => switch (this) {
        StockStatus.inStock => AppColors.primary,
        StockStatus.low => MarketingColors.orange,
        StockStatus.out => AppColors.error,
      };
}

/// A medicine the marketing head manages (full inventory record).
@immutable
class InventoryProduct {
  const InventoryProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.active,
    this.brand = '',
    this.code = '',
    this.manufacturer = '',
    this.marketedBy = '',
    this.description = '',
    this.mrp,
    this.category = 'Medicine',
    this.packOf = 1,
    this.hsnCode = '',
    this.gstPercent = 5,
    this.discountPercent = 0,
    this.lowThreshold = 10,
    this.prescriptionRequired = false,
    this.inactiveReason,
    this.icon = Icons.medication_liquid_outlined,
  });

  final String id;
  final String name;
  final String brand;
  final String code; // product / SKU code
  final String manufacturer;
  final String marketedBy;
  final String description;
  final double price; // selling price
  final double? mrp;
  final int stock;
  final bool active; // visible to customers
  final String category;
  final int packOf;
  final String hsnCode;
  final double gstPercent;
  final double discountPercent;
  final int lowThreshold;
  final bool prescriptionRequired;
  final String? inactiveReason;
  final IconData icon;

  StockStatus get stockStatus {
    if (stock <= 0) return StockStatus.out;
    if (stock <= lowThreshold) return StockStatus.low;
    return StockStatus.inStock;
  }

  InventoryProduct copyWith({
    String? name,
    String? brand,
    String? code,
    String? manufacturer,
    String? marketedBy,
    String? description,
    double? price,
    double? mrp,
    int? stock,
    bool? active,
    String? category,
    int? packOf,
    String? hsnCode,
    double? gstPercent,
    double? discountPercent,
    int? lowThreshold,
    bool? prescriptionRequired,
    String? inactiveReason,
    bool clearInactiveReason = false,
    IconData? icon,
  }) {
    return InventoryProduct(
      id: id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      code: code ?? this.code,
      manufacturer: manufacturer ?? this.manufacturer,
      marketedBy: marketedBy ?? this.marketedBy,
      description: description ?? this.description,
      price: price ?? this.price,
      mrp: mrp ?? this.mrp,
      stock: stock ?? this.stock,
      active: active ?? this.active,
      category: category ?? this.category,
      packOf: packOf ?? this.packOf,
      hsnCode: hsnCode ?? this.hsnCode,
      gstPercent: gstPercent ?? this.gstPercent,
      discountPercent: discountPercent ?? this.discountPercent,
      lowThreshold: lowThreshold ?? this.lowThreshold,
      prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
      inactiveReason:
          clearInactiveReason ? null : (inactiveReason ?? this.inactiveReason),
      icon: icon ?? this.icon,
    );
  }
}

// =============================================================================
// COUPONS
// =============================================================================

/// A promo coupon the marketing head can toggle on/off. Expired coupons are
/// shown greyed-out and cannot be re-enabled from the list.
@immutable
class MarketingCoupon {
  const MarketingCoupon({
    required this.code,
    required this.description,
    required this.redemptions,
    this.active = true,
    this.expired = false,
  });

  final String code;
  final String description;
  final int redemptions;
  final bool active;
  final bool expired;

  MarketingCoupon copyWith({bool? active}) => MarketingCoupon(
        code: code,
        description: description,
        redemptions: redemptions,
        active: active ?? this.active,
        expired: expired,
      );
}
