// =============================================================================
// MediCaPlus — Marketing Head · Outlet-by-pincode MOCK source
//
// UI-only placeholder data for the Select-Outlet flow. Mirrors the spec's
// "Outlet model" (Name, Pin, Username, Password) — only the display-relevant
// fields are modelled here; auth fields are intentionally omitted until backend
// integration.
//
// This entire file is a stand-in for a future backend endpoint
// (e.g. GET /outlets?pincode=XXXXXX). When wiring the real API, replace
// [MarketingOutletMock.outletsForPincode] with a repository call — the screen
// only depends on that one function + the [MarketingOutlet] shape.
// =============================================================================

/// One outlet as shown in the pincode dropdown. Kept deliberately small: just
/// what the UI needs to identify and label an outlet.
class MarketingOutlet {
  const MarketingOutlet({
    required this.id,
    required this.name,
    required this.pin,
  });

  final String id;
  final String name;
  final String pin;

  /// Label for the dropdown row — e.g. "Sai Medical  ·  411001".
  String get dropdownLabel => '$name  ·  $pin';
}

/// Mock lookup. Returns the outlets registered against [pin]. A few sample
/// pincodes are populated so the dropdown visibly filters; any other (valid
/// 6-digit) pincode returns an empty list → the screen shows "no outlets found".
class MarketingOutletMock {
  const MarketingOutletMock._();

  /// Sample outlet directory keyed by pincode. Replace with a backend call.
  static const Map<String, List<MarketingOutlet>> _byPincode = {
    '411001': [
      MarketingOutlet(id: 'o1', name: 'Sai Medical Store', pin: '411001'),
      MarketingOutlet(id: 'o2', name: 'Arogya Pharmacy', pin: '411001'),
      MarketingOutlet(id: 'o3', name: 'City Care Chemist', pin: '411001'),
    ],
    '411002': [
      MarketingOutlet(id: 'o4', name: 'Wellness Medicals', pin: '411002'),
      MarketingOutlet(id: 'o5', name: 'Shree Drug House', pin: '411002'),
    ],
    '110001': [
      MarketingOutlet(id: 'o6', name: 'Capital Pharmacy', pin: '110001'),
    ],
  };

  /// Outlets for [pin] (empty if none registered). Synchronous mock — the real
  /// implementation will be async against the backend.
  static List<MarketingOutlet> outletsForPincode(String pin) {
    return _byPincode[pin] ?? const [];
  }
}

// -----------------------------------------------------------------------------
// PRODUCTS (mock catalog for the select-product → quantity step)
// -----------------------------------------------------------------------------

/// One orderable product row shown after an outlet is chosen. Minimal display
/// shape — swap for the real product source at backend-integration time.
class MarketingOrderProduct {
  const MarketingOrderProduct({
    required this.id,
    required this.name,
    required this.price,
    this.packSize = '',
  });

  final String id;
  final String name;
  final double price;

  /// Pack / unit label (e.g. "10 tablets", "100 ml"). Optional.
  final String packSize;
}

/// Mock product catalog for the outlet-order flow. Not pincode/outlet specific
/// for now — a flat sample list so the product/quantity UI is exercisable.
/// Replace with a backend call (e.g. GET /all-products) later.
class MarketingProductMock {
  const MarketingProductMock._();

  static const List<MarketingOrderProduct> _catalog = [
    MarketingOrderProduct(
        id: 'p1', name: 'Paracetamol 500mg', price: 25, packSize: '10 tablets'),
    MarketingOrderProduct(
        id: 'p2', name: 'Amoxicillin 250mg', price: 60, packSize: '10 capsules'),
    MarketingOrderProduct(
        id: 'p3', name: 'Cough Syrup', price: 85, packSize: '100 ml'),
    MarketingOrderProduct(
        id: 'p4', name: 'Vitamin C', price: 120, packSize: '30 tablets'),
    MarketingOrderProduct(
        id: 'p5', name: 'ORS Powder', price: 20, packSize: '21.8 g'),
    MarketingOrderProduct(
        id: 'p6', name: 'Antacid Gel', price: 95, packSize: '170 ml'),
  ];

  /// The full mock catalog. Synchronous mock — real impl will be async.
  static List<MarketingOrderProduct> all() => _catalog;
}

// -----------------------------------------------------------------------------
// STOCK ASSIGNMENT (mock store for the "Done" action)
// -----------------------------------------------------------------------------

/// One product+quantity line the marketing head assigns to an outlet.
class MarketingStockAssignmentItem {
  const MarketingStockAssignmentItem({
    required this.productId,
    required this.name,
    required this.qty,
  });

  final String productId;
  final String name;
  final int qty;
}

/// In-memory record of stock the marketing head has assigned to outlets. This
/// is the seam a future backend call replaces (e.g.
/// POST /outlets/{id}/assign-stock): the outlet role would then read this stock
/// on its own Stock screen. For now it just proves the flow end-to-end in the
/// UI without any persistence beyond the app session.
class MarketingStockAssignmentMock {
  const MarketingStockAssignmentMock._();

  /// outletId → the items most recently assigned to it (mock, session-only).
  static final Map<String, List<MarketingStockAssignmentItem>> _assigned = {};

  /// Records [items] as assigned to the outlet. [pincode] is kept for parity
  /// with the future backend contract (assignment is scoped by outlet+pincode).
  static void assign({
    required String outletId,
    required String pincode,
    required List<MarketingStockAssignmentItem> items,
  }) {
    _assigned[outletId] = List.unmodifiable(items);
  }

  /// What has been assigned to [outletId] so far (empty if nothing).
  static List<MarketingStockAssignmentItem> assignedTo(String outletId) =>
      _assigned[outletId] ?? const [];
}
