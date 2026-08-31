// =============================================================================
// VS Arogya — Outlet Billing (POS) · Controller
//
// One ChangeNotifier that owns a single walk-in bill end-to-end, matching the
// app's existing controller style (see OutletCart / CartController):
//   • the customer draft (reuses VendorRegistrationModel so the exact same
//     register-vendor payload + validators are shared with the vendor screen),
//   • the billing cart (own-outlet stock lines, quantity-capped at stock),
//   • the order type + payment choice,
//   • and [submit], which orchestrates the whole reuse-only backend flow.
//
// SUBMIT FLOW (all existing endpoints — no server changes):
//   1. register the customer as a Vendor   (POST /register-vendor)   → Pending
//   2. resolve the new vendor's id          (GET  /all-vendors by mobile)
//   3. build the outlet server cart         (POST /outlet/add-cart × lines)
//   4. place the stock-deducting order      (POST /outlet/manual-order/:id)
//        → deducts outlet stock + renders the HTML-template invoice server-side
//
// The steps are guarded so a retry after a mid-flow failure never double-runs a
// completed step (re-register, re-add to cart, or duplicate the order).
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../vendor_registration_screen.dart' show VendorRegistrationModel;
import '../../shared/api_date.dart';
import '../outlet_api.dart';
import '../outlet_enums.dart';
import '../outlet_models.dart';

/// How the walk-in customer pays. COD needs no online step; Razorpay reuses the
/// existing outlet payment screen after the order exists.
enum BillingPayment { cod, razorpay }

/// One cart line — keeps the full stock item so the summary can show MRP, GST,
/// discount and the live stock cap without another fetch.
class BillingLine {
  BillingLine(this.item, this.qty);

  final OutletStockItem item;
  int qty;

  /// The FEFO batch breakdown for this line, as computed by the backend
  /// (single source of truth). Empty until the first preview returns.
  List<OutletBatchAllocation> allocations = const [];

  /// Units still unallocated per the last backend preview (0 = fully allocated).
  int remaining = 0;

  /// True while a preview/override request for this line is in flight.
  bool allocLoading = false;

  /// The last allocation error the backend returned for this line, if any.
  String? allocError;

  /// Whether the user has pinned a manual override on this line (so a later
  /// quantity change re-sends the overrides instead of a fresh FEFO).
  bool overridden = false;

  /// True once the backend has fully allocated the requested quantity.
  bool get isAllocated => remaining == 0 && allocError == null;

  double get lineTotal => item.price * qty;

  /// GST embedded in the (GST-inclusive) line total — mirrors the server
  /// invoice's slab extraction so the on-screen tax matches the printed one.
  double get lineGst => item.gstPercent <= 0
      ? 0
      : lineTotal - lineTotal / (1 + item.gstPercent / 100);

  /// The line valued at MRP (falls back to selling price when no MRP is set).
  double get lineMrpTotal => (item.mrp > item.price ? item.mrp : item.price) * qty;
}

/// The outcome of [BillingController.submit].
class BillingResult {
  const BillingResult._({required this.ok, this.error, this.order});

  factory BillingResult.success(OutletOrder order) =>
      BillingResult._(ok: true, order: order);
  factory BillingResult.failure(String error) =>
      BillingResult._(ok: false, error: error);

  final bool ok;
  final String? error;

  /// The placed order (for the invoice viewer + the Razorpay payment screen).
  final OutletOrder? order;
}

class BillingController extends ChangeNotifier {
  BillingController({OutletApi? api}) : _api = api ?? OutletApi();

  final OutletApi _api;

  /// The customer being billed. Reuses the vendor model so the success screen
  /// can hand it straight to the unchanged register-vendor API (in the
  /// background), and so its details bill the invoice.
  final VendorRegistrationModel customer = VendorRegistrationModel();

  final List<BillingLine> _lines = [];
  List<BillingLine> get lines => List.unmodifiable(_lines);

  OutletOrderType _orderType = OutletOrderType.counter;
  OutletOrderType get orderType => _orderType;
  set orderType(OutletOrderType v) {
    if (v == _orderType) return;
    _orderType = v;
    notifyListeners();
  }

  BillingPayment _payment = BillingPayment.cod;
  BillingPayment get payment => _payment;
  set payment(BillingPayment v) {
    if (v == _payment) return;
    _payment = v;
    notifyListeners();
  }

  // --- submit progress ---
  bool _submitting = false;
  bool get submitting => _submitting;
  String _phase = '';
  String get phase => _phase;

  // ---------------------------------------------------------------------------
  // CART
  // ---------------------------------------------------------------------------

  bool get isEmpty => _lines.isEmpty;
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.qty);
  int get distinctCount => _lines.length;

  int qtyOf(String productId) {
    for (final l in _lines) {
      if (l.item.id == productId) return l.qty;
    }
    return 0;
  }

  /// Adds/bumps a line, never letting the quantity exceed available stock.
  void add(OutletStockItem item, {int qty = 1}) {
    final idx = _lines.indexWhere((l) => l.item.id == item.id);
    if (idx >= 0) {
      _lines[idx].qty = _capped(item, _lines[idx].qty + qty);
      _lines[idx].overridden = false; // qty changed → back to auto FEFO
    } else {
      if (item.qtyAvailable <= 0) return;
      _lines.add(BillingLine(item, _capped(item, qty)));
    }
    notifyListeners();
    _scheduleAllocation(item.id);
  }

  void setQty(String productId, int qty) {
    final idx = _lines.indexWhere((l) => l.item.id == productId);
    if (idx < 0) return;
    if (qty <= 0) {
      _lines.removeAt(idx);
      _debouncers.remove(productId)?.cancel();
      notifyListeners();
      return;
    }
    _lines[idx].qty = _capped(_lines[idx].item, qty);
    _lines[idx].overridden = false; // qty changed → recompute from scratch
    notifyListeners();
    _scheduleAllocation(productId);
  }

  void increment(String productId) => setQty(productId, qtyOf(productId) + 1);
  void decrement(String productId) => setQty(productId, qtyOf(productId) - 1);
  void remove(String productId) => setQty(productId, 0);

  // ---------------------------------------------------------------------------
  // FEFO BATCH ALLOCATION (backend is the single source of truth)
  // ---------------------------------------------------------------------------

  /// Per-line debounce timers so rapid +/- taps collapse into one preview call.
  final Map<String, Timer> _debouncers = {};

  /// Debounced: ask the backend for this line's FEFO allocation.
  void _scheduleAllocation(String productId) {
    _debouncers[productId]?.cancel();
    _debouncers[productId] = Timer(
      const Duration(milliseconds: 350),
      () => _refreshAllocation(productId),
    );
  }

  /// Fetches (or re-validates) the FEFO allocation for one line from the
  /// backend. When the line is [BillingLine.overridden] the current pinned
  /// batches are sent so the server validates + fills the remainder FEFO.
  Future<void> _refreshAllocation(String productId,
      {List<OutletBatchAllocation>? overrides}) async {
    final idx = _lines.indexWhere((l) => l.item.id == productId);
    if (idx < 0) return;
    final line = _lines[idx];

    line.allocLoading = true;
    line.allocError = null;
    notifyListeners();

    final (allocs, remaining, _, error) = await _api.previewAllocation(
      productId,
      line.qty,
      overrides: overrides ?? (line.overridden ? line.allocations : const []),
    );

    // The line may have been removed/changed while the request was in flight.
    final cur = _lines.indexWhere((l) => l.item.id == productId);
    if (cur < 0) return;
    final l = _lines[cur];
    l.allocLoading = false;
    if (error != null) {
      l.allocError = error;
    } else {
      l.allocations = allocs;
      l.remaining = remaining;
      l.allocError = null;
    }
    notifyListeners();
  }

  /// Applies a manual batch override for a line (user edited quantities / picked
  /// another batch). The backend validates it, auto-fills the remainder FEFO and
  /// returns the corrected allocation.
  Future<void> overrideAllocation(
    String productId,
    List<OutletBatchAllocation> overrides,
  ) async {
    final idx = _lines.indexWhere((l) => l.item.id == productId);
    if (idx < 0) return;
    _lines[idx].overridden = true;
    _debouncers[productId]?.cancel();
    await _refreshAllocation(productId, overrides: overrides);
  }

  /// The outlet's sellable batches for the override picker.
  Future<(List<OutletBatch>?, String?)> availableBatches(String productId) =>
      _api.getOutletAvailableBatches(productId);

  /// True only when every line has a complete backend allocation — required
  /// before the bill can be generated.
  bool get allLinesAllocated =>
      _lines.isNotEmpty && _lines.every((l) => l.isAllocated);

  @override
  void dispose() {
    for (final t in _debouncers.values) {
      t.cancel();
    }
    _debouncers.clear();
    super.dispose();
  }

  /// Clamp a requested quantity to [1, stock].
  int _capped(OutletStockItem item, int qty) {
    if (qty < 1) return 1;
    if (qty > item.qtyAvailable) return item.qtyAvailable;
    return qty;
  }

  // ---------------------------------------------------------------------------
  // TOTALS (prices are GST-inclusive, so grandTotal == the server's totalAmount)
  // ---------------------------------------------------------------------------

  double get grandTotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);
  double get gstTotal => _lines.fold(0.0, (s, l) => s + l.lineGst);
  double get mrpTotal => _lines.fold(0.0, (s, l) => s + l.lineMrpTotal);

  /// Total saving vs MRP (never negative), shown as "Discount" on the summary.
  double get discountTotal {
    final d = mrpTotal - grandTotal;
    return d > 0 ? d : 0;
  }

  // ---------------------------------------------------------------------------
  // SUBMIT
  // ---------------------------------------------------------------------------

  /// Places the bill directly (deducts outlet stock + renders the invoice) with
  /// the customer's details inline — no pre-registered vendor needed, so this is
  /// fast. Vendor registration is submitted separately, in the background, from
  /// the success screen. Returns a [BillingResult]; the UI handles navigation.
  Future<BillingResult> submit() async {
    if (_submitting) return BillingResult.failure('A bill is already in progress.');
    if (_lines.isEmpty) return BillingResult.failure('Add at least one medicine.');

    _submitting = true;
    _phase = 'Placing bill…';
    notifyListeners();
    try {
      final items = [
        for (final l in _lines)
          {
            'productId': l.item.id,
            'quantity': l.qty,
            // Send the (possibly overridden) allocation so the backend honours
            // it after a final validation. Omitted when empty → pure FEFO.
            if (l.allocations.isNotEmpty)
              'allocations': l.allocations.map((a) => a.toJson()).toList(),
          },
      ];
      final (orderId, serverTotal, err) =
          await _api.placeOutletBill(customer: customerPayload, items: items);
      if (err != null) return BillingResult.failure(err);

      return BillingResult.success(
        _buildOrder(orderId ?? '', serverTotal ?? grandTotal),
      );
    } finally {
      _submitting = false;
      _phase = '';
      notifyListeners();
    }
  }

  /// The JSON body for POST /outlet/register-vendor (snake_case keys, NO files).
  /// Files the walk-in as a PENDING vendor for admin approval. GST is captured
  /// as a certificate number, so the vendor is recorded as GST-registered.
  Map<String, dynamic> get vendorRegistrationPayload => {
        'vendor_type': customer.vendorType ?? '',
        'shop_type': customer.shopType ?? '',
        'store_name': customer.storeName,
        'contact_person_name': customer.contactPerson,
        'mobile_no': customer.mobile,
        'email': customer.email,
        'full_address': customer.fullAddress,
        'city': customer.city,
        'state': customer.state,
        'pin_code': customer.pinCode,
        'gst_status': customer.gstNumber.trim().isNotEmpty ? 'yes' : 'no',
        'gst_no': customer.gstNumber,
        'drug_lic_no': customer.drugLicenseNumber,
        if (customer.drugLicenseExpiry != null)
          'drug_lic_ex_date': apiCalendarDate(customer.drugLicenseExpiry!),
      };

  /// The customer details the server bills the invoice to (matches the
  /// `customer` object the /outlet/bill endpoint reads).
  Map<String, dynamic> get customerPayload => {
        'name': customer.contactPerson,
        'firm': customer.storeName,
        'address': customer.fullAddress,
        'city': customer.city,
        'state': customer.state,
        'pincode': customer.pinCode,
        'phone': customer.mobile,
        'gstin': customer.gstNumber,
      };

  /// Builds the display order from the local bill + the server's id/total (the
  /// order response is unpopulated, so the lines come from our own cart —
  /// matching how OutletApi maps other manual orders).
  OutletOrder _buildOrder(String id, double total) => OutletOrder(
        id: id,
        type: orderType,
        status: OutletOrderStatus.awaitingPayment,
        // A neutral method that lets the reused payment screen mint a QR/link.
        paymentMethod: OutletPaymentMethod.qr,
        lines: [
          for (final l in _lines)
            OutletOrderLine(
              name: l.item.name,
              packSize: l.item.packSize,
              qty: l.qty,
              price: l.item.price,
            ),
        ],
        customer: OutletCustomerInfo(
          name: customer.storeName.isNotEmpty
              ? customer.storeName
              : customer.contactPerson,
          phone: customer.mobile,
          address: orderType.needsAddress ? customer.fullAddress : null,
        ),
        total: total,
        createdAt: DateTime.now(),
      );
}
