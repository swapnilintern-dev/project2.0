// =============================================================================
// VS Arogya — Outlet Staff · Models
//
// Hand-written immutable models (no code-gen), matching the app's existing
// style (see customer_models.dart / delivery_models.dart): const constructors,
// final fields, tolerant fromJson(), toJson() emitting the exact backend wire
// tokens, and copyWith() for cart edits + live status updates.
//
// All order/payment/status vocabulary comes from outlet_enums.dart so there is
// ONE source of truth. Locked rules are reflected here:
//   #1 stock: [OutletStockItem.isOwnOutlet] separates full (own outlet) from
//      read-only (district) rows.
//   #2 type:  [OutletCustomerInfo.address] is only required for DELIVERY.
//   #3 money: paid state lives in [OutletOrderStatus] (server-owned) — no cash
//      / COD field exists anywhere in these models.
// =============================================================================

import 'outlet_enums.dart';

// -----------------------------------------------------------------------------
// STOCK
// -----------------------------------------------------------------------------

/// One product row shown in the Stock screen.
///
/// The same shape backs both tabs; [isOwnOutlet] decides whether the row is
/// actionable (own outlet → can add to cart) or read-only (district stock).
class OutletStockItem {
  const OutletStockItem({
    required this.id,
    required this.name,
    required this.price,
    required this.qtyAvailable,
    required this.isOwnOutlet,
    this.packSize = '',
    this.category = '',
    this.outletName = '',
    this.district = '',
  });

  final String id;
  final String name;

  /// Pack / unit label (e.g. "10 tablets", "100 ml"). Optional.
  final String packSize;
  final String category;

  final double price;
  final int qtyAvailable;

  /// True for the staff's OWN outlet stock (actionable). False for district
  /// stock, which is READ-ONLY — no add-to-cart, no edit (locked rule #1).
  final bool isOwnOutlet;

  /// Which outlet this row belongs to (shown on the district tab).
  final String outletName;
  final String district;

  bool get inStock => qtyAvailable > 0;

  factory OutletStockItem.fromJson(
    Map<String, dynamic> json, {
    bool isOwnOutlet = true,
  }) {
    return OutletStockItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['product_name'] ?? '').toString(),
      packSize: (json['packSize'] ?? json['pack_size'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      price: _toDouble(json['price']),
      qtyAvailable: _toInt(json['qtyAvailable'] ?? json['stock'] ?? json['qty']),
      isOwnOutlet: json['isOwnOutlet'] as bool? ?? isOwnOutlet,
      outletName: (json['outletName'] ?? json['outlet'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'packSize': packSize,
        'category': category,
        'price': price,
        'qtyAvailable': qtyAvailable,
        'isOwnOutlet': isOwnOutlet,
        'outletName': outletName,
        'district': district,
      };

  OutletStockItem copyWith({int? qtyAvailable}) => OutletStockItem(
        id: id,
        name: name,
        packSize: packSize,
        category: category,
        price: price,
        qtyAvailable: qtyAvailable ?? this.qtyAvailable,
        isOwnOutlet: isOwnOutlet,
        outletName: outletName,
        district: district,
      );
}

// -----------------------------------------------------------------------------
// CART (staff's working basket, before the order is created)
// -----------------------------------------------------------------------------

/// A single line in the staff's working cart. Built from an own-outlet
/// [OutletStockItem]; [qty] is editable in the Create Manual Order screen.
class OutletCartLine {
  const OutletCartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.packSize = '',
  });

  final String productId;
  final String name;
  final String packSize;
  final double price;
  final int qty;

  double get lineTotal => price * qty;

  factory OutletCartLine.fromStock(OutletStockItem item, {int qty = 1}) =>
      OutletCartLine(
        productId: item.id,
        name: item.name,
        packSize: item.packSize,
        price: item.price,
        qty: qty,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'packSize': packSize,
        'price': price,
        'qty': qty,
      };

  OutletCartLine copyWith({int? qty}) => OutletCartLine(
        productId: productId,
        name: name,
        packSize: packSize,
        price: price,
        qty: qty ?? this.qty,
      );
}

// -----------------------------------------------------------------------------
// CUSTOMER
// -----------------------------------------------------------------------------

/// Walk-in customer details captured by staff.
///
/// [address] is only required when the order is a DELIVERY (locked rule #2);
/// for a COUNTER order it stays null.
class OutletCustomerInfo {
  const OutletCustomerInfo({
    required this.name,
    required this.phone,
    this.address,
    this.vendorId = '',
  });

  final String name;
  final String phone;
  final String? address;

  /// The verified vendor this order is placed for. Outlet orders are always
  /// created against an admin-approved vendor (chosen from the picker), so
  /// [name] / [phone] / [address] are sourced from that vendor's registered
  /// profile rather than typed by hand.
  final String vendorId;

  bool get hasAddress => (address ?? '').trim().isNotEmpty;

  /// Builds the customer block from a selected [OutletVendor]. The delivery
  /// address is attached only for DELIVERY orders (locked rule #2) and comes
  /// straight from the vendor's registered address.
  factory OutletCustomerInfo.fromVendor(
    OutletVendor vendor, {
    bool includeAddress = false,
  }) =>
      OutletCustomerInfo(
        name: vendor.displayName,
        phone: vendor.phone,
        address: includeAddress && vendor.fullAddress.isNotEmpty
            ? vendor.fullAddress
            : null,
        vendorId: vendor.id,
      );

  factory OutletCustomerInfo.fromJson(Map<String, dynamic> json) =>
      OutletCustomerInfo(
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? json['mobile'] ?? '').toString(),
        address: json['address']?.toString(),
        vendorId: (json['vendorId'] ?? json['vendor'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        if (hasAddress) 'address': address,
        if (vendorId.isNotEmpty) 'vendorId': vendorId,
      };

  OutletCustomerInfo copyWith({
    String? name,
    String? phone,
    String? address,
    String? vendorId,
  }) =>
      OutletCustomerInfo(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        vendorId: vendorId ?? this.vendorId,
      );
}

// -----------------------------------------------------------------------------
// VENDOR (the admin-approved buyer an outlet order is placed for)
// -----------------------------------------------------------------------------

/// A verified (admin-approved) vendor shown in the manual-order picker. Mirrors
/// the fields the backend keeps on a vendor account (store_name /
/// contact_person_name / mobile_no / full_address / city / state / pin_code),
/// so a LiveOutletDataSource can map GET /all-vendors (approvalStatus
/// "Approved") straight onto it. Only approved vendors are ever returned.
class OutletVendor {
  const OutletVendor({
    required this.id,
    required this.storeName,
    required this.contactPerson,
    required this.phone,
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
  });

  final String id;
  final String storeName;
  final String contactPerson;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;

  /// Best label for the vendor — store name, falling back to the contact.
  String get displayName => storeName.trim().isNotEmpty
      ? storeName
      : (contactPerson.trim().isNotEmpty ? contactPerson : 'Vendor');

  bool get hasAddress => fullAddress.isNotEmpty;

  /// The registered address as one line (street, city, state, pincode).
  String get fullAddress => [address, city, state, pincode]
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .join(', ');

  factory OutletVendor.fromJson(Map<String, dynamic> json) => OutletVendor(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        storeName: (json['storeName'] ?? json['store_name'] ?? '').toString(),
        contactPerson:
            (json['contactPerson'] ?? json['contact_person_name'] ?? '')
                .toString(),
        phone: (json['phone'] ?? json['mobile_no'] ?? json['mobile'] ?? '')
            .toString(),
        address: (json['address'] ?? json['full_address'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        pincode: (json['pincode'] ?? json['pin_code'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeName': storeName,
        'contactPerson': contactPerson,
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
      };
}

// -----------------------------------------------------------------------------
// ORDER
// -----------------------------------------------------------------------------

/// A confirmed line inside an [OutletOrder] as returned by the server.
class OutletOrderLine {
  const OutletOrderLine({
    required this.name,
    required this.qty,
    required this.price,
    this.packSize = '',
  });

  final String name;
  final String packSize;
  final int qty;
  final double price;

  double get lineTotal => price * qty;

  factory OutletOrderLine.fromJson(Map<String, dynamic> json) =>
      OutletOrderLine(
        name: (json['name'] ?? '').toString(),
        packSize: (json['packSize'] ?? '').toString(),
        qty: _toInt(json['qty']),
        price: _toDouble(json['price']),
      );

  factory OutletOrderLine.fromCartLine(OutletCartLine line) => OutletOrderLine(
        name: line.name,
        packSize: line.packSize,
        qty: line.qty,
        price: line.price,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'packSize': packSize,
        'qty': qty,
        'price': price,
      };
}

/// An outlet order. Its [status] and [paidAt] are SERVER-OWNED — the client
/// only reads them (locked rule #3). Never construct one with [status] set to
/// paid on the client; use the value the backend/webhook reports.
class OutletOrder {
  const OutletOrder({
    required this.id,
    required this.type,
    required this.status,
    required this.paymentMethod,
    required this.lines,
    required this.customer,
    required this.total,
    required this.createdAt,
    this.idempotencyKey = '',
    this.paidAt,
  });

  final String id;
  final OutletOrderType type;
  final OutletOrderStatus status;
  final OutletPaymentMethod paymentMethod;
  final List<OutletOrderLine> lines;
  final OutletCustomerInfo customer;
  final double total;
  final DateTime createdAt;

  /// Generated once per cart on the client (Step 6) and echoed back by the
  /// server; guards against double-tap duplicate orders.
  final String idempotencyKey;

  /// When the server confirmed payment. Null until [status] reaches paid.
  final DateTime? paidAt;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  bool get isPaid => status.isPaid;
  bool get isAwaitingPayment => status.isAwaitingPayment;

  factory OutletOrder.fromJson(Map<String, dynamic> json) => OutletOrder(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        type: OutletOrderType.fromApi(json['type']?.toString()),
        status: OutletOrderStatus.fromApi(json['status']?.toString()),
        paymentMethod:
            OutletPaymentMethod.fromApi(json['paymentMethod']?.toString()),
        lines: (json['lines'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OutletOrderLine.fromJson)
            .toList(),
        customer: OutletCustomerInfo.fromJson(
          (json['customer'] as Map<String, dynamic>?) ?? const {},
        ),
        total: _toDouble(json['total']),
        createdAt: _toDate(json['createdAt']),
        idempotencyKey: (json['idempotencyKey'] ?? '').toString(),
        paidAt: json['paidAt'] == null ? null : _toDate(json['paidAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.api,
        'status': status.api,
        'paymentMethod': paymentMethod.api,
        'lines': lines.map((l) => l.toJson()).toList(),
        'customer': customer.toJson(),
        'total': total,
        'createdAt': createdAt.toIso8601String(),
        'idempotencyKey': idempotencyKey,
        if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
      };

  /// Applies a fresh server-reported [status] (used by the payment-screen and
  /// order-detail live polling). This is the ONLY sanctioned way the client
  /// changes an order's status — by copying what the server said.
  OutletOrder copyWith({
    OutletOrderStatus? status,
    DateTime? paidAt,
  }) =>
      OutletOrder(
        id: id,
        type: type,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        lines: lines,
        customer: customer,
        total: total,
        createdAt: createdAt,
        idempotencyKey: idempotencyKey,
        paidAt: paidAt ?? this.paidAt,
      );
}

// -----------------------------------------------------------------------------
// REQUESTS / PAYMENT
// -----------------------------------------------------------------------------

/// Payload for creating a manual order.
///
/// Carries the [idempotencyKey] generated once per cart (Step 6) so a
/// double-tapped "Create order" can never produce two orders.
class CreateOrderRequest {
  const CreateOrderRequest({
    required this.type,
    required this.paymentMethod,
    required this.lines,
    required this.customer,
    required this.idempotencyKey,
  });

  final OutletOrderType type;
  final OutletPaymentMethod paymentMethod;
  final List<OutletCartLine> lines;
  final OutletCustomerInfo customer;
  final String idempotencyKey;

  double get total => lines.fold(0.0, (sum, l) => sum + l.lineTotal);

  Map<String, dynamic> toJson() => {
        'type': type.api,
        'paymentMethod': paymentMethod.api,
        'idempotencyKey': idempotencyKey,
        'total': total,
        'lines': lines.map((l) => l.toJson()).toList(),
        'customer': customer.toJson(),
      };
}

/// What the backend returns when it creates a Razorpay order for an outlet
/// order — everything the razorpay_flutter checkout sheet needs to open.
/// Mirrors the customer flow's OnlinePayment. Amount is in paise.
class OutletOnlinePayment {
  const OutletOnlinePayment({
    required this.razorpayOrderId,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  final String razorpayOrderId;
  final int amount; // paise
  final String currency;
  final String keyId; // Razorpay publishable key id (rzp_test_… / rzp_live_…)

  factory OutletOnlinePayment.fromJson(Map<String, dynamic> json) =>
      OutletOnlinePayment(
        razorpayOrderId:
            (json['razorpayOrderId'] ?? json['razorpay_order_id'] ?? '')
                .toString(),
        amount: _toInt(json['amount']),
        currency: (json['currency'] ?? 'INR').toString(),
        keyId: (json['razorpayKeyId'] ?? json['keyId'] ?? json['key'] ?? '')
            .toString(),
      );
}

/// The payment session for an order — what the Payment screen renders.
///
/// Exactly one of [qrImageData] / [paymentLink] is populated, matching the
/// chosen [OutletPaymentMethod]. [status] is refreshed by polling; the client
/// never sets it to paid itself (locked rule #3).
class OutletPaymentInfo {
  const OutletPaymentInfo({
    required this.orderId,
    required this.amount,
    required this.status,
    this.qrImageData,
    this.paymentLink,
    this.expiresAt,
  });

  final String orderId;
  final double amount;
  final OutletOrderStatus status;

  /// Base64 / URL of the Razorpay QR image (QR method).
  final String? qrImageData;

  /// Razorpay payment link (payment-link method).
  final String? paymentLink;

  /// When the payment window lapses; after this the order expires and reserved
  /// stock is released.
  final DateTime? expiresAt;

  bool get isPaid => status.isPaid;

  factory OutletPaymentInfo.fromJson(Map<String, dynamic> json) =>
      OutletPaymentInfo(
        orderId: (json['orderId'] ?? json['id'] ?? '').toString(),
        amount: _toDouble(json['amount']),
        status: OutletOrderStatus.fromApi(json['status']?.toString()),
        qrImageData: json['qrImageData']?.toString(),
        paymentLink: json['paymentLink']?.toString(),
        expiresAt: json['expiresAt'] == null ? null : _toDate(json['expiresAt']),
      );

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'amount': amount,
        'status': status.api,
        if (qrImageData != null) 'qrImageData': qrImageData,
        if (paymentLink != null) 'paymentLink': paymentLink,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  OutletPaymentInfo copyWith({OutletOrderStatus? status}) => OutletPaymentInfo(
        orderId: orderId,
        amount: amount,
        status: status ?? this.status,
        qrImageData: qrImageData,
        paymentLink: paymentLink,
        expiresAt: expiresAt,
      );
}

// -----------------------------------------------------------------------------
// Parsing helpers (mirrors the private ones in customer_models.dart — kept
// local so this file has no cross-feature dependency).
// -----------------------------------------------------------------------------

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

DateTime _toDate(Object? v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  }
  return DateTime.now();
}
