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
    this.mrp = 0,
    this.imageUrl = '',
    this.expiry,
    this.batch = '',
    this.batchCount = 0,
    this.gstPercent = 0,
    this.discountPercent = 0,
    this.hsnCode = '',
  });

  final String id;
  final String name;

  /// Pack / unit label (e.g. "10 tablets", "100 ml"). Optional.
  final String packSize;
  final String category;

  /// The selling price charged at billing (GST-inclusive, matching the invoice).
  final double price;
  final int qtyAvailable;

  // --- Billing / POS display fields (populated from the server product; all
  // optional so existing callers that don't set them keep working) ---

  /// Printed maximum retail price. 0 when the product has none set.
  final double mrp;

  /// First product image URL, or '' when none.
  final String imageUrl;

  /// Expiry of the lot this outlet will sell NEXT — i.e. the FEFO-front batch
  /// of the outlet's own stock, not the catalog's. Null when the lot carries no
  /// printed expiry (or the outlet holds no batched stock).
  final DateTime? expiry;

  /// Batch number of that same FEFO-front lot, or '' when none.
  final String batch;

  /// How many distinct lots of this medicine the outlet holds. > 1 means the
  /// next bill may span more than one batch, which the UI says explicitly.
  final int batchCount;

  /// GST slab % embedded in [price] (prices are GST-inclusive).
  final double gstPercent;

  /// Discount % off MRP, informational for the summary.
  final double discountPercent;

  /// HSN code, shown on the invoice.
  final String hsnCode;

  /// The saving vs MRP for one unit (0 when there is no higher MRP).
  double get mrpSaving => mrp > price ? mrp - price : 0;

  /// True when this batch expires within the next 90 days (or already has).
  /// Mirrors the backend `isExpiringSoon` rule so the Outlet POS shows the same
  /// red "Expiring Soon" alert the Marketing role sees. Computed from [expiry]
  /// on the current date — no timer, always live.
  bool get isExpiringSoon {
    final e = expiry;
    if (e == null) return false;
    return e.difference(DateTime.now()).inDays <= 90;
  }

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
      mrp: _toDouble(json['mrp']),
      imageUrl: (json['imageUrl'] ?? json['image'] ?? '').toString(),
      expiry: json['expiry'] == null ? null : _toDate(json['expiry']),
      batch: (json['batch'] ?? json['batch_no'] ?? '').toString(),
      batchCount: _toInt(json['batchCount'] ?? json['batch_count']),
      gstPercent: _toDouble(json['gstPercent']),
      discountPercent: _toDouble(json['discountPercent']),
      hsnCode: (json['hsnCode'] ?? '').toString(),
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
        'mrp': mrp,
        'imageUrl': imageUrl,
        if (expiry != null) 'expiry': expiry!.toIso8601String(),
        'batch': batch,
        'batchCount': batchCount,
        'gstPercent': gstPercent,
        'discountPercent': discountPercent,
        'hsnCode': hsnCode,
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
        mrp: mrp,
        imageUrl: imageUrl,
        expiry: expiry,
        batch: batch,
        batchCount: batchCount,
        gstPercent: gstPercent,
        discountPercent: discountPercent,
        hsnCode: hsnCode,
      );
}

// -----------------------------------------------------------------------------
// BATCHES (FEFO allocation for POS billing — backend is the source of truth)
// -----------------------------------------------------------------------------

/// One batch the outlet holds for a product. Read-only — the backend computes
/// availability, ordering (FEFO) and the ≤90-day [isExpiringSoon] flag.
///
/// The SAME model backs two reads of the one endpoint:
///   • the manual-override picker — sellable lots only (available > 0, not
///     expired), which is the default response;
///   • Medicine Details (`?all=1`) — every lot, expired and emptied included,
///     with the lot's own pricing, supplier and dates.
/// The extra fields simply stay at their defaults on the sellable read, so
/// nothing that already consumes this model changes.
class OutletBatch {
  const OutletBatch({
    required this.id,
    required this.batchNumber,
    required this.available,
    this.expiry,
    this.purchaseDate,
    this.isExpiringSoon = false,
    this.manufacturingDate,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.supplier = '',
    this.updatedAt,
  });

  final String id;
  final String batchNumber;
  final int available;
  final DateTime? expiry;

  /// When this lot was credited to the outlet (`createdAt` server-side).
  final DateTime? purchaseDate;
  final bool isExpiringSoon;

  /// Printed manufacturing date. Carried by the CATALOG lot this outlet batch
  /// came from (outlet batches never copied it), so it is null for stock whose
  /// source lot no longer exists — the UI shows "—" rather than inventing one.
  final DateTime? manufacturingDate;

  /// The lot's own rates, as recorded when the stock was assigned. 0 means the
  /// lot carries none and the product's price applies.
  final double purchasePrice;
  final double sellingPrice;

  final String supplier;

  /// Last server-side change to this lot (a sale, a re-assignment).
  final DateTime? updatedAt;

  /// True when the printed expiry has already passed. The sellable read never
  /// returns these (the server filters them out), so this only ever fires on the
  /// `?all=1` read — where the UI must show them as un-sellable.
  bool get isExpired {
    final e = expiry;
    return e != null && !e.isAfter(DateTime.now());
  }

  /// True when this lot can actually be issued right now — the same rule the
  /// backend applies when it allocates FEFO.
  bool get isSellable => available > 0 && !isExpired;

  factory OutletBatch.fromJson(Map<String, dynamic> j) => OutletBatch(
        id: (j['_id'] ?? j['batch'] ?? '').toString(),
        batchNumber: (j['batch_number'] ?? '').toString(),
        available: _toInt(j['available_quantity']),
        expiry: j['expiry_date'] == null ? null : _toDate(j['expiry_date']),
        purchaseDate:
            j['created_at'] == null ? null : _toDate(j['created_at']),
        isExpiringSoon: j['isExpiringSoon'] == true,
        manufacturingDate: j['manufacturing_date'] == null
            ? null
            : _toDate(j['manufacturing_date']),
        purchasePrice: _toDouble(j['purchase_price']),
        sellingPrice: _toDouble(j['selling_price']),
        supplier: (j['supplier'] ?? '').toString(),
        updatedAt: j['updated_at'] == null ? null : _toDate(j['updated_at']),
      );
}

/// Everything the Stock → Medicine Details screen shows, as returned by ONE
/// call to `GET /outlet/product/:id/available-batches?all=1`: the catalog
/// product, this outlet's stock totals, and every lot it holds.
///
/// Nothing here is computed on the client — [totalStock] is the server's SUM
/// over the lots and [stockMirror] the outlet's stored quantity, so the screen
/// can only ever show what the database holds.
class OutletMedicineDetail {
  const OutletMedicineDetail({
    required this.productId,
    required this.name,
    required this.batches,
    required this.totalStock,
    required this.stockMirror,
    required this.batchCount,
    this.description = '',
    this.category = '',
    this.brand = '',
    this.manufacturer = '',
    this.marketedBy = '',
    this.code = '',
    this.packInfo = '',
    this.packOf = 0,
    this.hsnCode = '',
    this.gstPercent = 0,
    this.discountPercent = 0,
    this.price = 0,
    this.mrp = 0,
    this.imageUrl = '',
    this.coldStored = '',
    this.prescriptionRequired = false,
    this.createdAt,
    this.updatedAt,
    this.showsAllLots = true,
  });

  final String productId;
  final String name;

  /// Every lot this outlet holds, in the backend's FEFO order (nearest expiry
  /// first). Never re-sorted here — the server's order IS the policy.
  final List<OutletBatch> batches;

  /// Sum of the lots' available quantities, computed server-side.
  final int totalStock;

  /// The outlet's stored `outletStock.quantity` mirror. Equals [totalStock]
  /// for batched stock; shown separately so a drift is visible rather than
  /// silently hidden.
  final int stockMirror;

  final int batchCount;

  final String description;
  final String category;
  final String brand;
  final String manufacturer;
  final String marketedBy;
  final String code;
  final String packInfo;
  final int packOf;
  final String hsnCode;
  final double gstPercent;
  final double discountPercent;

  /// The selling price charged at billing (GST-inclusive).
  final double price;
  final double mrp;
  final String imageUrl;
  final String coldStored;
  final bool prescriptionRequired;

  /// When the medicine was added to the catalog / last edited.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True when [batches] is every lot the outlet holds. False when the server
  /// answering the call predates the `?all=1` flag and could only return the
  /// SELLABLE lots — the figures shown are still live and correct, but expired
  /// and emptied lots are missing, and the screen says so rather than implying
  /// they don't exist.
  final bool showsAllLots;

  double get mrpSaving => mrp > price ? mrp - price : 0;

  /// Lots that can actually be sold right now — the same rule the backend
  /// applies when it allocates FEFO (in stock and not past expiry).
  int get sellableBatchCount => batches
      .where((b) =>
          b.available > 0 &&
          (b.expiry == null || b.expiry!.isAfter(DateTime.now())))
      .length;

  /// Reads the `?all=1` response body. [showsAllLots] is false when the caller
  /// assembled this from a server that predates that flag (see
  /// [OutletApi.fetchMedicineDetail]).
  factory OutletMedicineDetail.fromJson(
    Map<String, dynamic> json, {
    bool showsAllLots = true,
  }) {
    final p = (json['product'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rows = (json['batches'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OutletBatch.fromJson)
        .toList();

    return OutletMedicineDetail(
      productId: (p['_id'] ?? p['id'] ?? '').toString(),
      name: (p['title'] ?? '').toString(),
      batches: rows,
      totalStock: _toInt(json['total_stock']),
      stockMirror: _toInt(json['stock']),
      batchCount: _toInt(json['batch_count']),
      description: (p['description'] ?? '').toString(),
      category: (p['category'] ?? '').toString(),
      brand: (p['brand'] ?? '').toString(),
      manufacturer: (p['manufacturer'] ?? '').toString(),
      marketedBy: (p['marketedBy'] ?? '').toString(),
      code: (p['code'] ?? '').toString(),
      packInfo: (p['packInfo'] ?? '').toString(),
      packOf: _toInt(p['packOf']),
      hsnCode: (p['hsnCode'] ?? '').toString(),
      gstPercent: _toDouble(p['gstPercent']),
      discountPercent: _toDouble(p['discountPercent']),
      price: _toDouble(p['price']),
      mrp: _toDouble(p['mrp']),
      imageUrl: _firstImageUrl(p['image']),
      coldStored: (p['cold_stored'] ?? '').toString(),
      prescriptionRequired: p['prescriptionRequired'] == true,
      createdAt: p['createdAt'] == null ? null : _toDate(p['createdAt']),
      updatedAt: p['updatedAt'] == null ? null : _toDate(p['updatedAt']),
      showsAllLots: showsAllLots,
    );
  }

  /// The first usable URL from a product's `image: [{ url, publicId }]` array.
  static String _firstImageUrl(Object? images) {
    if (images is List) {
      for (final img in images) {
        if (img is Map && (img['url'] ?? '').toString().isNotEmpty) {
          return img['url'].toString();
        }
      }
    }
    return '';
  }
}

/// One batch allocated to a bill line (part of the FEFO breakdown). The backend
/// returns these; the app displays them and, on override, sends them back.
class OutletBatchAllocation {
  const OutletBatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    this.expiry,
  });

  final String batchId;
  final String batchNumber;
  final int quantity;
  final DateTime? expiry;

  factory OutletBatchAllocation.fromJson(Map<String, dynamic> j) =>
      OutletBatchAllocation(
        batchId: (j['batch'] ?? '').toString(),
        batchNumber: (j['batch_number'] ?? '').toString(),
        quantity: _toInt(j['quantity']),
        expiry: j['expiry_date'] == null ? null : _toDate(j['expiry_date']),
      );

  /// The override payload the backend expects: a pinned batch + quantity.
  Map<String, dynamic> toJson() => {
        'batch': batchId,
        'batch_number': batchNumber,
        'quantity': quantity,
      };

  OutletBatchAllocation copyWith({int? quantity}) => OutletBatchAllocation(
        batchId: batchId,
        batchNumber: batchNumber,
        quantity: quantity ?? this.quantity,
        expiry: expiry,
      );
}

/// The backend's answer to "can this quantity be issued, from these lots?" —
/// POST /outlet/allocate-preview. NON-mutating, so it is the safe way to
/// validate a cart line (stock, batch, expiry and outlet ownership are all
/// checked server-side) before anything is committed.
class OutletAllocationPreview {
  const OutletAllocationPreview({
    required this.allocations,
    required this.remaining,
    this.availableBatches = const [],
  });

  /// The lots the server would actually consume, in FEFO order.
  final List<OutletBatchAllocation> allocations;

  /// Units the server could NOT place on any lot. 0 means the line is fully
  /// coverable right now; anything higher means the outlet is short.
  final int remaining;

  /// The outlet's sellable lots for the product, as the server sees them.
  final List<OutletBatch> availableBatches;

  bool get isComplete => remaining <= 0;
}

// -----------------------------------------------------------------------------
// CART (staff's working basket, before the order is created)
// -----------------------------------------------------------------------------

/// A single line in the staff's working cart. Built from an own-outlet
/// [OutletStockItem] together with the LOT it will be issued from; both [qty]
/// and the pinned batch are editable in the Create Manual Order screen.
///
/// BATCH-WISE ORDERING: a line carries the exact [batchId] the user picked, so
/// the order pins that lot instead of leaving the server to pick FEFO. The
/// backend still re-validates the pin against live availability at order time
/// (previewOutletAllocation → allocateOutletFEFO) and remains the final
/// authority on what is actually deducted.
class OutletCartLine {
  const OutletCartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.packSize = '',
    this.batch = '',
    this.expiry,
    this.batchCount = 0,
    this.batchId = '',
    this.batchAvailable = 0,
  });

  final String productId;
  final String name;
  final String packSize;
  final double price;
  final int qty;

  /// Batch NUMBER of the pinned lot (what staff and the invoice read).
  final String batch;
  final DateTime? expiry;

  /// How many lots of this medicine the outlet holds; > 1 means another lot
  /// could have been chosen instead.
  final int batchCount;

  /// The `outletStockBatch._id` of the pinned lot — the id the backend pins an
  /// allocation to. Empty means no batch has been chosen yet, which the order
  /// screen refuses to submit.
  final String batchId;

  /// Units the pinned lot held when it was last read from the server. This is
  /// the quantity CEILING for this line: a single batch can never give more
  /// than it holds.
  final int batchAvailable;

  bool get hasBatch => batchId.isNotEmpty;

  /// The most this line may be raised to, or 0 when the server has not reported
  /// a per-lot figure (no batch pinned yet) — a cap is never invented here.
  int get maxQty => batchAvailable;

  /// True when the line is already at its pinned lot's ceiling.
  bool get isAtMax => batchAvailable > 0 && qty >= batchAvailable;

  double get lineTotal => price * qty;

  /// Builds the line from a stock row plus the lot the user chose. Without
  /// [batch] the line falls back to the row's FEFO-front lot for display only —
  /// [batchId] stays empty, so it still counts as "no batch chosen".
  factory OutletCartLine.fromStock(
    OutletStockItem item, {
    int qty = 1,
    OutletBatch? batch,
  }) =>
      OutletCartLine(
        productId: item.id,
        name: item.name,
        packSize: item.packSize,
        price: item.price,
        qty: qty,
        batch: batch?.batchNumber ?? item.batch,
        expiry: batch?.expiry ?? item.expiry,
        batchCount: item.batchCount,
        batchId: batch?.id ?? '',
        batchAvailable: batch?.available ?? 0,
      );

  /// The `allocations` entry every batch-aware backend endpoint accepts: this
  /// line's whole quantity pinned to the chosen lot. Both identifiers are sent
  /// so the server can still resolve the lot if its id changed.
  OutletBatchAllocation get allocation => OutletBatchAllocation(
        batchId: batchId,
        batchNumber: batch,
        quantity: qty,
        expiry: expiry,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'packSize': packSize,
        'price': price,
        'qty': qty,
        'batch': batch,
        if (expiry != null) 'expiry': expiry!.toIso8601String(),
        'batchCount': batchCount,
        'batchId': batchId,
        'batchAvailable': batchAvailable,
      };

  /// Copies the line. Passing [batch] re-pins it to another lot (which also
  /// resets [batchAvailable], the quantity cap).
  OutletCartLine copyWith({int? qty, OutletBatch? batch}) => OutletCartLine(
        productId: productId,
        name: name,
        packSize: packSize,
        price: price,
        qty: qty ?? this.qty,
        batch: batch?.batchNumber ?? this.batch,
        expiry: batch == null ? expiry : batch.expiry,
        batchCount: batchCount,
        batchId: batch?.id ?? batchId,
        batchAvailable: batch?.available ?? batchAvailable,
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
    this.teamFulfilled = false,
    this.serverStatusLabel = '',
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

  /// True for orders that live in the VENDOR pipeline — placed by this outlet
  /// through the manual-order API, then confirmed, invoiced and delivered by
  /// the team. The outlet only watches these: it must not be offered "collect
  /// payment" or "mark handed over", because neither is its job and neither is
  /// possible against that API.
  final bool teamFulfilled;

  /// The server's own status string ("Pending", "Confirm Order", "Shipped", …)
  /// for a [teamFulfilled] order. [status] is the nearest outlet-vocabulary
  /// equivalent for colouring and ordering; this is what actually happened, so
  /// it is what the detail screen shows the user.
  final String serverStatusLabel;

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
        teamFulfilled: teamFulfilled,
        serverStatusLabel: serverStatusLabel,
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
