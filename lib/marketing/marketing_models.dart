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
import '../services/product_media.dart';
import '../shared/api_date.dart';

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
/// Mirrors the backend order status enum exactly:
/// ["Pending", "Confirm Order", "Shipped", "Out for Delivery", "Delivered",
/// "Cancelled"]. The marketing pipeline advances an order through these via the
/// matching backend status endpoints.
enum MarketingOrderStatus {
  pending,
  confirmed,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
}

extension MarketingOrderStatusX on MarketingOrderStatus {
  String get label => switch (this) {
        MarketingOrderStatus.pending => 'New',
        MarketingOrderStatus.confirmed => 'Confirmed',
        MarketingOrderStatus.shipped => 'Shipped',
        MarketingOrderStatus.outForDelivery => 'Out for Delivery',
        MarketingOrderStatus.delivered => 'Delivered',
        MarketingOrderStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        MarketingOrderStatus.pending => AppColors.primary,
        MarketingOrderStatus.confirmed => MarketingColors.orange,
        MarketingOrderStatus.shipped => MarketingColors.blue,
        MarketingOrderStatus.outForDelivery => MarketingColors.blue,
        MarketingOrderStatus.delivered => AppColors.darkGreen,
        MarketingOrderStatus.cancelled => AppColors.error,
      };

  /// The contextual action that advances the order, or null when finished.
  String? get actionLabel => switch (this) {
        MarketingOrderStatus.pending => 'Accept',
        MarketingOrderStatus.confirmed => 'Ship',
        MarketingOrderStatus.shipped => 'Out for Delivery',
        MarketingOrderStatus.outForDelivery => 'Mark Delivered',
        MarketingOrderStatus.delivered => null,
        MarketingOrderStatus.cancelled => null,
      };

  /// The status this order moves to when the action button is tapped.
  MarketingOrderStatus? get next => switch (this) {
        MarketingOrderStatus.pending => MarketingOrderStatus.confirmed,
        MarketingOrderStatus.confirmed => MarketingOrderStatus.shipped,
        MarketingOrderStatus.shipped => MarketingOrderStatus.outForDelivery,
        MarketingOrderStatus.outForDelivery => MarketingOrderStatus.delivered,
        MarketingOrderStatus.delivered => null,
        MarketingOrderStatus.cancelled => null,
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
    this.paymentTerm = '', // real payment method from the backend; '' = unknown
    this.source = '', // e.g. MANUAL_BY_MARKETING; '' = placed by the vendor
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

  /// Where the order came from. `MANUAL_BY_MARKETING` = created by the
  /// marketing team on the vendor's behalf (phone order); empty/anything else
  /// = placed by the vendor in their own app. Auditable via the backend's
  /// `source` + `createdBy` fields (see the manual-order API contract).
  final String source;
  final bool urgent;
  final bool isNew;

  /// True when this order was manually created by the marketing team.
  bool get isManual => source == 'MANUAL_BY_MARKETING';

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
        source: source,
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
    // --- Batch & expiry (managed by marketing; see BATCH_EXPIRY) ---
    this.batchNo = '',
    this.expiryDate,
    this.isExpiringSoon = false,
    // --- Customer-facing display fields (shown in the shopping app) ---
    this.rating = 4.5,
    this.reviewCount = 0,
    this.badge,
    this.packInfo = '',
    this.images = const [],
    this.video,
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

  /// Manufacturing batch number (e.g. "BCH240701A").
  final String batchNo;

  /// The batch's expiry date, or null when the product has none stored.
  final DateTime? expiryDate;

  /// True when the backend flags this batch as expiring within 90 days. The
  /// server computes it live from the current date (see the `isExpiringSoon`
  /// virtual), so it is always up to date without any client timer.
  final bool isExpiringSoon;

  // Customer-facing display fields. These have no effect on the inventory
  // workflow; they decorate the same record when it appears in the shop.
  final double rating;
  final int reviewCount;
  final String? badge; // e.g. NEW / BEST SELLER / LOW STOCK
  final String packInfo; // e.g. "Strip of 15 tablets"

  /// Ordered product images (`images.first` is the primary/thumbnail). Carries
  /// the Cloudinary publicId so the Edit flow can keep/delete each one.
  final List<ProductMedia> images;

  /// The optional promotional video, or null when the product has none.
  final ProductMedia? video;

  /// The primary image URL (first image), or null when the product has none.
  /// Kept so the many existing call-sites that read a single image URL still
  /// work unchanged.
  String? get imageUrl => images.isNotEmpty ? images.first.url : null;

  /// Every image URL, in display order.
  List<String> get imageUrls => images.map((m) => m.url).toList();

  /// The promotional video URL, or null.
  String? get videoUrl => video?.url;

  bool get hasVideo => video != null && video!.url.isNotEmpty;

  StockStatus get stockStatus {
    if (stock <= 0) return StockStatus.out;
    if (stock <= lowThreshold) return StockStatus.low;
    return StockStatus.inStock;
  }

  /// Maps the human category label the marketing head selects onto the
  /// category id the customer catalogue filters by. Keeps the two roles in
  /// sync without forcing them to share the exact same string.
  String get categoryId {
    switch (category) {
      case 'Lifesaving Injections':
        return 'injections';
      case 'Vaccines':
        return 'vaccines';
      case 'Medicine':
      default:
        return 'medicine';
    }
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
    String? batchNo,
    DateTime? expiryDate,
    bool? isExpiringSoon,
    double? rating,
    int? reviewCount,
    String? badge,
    String? packInfo,
    List<ProductMedia>? images,
    ProductMedia? video,
    bool clearVideo = false,
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
      batchNo: batchNo ?? this.batchNo,
      expiryDate: expiryDate ?? this.expiryDate,
      isExpiringSoon: isExpiringSoon ?? this.isExpiringSoon,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      badge: badge ?? this.badge,
      packInfo: packInfo ?? this.packInfo,
      images: images ?? this.images,
      video: clearVideo ? null : (video ?? this.video),
    );
  }
}

/// One physical inventory lot of a product (see the backend `productBatch`
/// collection). A product owns many of these — one per purchase over time. The
/// product's total stock is the SUM of every batch's [availableQuantity];
/// stock is consumed FEFO (nearest [expiryDate] first) by the backend.
@immutable
class ProductBatch {
  const ProductBatch({
    this.id = '',
    required this.batchNumber,
    required this.purchaseQuantity,
    required this.availableQuantity,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.manufacturingDate,
    this.expiryDate,
    this.supplier = '',
    this.isExpiringSoon = false,
  });

  final String id;
  final String batchNumber;
  final int purchaseQuantity;
  final int availableQuantity;
  final double purchasePrice;
  final double sellingPrice;
  final DateTime? manufacturingDate;
  final DateTime? expiryDate;
  final String supplier;

  /// Server-computed flag: this batch expires within 90 days (or already has).
  final bool isExpiringSoon;

  factory ProductBatch.fromJson(Map<String, dynamic> j) {
    double toDouble(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int toInt(Object? v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? toDate(Object? v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty || s == 'N/A') return null;
      return DateTime.tryParse(s);
    }

    return ProductBatch(
      id: (j['_id'] ?? '').toString(),
      batchNumber: (j['batch_number'] ?? '').toString(),
      purchaseQuantity: toInt(j['purchase_quantity']),
      availableQuantity: toInt(j['available_quantity']),
      purchasePrice: toDouble(j['purchase_price']),
      sellingPrice: toDouble(j['selling_price']),
      manufacturingDate: toDate(j['manufacturing_date']),
      expiryDate: toDate(j['expiry_date']),
      supplier: (j['supplier'] ?? '').toString(),
      isExpiringSoon: j['isExpiringSoon'] == true,
    );
  }

  /// The payload the batch endpoints expect (snake_case keys). Dates go as
  /// timezone-independent `YYYY-MM-DD` calendar dates (see [apiCalendarDate]);
  /// omitted when null so an edit that doesn't touch a date leaves it unchanged.
  Map<String, dynamic> toJson() => {
        'batch_number': batchNumber,
        'purchase_quantity': purchaseQuantity,
        'available_quantity': availableQuantity,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        if (manufacturingDate != null)
          'manufacturing_date': apiCalendarDate(manufacturingDate!),
        if (expiryDate != null) 'expiry_date': apiCalendarDate(expiryDate!),
        'supplier': supplier,
      };

  ProductBatch copyWith({
    String? batchNumber,
    int? purchaseQuantity,
    int? availableQuantity,
    double? purchasePrice,
    double? sellingPrice,
    DateTime? manufacturingDate,
    DateTime? expiryDate,
    String? supplier,
  }) {
    return ProductBatch(
      id: id,
      batchNumber: batchNumber ?? this.batchNumber,
      purchaseQuantity: purchaseQuantity ?? this.purchaseQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      expiryDate: expiryDate ?? this.expiryDate,
      supplier: supplier ?? this.supplier,
      isExpiringSoon: isExpiringSoon,
    );
  }
}

// =============================================================================
// DELIVERY AGENTS
// =============================================================================

/// A delivery partner, fetched live from the backend (users with
/// role == "delivery" in GET /vsArogya/all-vendors). Never dummy data.
@immutable
class DeliveryAgent {
  const DeliveryAgent({
    required this.id,
    required this.name,
    this.phone = '',
    this.city = '',
    this.email = '',
  });

  final String id;
  final String name;
  final String phone;
  final String city;
  final String email;

  /// Two-letter initials for the avatar (e.g. "Suresh Patil" -> "SP").
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory DeliveryAgent.fromJson(Map<String, dynamic> j) {
    final contact = (j['contact_person_name'] ?? '').toString().trim();
    final store = (j['store_name'] ?? '').toString().trim();
    return DeliveryAgent(
      id: (j['_id'] ?? '').toString(),
      name: contact.isNotEmpty
          ? contact
          : (store.isNotEmpty ? store : 'Delivery Agent'),
      phone: (j['mobile_no'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
    );
  }
}

// =============================================================================
// VENDOR ACCOUNTS (buyers)
// =============================================================================

/// A registered buyer/vendor account (pharmacy / distributor), fetched live
/// from the backend (GET /vsArogya/all-vendors, staff roles filtered out).
/// Used by the manual-order flow so marketing can place an order on a
/// vendor's behalf. Never dummy data.
@immutable
class VendorAccount {
  const VendorAccount({
    required this.id,
    required this.storeName,
    this.contactPerson = '',
    this.phone = '',
    this.city = '',
    this.email = '',
    this.approved = true,
  });

  final String id;
  final String storeName;
  final String contactPerson;
  final String phone;
  final String city;
  final String email;
  final bool approved;

  /// Two-letter initials for the avatar (e.g. "Apollo Pharmacy" -> "AP").
  String get initials {
    final parts = storeName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory VendorAccount.fromJson(Map<String, dynamic> j) {
    final store = (j['store_name'] ?? '').toString().trim();
    final contact = (j['contact_person_name'] ?? '').toString().trim();
    return VendorAccount(
      id: (j['_id'] ?? '').toString(),
      storeName: store.isNotEmpty ? store : (contact.isNotEmpty ? contact : 'Vendor'),
      contactPerson: contact,
      phone: (j['mobile_no'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      // Missing field → treated as approved (older accounts).
      approved: (j['approvalStatus'] ?? 'Approved').toString() == 'Approved',
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

  factory MarketingCoupon.fromJson(Map<String, dynamic> j) => MarketingCoupon(
        code: (j['code'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        redemptions: (j['redemptions'] as num?)?.toInt() ?? 0,
        active: j['active'] is bool ? j['active'] as bool : true,
        expired: j['expired'] is bool ? j['expired'] as bool : false,
      );

  MarketingCoupon copyWith({bool? active}) => MarketingCoupon(
        code: code,
        description: description,
        redemptions: redemptions,
        active: active ?? this.active,
        expired: expired,
      );
}

// =============================================================================
// OUTLET (a physical shop we run — marketing registers it and stocks it)
// =============================================================================

/// One outlet from GET /vsArogya/outlets. Mirrors the server's Outlet document
/// (model/outletregistersModel.js) minus the password.
class MarketingOutlet {
  const MarketingOutlet({
    required this.id,
    required this.name,
    required this.pin,
    this.ownerName = '',
    this.mobileNo = '',
    this.city = '',
    this.state = '',
    this.status = 'Active',
  });

  final String id;
  final String name;
  final String pin;
  final String ownerName;
  final String mobileNo;
  final String city;
  final String state;
  final String status;

  bool get isActive => status.toLowerCase() != 'inactive';

  /// Label for the dropdown row — e.g. "Sai Medical  ·  411001".
  String get dropdownLabel => '$name  ·  $pin';

  factory MarketingOutlet.fromJson(Map<String, dynamic> j) => MarketingOutlet(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        name: (j['outletName'] ?? '').toString(),
        pin: (j['pincode'] ?? '').toString(),
        ownerName: (j['ownerName'] ?? '').toString(),
        mobileNo: (j['mobileNo'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        state: (j['state'] ?? '').toString(),
        status: (j['status'] ?? 'Active').toString(),
      );
}
