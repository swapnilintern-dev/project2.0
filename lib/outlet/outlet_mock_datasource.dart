// =============================================================================
// VS Arogya — Outlet Staff · Mock DataSource
//
// A fully in-memory implementation of [OutletDataSource] used while the backend
// is being built. It behaves like a real server so every later screen can be
// developed and demoed end-to-end:
//
//   • fetchStock()   → seeded own-outlet stock (full) + district stock (read-only)
//   • createOrder()  → AWAITING_PAYMENT; reserves stock; idempotency-key aware
//   • createPayment()→ returns a mock QR / payment link, arms a payment timer
//   • fetchOrderStatus() → AWAITING_PAYMENT for ~10s, then PAID (server-owned)
//   • advanceOrder() → fulfilment transitions, guarded so nothing moves past
//                      payment until PAID; cancel/expire releases reserved stock
//
// Singleton so state (orders, reserved stock, payment timers) is shared across
// screens. Swap this out for a live datasource when ApiConfig.outlet* is ready.
// =============================================================================

import 'outlet_enums.dart';
import 'outlet_models.dart';
import 'outlet_repository.dart';

class MockOutletDataSource implements OutletDataSource {
  MockOutletDataSource._();
  static final MockOutletDataSource instance = MockOutletDataSource._();

  /// How long the mock keeps an order in AWAITING_PAYMENT before the "webhook"
  /// flips it to PAID. Matches the Step-3 spec (~10s).
  static const Duration mockPaymentDelay = Duration(seconds: 10);

  /// Simulated network latency so the UI's loading states are exercised.
  static const Duration _latency = Duration(milliseconds: 350);

  // In-memory state -----------------------------------------------------------

  /// orderId → order (mutable snapshot the mock updates as status changes).
  final Map<String, OutletOrder> _orders = {};

  /// idempotencyKey → orderId, so a repeat createOrder returns the same order.
  final Map<String, String> _idempotency = {};

  /// orderId → the instant the mock will consider payment received.
  final Map<String, DateTime> _paidAfter = {};

  /// Own-outlet stock levels (productId → qty), decremented on reserve.
  late final Map<String, int> _ownStock = {
    for (final s in _seedOwnStock) s.id: s.qtyAvailable,
  };

  int _seq = 0;

  // Reads ----------------------------------------------------------------------

  @override
  Future<List<OutletStockItem>> fetchStock() async {
    await Future<void>.delayed(_latency);
    // Own-outlet rows reflect live (reserved-adjusted) quantities.
    final own = _seedOwnStock
        .map((s) => s.copyWith(qtyAvailable: _ownStock[s.id] ?? s.qtyAvailable))
        .toList();
    return [...own, ..._seedDistrictStock];
  }

  @override
  Future<List<OutletVendor>> fetchVerifiedVendors() async {
    await Future<void>.delayed(_latency);
    // Every seeded vendor is admin-approved — a live datasource returns
    // GET /all-vendors filtered to approvalStatus "Approved".
    return _seedVendors;
  }

  @override
  Future<List<OutletOrder>> fetchOrders() async {
    await Future<void>.delayed(_latency);
    _reconcilePayments();
    final list = _orders.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<OutletOrder> fetchOrder(String orderId) async {
    await Future<void>.delayed(_latency);
    _reconcilePayments();
    return _orders[orderId] ?? _missing(orderId);
  }

  @override
  Future<OutletOrderStatus> fetchOrderStatus(String orderId) async {
    await Future<void>.delayed(_latency);
    _reconcilePayments();
    return (_orders[orderId] ?? _missing(orderId)).status;
  }

  // Writes ---------------------------------------------------------------------

  @override
  Future<OutletOrder> createOrder(CreateOrderRequest request) async {
    await Future<void>.delayed(_latency);

    // Idempotency: same cart key → same order, never a duplicate.
    final existingId = _idempotency[request.idempotencyKey];
    if (request.idempotencyKey.isNotEmpty && existingId != null) {
      return _orders[existingId]!;
    }

    final id = 'OUT${DateTime.now().millisecondsSinceEpoch}${_seq++}';
    final order = OutletOrder(
      id: id,
      type: request.type,
      status: OutletOrderStatus.awaitingPayment,
      paymentMethod: request.paymentMethod,
      lines: request.lines.map(OutletOrderLine.fromCartLine).toList(),
      customer: request.customer,
      total: request.total,
      createdAt: DateTime.now(),
      idempotencyKey: request.idempotencyKey,
    );

    _orders[id] = order;
    if (request.idempotencyKey.isNotEmpty) {
      _idempotency[request.idempotencyKey] = id;
    }
    _reserveStock(request.lines); // hold stock while awaiting payment
    return order;
  }

  @override
  Future<OutletPaymentInfo> createPayment(
    String orderId,
    OutletPaymentMethod method,
  ) async {
    await Future<void>.delayed(_latency);
    final order = _orders[orderId] ?? _missing(orderId);

    // Arm the mock "webhook": payment lands mockPaymentDelay from now.
    _paidAfter[orderId] = DateTime.now().add(mockPaymentDelay);

    final amountPaise = (order.total * 100).round();
    // "Both" mode: return a scannable QR (UPI intent) AND a payment link so the
    // Payment screen can show either. A live datasource returns Razorpay's real
    // QR image + Payment Link here.
    return OutletPaymentInfo(
      orderId: orderId,
      amount: order.total,
      status: order.status,
      qrImageData: 'upi://pay?pa=vsarogya@okhdfc&pn=VS%20Arogya'
          '&am=${order.total.toStringAsFixed(2)}&cu=INR&tn=$orderId',
      paymentLink: 'https://rzp.io/i/mock-$orderId?amount=$amountPaise',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<OutletOnlinePayment> createRazorpayOrder(String orderId) async {
    await Future<void>.delayed(_latency);
    final order = _orders[orderId] ?? _missing(orderId);
    // A live datasource returns the SERVER-created Razorpay order + publishable
    // key here (POST /outlet/orders/:id/payment). The mock returns placeholders
    // so the checkout flow is wired end-to-end; opening the real sheet needs a
    // real key from the backend.
    return OutletOnlinePayment(
      razorpayOrderId: 'order_mock_$orderId',
      amount: (order.total * 100).round(),
      currency: 'INR',
      keyId: 'rzp_test_MOCK', // replace via backend; invalid key won't open live
    );
  }

  @override
  Future<bool> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String paymentId,
    required String signature,
  }) async {
    await Future<void>.delayed(_latency);
    // The real server recomputes the signature and marks the order paid only if
    // it verifies. The mock treats any callback as verified and confirms
    // payment immediately — status still flows through the server-owned field.
    final order = _orders[orderId];
    if (order != null && order.status == OutletOrderStatus.awaitingPayment) {
      _orders[orderId] =
          order.copyWith(status: OutletOrderStatus.paid, paidAt: DateTime.now());
      _paidAfter.remove(orderId);
    }
    return true;
  }

  @override
  Future<OutletOrder> advanceOrder(String orderId, OutletOrderStatus to) async {
    await Future<void>.delayed(_latency);
    _reconcilePayments();
    final order = _orders[orderId] ?? _missing(orderId);

    // Cancel / expire is always allowed and releases the reserved stock.
    if (to.isReleased) {
      _releaseStock(order.lines);
      _paidAfter.remove(orderId);
      return _save(order.copyWith(status: to));
    }

    // Any fulfilment step requires server-confirmed payment (locked rule #3).
    if (!order.isPaid) {
      throw StateError(
        'Cannot move order $orderId to ${to.api} before it is PAID.',
      );
    }
    return _save(order.copyWith(status: to));
  }

  // Internals ------------------------------------------------------------------

  /// Flips any order whose mock payment timer has elapsed to PAID. This is the
  /// mock's stand-in for the Razorpay webhook — status only ever advances on
  /// the "server" side, never from client code.
  void _reconcilePayments() {
    final now = DateTime.now();
    for (final entry in _paidAfter.entries.toList()) {
      final order = _orders[entry.key];
      if (order == null) continue;
      if (order.status == OutletOrderStatus.awaitingPayment &&
          !now.isBefore(entry.value)) {
        _orders[entry.key] = order.copyWith(
          status: OutletOrderStatus.paid,
          paidAt: now,
        );
      }
    }
  }

  OutletOrder _save(OutletOrder order) {
    _orders[order.id] = order;
    return order;
  }

  void _reserveStock(List<OutletCartLine> lines) {
    for (final l in lines) {
      final current = _ownStock[l.productId];
      if (current != null) {
        _ownStock[l.productId] = (current - l.qty).clamp(0, current);
      }
    }
  }

  void _releaseStock(List<OutletOrderLine> lines) {
    for (final l in lines) {
      // Only own-outlet products are tracked; district stock is read-only.
      final match = _seedOwnStock.where((s) => s.name == l.name);
      if (match.isNotEmpty) {
        final id = match.first.id;
        _ownStock[id] = (_ownStock[id] ?? 0) + l.qty;
      }
    }
  }

  Never _missing(String orderId) =>
      throw StateError('Outlet order not found: $orderId');
}

// -----------------------------------------------------------------------------
// SEED DATA
// -----------------------------------------------------------------------------

/// The staff's OWN outlet stock — full access (add to cart, reserve).
final List<OutletStockItem> _seedOwnStock = const [
  OutletStockItem(
    id: 'own-1',
    name: 'Paracetamol 500mg',
    packSize: '10 tablets',
    category: 'medicine',
    price: 28.0,
    qtyAvailable: 120,
    isOwnOutlet: true,
    outletName: 'Ballari Outlet',
    district: 'Ballari',
  ),
  OutletStockItem(
    id: 'own-2',
    name: 'Amoxicillin 250mg',
    packSize: '10 capsules',
    category: 'medicine',
    price: 64.0,
    qtyAvailable: 60,
    isOwnOutlet: true,
    outletName: 'Ballari Outlet',
    district: 'Ballari',
  ),
  OutletStockItem(
    id: 'own-3',
    name: 'ORS Sachet',
    packSize: '21.8g',
    category: 'medicine',
    price: 22.0,
    qtyAvailable: 200,
    isOwnOutlet: true,
    outletName: 'Ballari Outlet',
    district: 'Ballari',
  ),
  OutletStockItem(
    id: 'own-4',
    name: 'Tetanus Vaccine',
    packSize: '0.5ml vial',
    category: 'vaccines',
    price: 145.0,
    qtyAvailable: 18,
    isOwnOutlet: true,
    outletName: 'Ballari Outlet',
    district: 'Ballari',
  ),
  OutletStockItem(
    id: 'own-5',
    name: 'Insulin Injection',
    packSize: '10ml vial',
    category: 'injections',
    price: 310.0,
    qtyAvailable: 4,
    isOwnOutlet: true,
    outletName: 'Ballari Outlet',
    district: 'Ballari',
  ),
];

/// District stock at OTHER outlets — READ-ONLY (locked rule #1): no add-to-cart,
/// no edit. Shown so staff can see where stock exists across the district.
final List<OutletStockItem> _seedDistrictStock = const [
  OutletStockItem(
    id: 'dist-1',
    name: 'Paracetamol 500mg',
    packSize: '10 tablets',
    category: 'medicine',
    price: 28.0,
    qtyAvailable: 340,
    isOwnOutlet: false,
    outletName: 'Hospet Outlet',
    district: 'Ballari',
  ),
  OutletStockItem(
    id: 'dist-2',
    name: 'Insulin Injection',
    packSize: '10ml vial',
    category: 'injections',
    price: 310.0,
    qtyAvailable: 26,
    isOwnOutlet: false,
    outletName: 'Hospet Outlet',
    district: 'Ballari',
  ),
  OutletStockItem(
    id: 'dist-3',
    name: 'Azithromycin 500mg',
    packSize: '5 tablets',
    category: 'medicine',
    price: 78.0,
    qtyAvailable: 90,
    isOwnOutlet: false,
    outletName: 'Sandur Outlet',
    district: 'Ballari',
  ),
  OutletStockItem(
    id: 'dist-4',
    name: 'Tetanus Vaccine',
    packSize: '0.5ml vial',
    category: 'vaccines',
    price: 145.0,
    qtyAvailable: 0,
    isOwnOutlet: false,
    outletName: 'Sandur Outlet',
    district: 'Ballari',
  ),
];

/// Admin-approved vendors the outlet can place manual orders for. A live
/// datasource replaces this with GET /all-vendors (approvalStatus "Approved").
final List<OutletVendor> _seedVendors = const [
  OutletVendor(
    id: 'ven-1',
    storeName: 'Sri Sai Medicals',
    contactPerson: 'Ravi Kumar',
    phone: '9876500011',
    address: 'Gandhi Nagar, Main Road',
    city: 'Ballari',
    state: 'Karnataka',
    pincode: '583101',
  ),
  OutletVendor(
    id: 'ven-2',
    storeName: 'Hospet Pharma',
    contactPerson: 'Anita Rao',
    phone: '9876500022',
    address: 'Station Road',
    city: 'Hospet',
    state: 'Karnataka',
    pincode: '583201',
  ),
  OutletVendor(
    id: 'ven-3',
    storeName: 'Sandur Health Care',
    contactPerson: 'Mahesh Patil',
    phone: '9876500033',
    address: 'Market Street',
    city: 'Sandur',
    state: 'Karnataka',
    pincode: '583119',
  ),
  OutletVendor(
    id: 'ven-4',
    storeName: 'Janatha Drug House',
    contactPerson: 'Suresh N',
    phone: '9876500044',
    address: 'Cowl Bazar',
    city: 'Ballari',
    state: 'Karnataka',
    pincode: '583102',
  ),
];
