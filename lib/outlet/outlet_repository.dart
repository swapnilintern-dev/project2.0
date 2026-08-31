// =============================================================================
// VS Arogya — Outlet Staff · Repository + DataSource contract
//
// The screens talk ONLY to [OutletRepository]. The repository delegates to an
// [OutletDataSource], which is swappable:
//   • LiveOutletDataSource — the default; every call goes to the real backend.
//   • MockOutletDataSource — in-memory data kept ONLY for widget tests; no
//     sign-in path can reach it anymore (a real session always has the outlet
//     id, and the shell refuses to render without one).
//
// LOCKED RULE #3: there is no "mark paid" method here. Payment status is only
// ever READ from the server (fetchOrderStatus / fetchOrder). The client can ask
// to advance an order to a fulfilment state (handed over / dispatch), but the
// datasource must reject that unless the order is already server-confirmed PAID.
// =============================================================================

import 'outlet_enums.dart';
import 'outlet_live_datasource.dart';
import 'outlet_models.dart';

/// The backend-facing contract for the Outlet Staff role. Every method is
/// offline-safe by convention (implementations degrade gracefully rather than
/// throwing raw network errors), matching the app's other API services.
abstract class OutletDataSource {
  /// Own-outlet stock (full, actionable) + district stock (read-only), combined
  /// into one list. Distinguish rows via [OutletStockItem.isOwnOutlet].
  Future<List<OutletStockItem>> fetchStock();

  /// One medicine's full detail — the catalog product, this outlet's stock
  /// totals and EVERY lot it holds (expired and emptied included), as the
  /// backend returns them. Backs the Stock → Medicine Details screen.
  Future<OutletMedicineDetail> fetchMedicineDetail(String productId);

  /// The outlet's SELLABLE lots for one product — available > 0, not past
  /// expiry, in the backend's FEFO order (nearest expiry first). Backs the
  /// batch picker; the order is the server's policy and is never re-sorted.
  Future<List<OutletBatch>> fetchAvailableBatches(String productId);

  /// Asks the backend whether [quantity] of [productId] can be issued from
  /// [overrides] (the lot the user pinned), auto-filling any remainder FEFO.
  /// NON-mutating — this is how a cart line is validated against live inventory
  /// before the order is placed.
  Future<OutletAllocationPreview> previewAllocation(
    String productId,
    int quantity, {
    List<OutletBatchAllocation> overrides = const [],
  });

  /// The admin-approved vendors an outlet order can be placed for. Only
  /// verified (approvalStatus "Approved") vendors are returned; the manual-order
  /// screen shows these in its picker instead of a typed walk-in name.
  Future<List<OutletVendor>> fetchVerifiedVendors();

  /// Creates a manual order in [OutletOrderStatus.awaitingPayment].
  ///
  /// Honours [CreateOrderRequest.idempotencyKey]: a repeat call with the same
  /// key returns the SAME order instead of creating a duplicate.
  Future<OutletOrder> createOrder(CreateOrderRequest request);

  /// Creates the Razorpay QR / payment link for an order.
  Future<OutletPaymentInfo> createPayment(
    String orderId,
    OutletPaymentMethod method,
  );

  /// Creates a Razorpay order on the server for [orderId] and returns the
  /// details the razorpay_flutter checkout sheet needs (order id, amount, key).
  /// Mirrors the customer flow's POST /create-payment.
  Future<OutletOnlinePayment> createRazorpayOrder(String orderId);

  /// Sends the razorpay_flutter success callback fields to the server, which
  /// recomputes + verifies the signature and (only then) marks the order paid.
  /// Returns whether the signature verified. The client NEVER sets paid itself
  /// (locked rule #3) — it still polls [fetchOrderStatus] for the real state.
  Future<bool> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String paymentId,
    required String signature,
  });

  /// Polls the server-owned payment status for [orderId] (Payment screen).
  Future<OutletOrderStatus> fetchOrderStatus(String orderId);

  /// All orders for this outlet, newest first.
  Future<List<OutletOrder>> fetchOrders();

  /// A single order's full detail.
  Future<OutletOrder> fetchOrder(String orderId);

  /// Requests a fulfilment transition (e.g. handed over, ready for pickup,
  /// out for delivery, delivered) or a cancel. Implementations MUST reject a
  /// fulfilment transition on an order that isn't server-confirmed paid.
  /// Cancel/expire releases any reserved stock.
  Future<OutletOrder> advanceOrder(String orderId, OutletOrderStatus to);
}

/// The single entry point the Outlet screens use. Thin pass-through today; the
/// place to add caching / retry / logging later without touching the UI.
class OutletRepository {
  OutletRepository({OutletDataSource? dataSource})
      : _ds = dataSource ?? LiveOutletDataSource.instance;

  final OutletDataSource _ds;

  Future<List<OutletStockItem>> fetchStock() => _ds.fetchStock();

  Future<OutletMedicineDetail> fetchMedicineDetail(String productId) =>
      _ds.fetchMedicineDetail(productId);

  Future<List<OutletBatch>> fetchAvailableBatches(String productId) =>
      _ds.fetchAvailableBatches(productId);

  Future<OutletAllocationPreview> previewAllocation(
    String productId,
    int quantity, {
    List<OutletBatchAllocation> overrides = const [],
  }) =>
      _ds.previewAllocation(productId, quantity, overrides: overrides);

  Future<List<OutletVendor>> fetchVerifiedVendors() =>
      _ds.fetchVerifiedVendors();

  Future<OutletOrder> createOrder(CreateOrderRequest request) =>
      _ds.createOrder(request);

  Future<OutletPaymentInfo> createPayment(
    String orderId,
    OutletPaymentMethod method,
  ) =>
      _ds.createPayment(orderId, method);

  Future<OutletOnlinePayment> createRazorpayOrder(String orderId) =>
      _ds.createRazorpayOrder(orderId);

  Future<bool> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String paymentId,
    required String signature,
  }) =>
      _ds.verifyPayment(
        orderId: orderId,
        razorpayOrderId: razorpayOrderId,
        paymentId: paymentId,
        signature: signature,
      );

  Future<OutletOrderStatus> fetchOrderStatus(String orderId) =>
      _ds.fetchOrderStatus(orderId);

  Future<List<OutletOrder>> fetchOrders() => _ds.fetchOrders();

  Future<OutletOrder> fetchOrder(String orderId) => _ds.fetchOrder(orderId);

  Future<OutletOrder> advanceOrder(String orderId, OutletOrderStatus to) =>
      _ds.advanceOrder(orderId, to);
}
