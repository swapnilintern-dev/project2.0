// =============================================================================
// VS Arogya — Outlet Staff · Live DataSource
//
// Implements the [OutletDataSource] contract against the real backend. The
// mock backs ONLY the local demo session (no outlet id — nothing to call the
// server with); every real session is fully live:
//
//   • fetchStock()            → GET  /vsArogya/outlet-products/:id
//   • fetchVerifiedVendors()  → GET  /vsArogya/all-vendors  (approved only)
//   • createOrder()           → POST /vsArogya/manual-cart/:vendorId/:productId
//                             → POST /vsArogya/manual-order/:vendorId
//                               (the same API the marketing role uses, now
//                               tagged with outletId so the order is traceable)
//   • fetchOrders()           → GET  /vsArogya/outlet-orders/:id
//   • fetchOrder()            → read from that same list
//   • createPayment()         → POST /vsArogya/outlet/orders/:id/payment
//   • createRazorpayOrder()   → POST /vsArogya/outlet/orders/:id/razorpay
//   • verifyPayment()         → POST /vsArogya/outlet/orders/:id/verify
//   • fetchOrderStatus()      → GET  /vsArogya/outlet/orders/:id/status
//
// advanceOrder() is refused outright rather than mocked — see below.
//
// LOCKED RULE #3 still holds: there is no "mark paid" path in this class. Paid
// state is only ever read from the server — the status endpoint is also where
// the server reconciles a pending payment link against Razorpay.
// =============================================================================

import 'package:flutter/foundation.dart' show debugPrint;

import 'outlet_api.dart';
import 'outlet_enums.dart';
import 'outlet_mock_datasource.dart';
import 'outlet_models.dart';
import 'outlet_repository.dart';
import 'outlet_session.dart';

class LiveOutletDataSource implements OutletDataSource {
  LiveOutletDataSource({OutletApi? api, OutletDataSource? fallback})
      : _api = api ?? OutletApi(),
        _fallback = fallback ?? MockOutletDataSource.instance;

  static final LiveOutletDataSource instance = LiveOutletDataSource();

  final OutletApi _api;

  /// Backs every call the server can't answer yet.
  final OutletDataSource _fallback;

  // ---------------------------------------------------------------------------
  // LIVE
  // ---------------------------------------------------------------------------

  /// The outlet's own stock, straight from the server.
  ///
  /// Falls back to the mock only when there is no live session (the local demo
  /// login has no outlet id) — NOT when the request fails. A network error must
  /// surface as an error rather than silently showing fake stock, which staff
  /// could then try to sell.
  @override
  Future<List<OutletStockItem>> fetchStock() async {
    final outletId = OutletSession.instance.outletId;
    if (outletId == null || outletId.isEmpty) {
      debugPrint('[OutletLive] no outletId (demo session) — using mock stock');
      return _fallback.fetchStock();
    }

    final (items, error) = await _api.fetchStock(outletId);
    if (error != null) throw OutletApiException(error);
    return items ?? const [];
  }

  /// The approved vendors an order can be placed for — GET /all-vendors.
  @override
  Future<List<OutletVendor>> fetchVerifiedVendors() async {
    final (vendors, error) = await _api.fetchVendors();
    if (error != null) throw OutletApiException(error);
    return vendors ?? const [];
  }

  /// Places the order through the marketing manual-order API
  /// (manual-cart ×qty → manual-order).
  ///
  /// KNOWN LIMITS of reusing that API — all need a server change to fix, none
  /// are client-side bugs:
  ///  1. The order is created against the VENDOR (`order.user = vendorId`) and
  ///     the order model has no outlet field, so it carries NO link back to
  ///     this outlet. That is why [fetchOrders] below still can't be live.
  ///  2. It does NOT deduct this outlet's stock — manualOrder never touches
  ///     OutletStock. The stock screen will keep showing the pre-sale figure.
  ///  3. It ignores `idempotencyKey`, so a double-submit creates two orders.
  ///     The manual-order screen guards this client-side.
  ///  4. It places the order from the vendor's WHOLE cart — anything the vendor
  ///     already had in their own cart is swept into this order.
  @override
  Future<OutletOrder> createOrder(CreateOrderRequest request) async {
    final (order, error) = await _api.createManualOrder(request);
    if (error != null) throw OutletApiException(error);
    return order!;
  }

  // ---------------------------------------------------------------------------
  // PAYMENT — live against /outlet/orders/:id/… (rolePaymentController.js).
  // The mock only ever backs the demo session, which has no outlet id.
  // ---------------------------------------------------------------------------

  bool get _isDemoSession {
    final outletId = OutletSession.instance.outletId;
    return outletId == null || outletId.isEmpty;
  }

  /// The QR / payment-link session. The server answers with a Razorpay payment
  /// link; scanning the QR opens that link's hosted checkout.
  @override
  Future<OutletPaymentInfo> createPayment(
    String orderId,
    OutletPaymentMethod method,
  ) async {
    if (_isDemoSession) return _fallback.createPayment(orderId, method);
    final (info, error) = await _api.createPaymentSession(orderId, method);
    if (error != null) throw OutletApiException(error);
    return info!;
  }

  @override
  Future<OutletOnlinePayment> createRazorpayOrder(String orderId) async {
    if (_isDemoSession) return _fallback.createRazorpayOrder(orderId);
    final (pay, error) = await _api.createRazorpayOrder(orderId);
    if (error != null) throw OutletApiException(error);
    return pay!;
  }

  @override
  Future<bool> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String paymentId,
    required String signature,
  }) async {
    if (_isDemoSession) {
      return _fallback.verifyPayment(
        orderId: orderId,
        razorpayOrderId: razorpayOrderId,
        paymentId: paymentId,
        signature: signature,
      );
    }
    final (verified, error) = await _api.verifyPayment(
      orderId: orderId,
      razorpayOrderId: razorpayOrderId,
      paymentId: paymentId,
      signature: signature,
    );
    if (error != null) throw OutletApiException(error);
    return verified ?? false;
  }

  /// Orders this outlet placed — GET /outlet-orders/:id.
  @override
  Future<List<OutletOrder>> fetchOrders() async {
    final outletId = OutletSession.instance.outletId;
    if (outletId == null || outletId.isEmpty) {
      debugPrint('[OutletLive] no outletId (demo session) — using mock orders');
      return _fallback.fetchOrders();
    }
    final (orders, error) = await _api.fetchOrders(outletId);
    if (error != null) throw OutletApiException(error);
    return orders ?? const [];
  }

  /// One order, taken from this outlet's list — there is no single-order
  /// endpoint scoped to an outlet, and reusing /single-order/:id would let any
  /// outlet read any order by id.
  @override
  Future<OutletOrder> fetchOrder(String orderId) async {
    final orders = await fetchOrders();
    for (final o in orders) {
      if (o.id == orderId) return o;
    }
    throw const OutletApiException('That order is no longer available.');
  }

  /// The payment screen's 3-second poll — GET /outlet/orders/:id/status. This
  /// is also where the server reconciles a pending payment link with Razorpay,
  /// so the QR flow flips to PAID without any client-side assertion.
  @override
  Future<OutletOrderStatus> fetchOrderStatus(String orderId) async {
    if (_isDemoSession) return _fallback.fetchOrderStatus(orderId);
    final (status, error) = await _api.fetchOrderStatus(orderId);
    if (error != null) throw OutletApiException(error);
    return status!;
  }

  @override
  Future<OutletOrder> advanceOrder(String orderId, OutletOrderStatus to) async {
    // These orders are fulfilled by the team through the vendor pipeline, not
    // by the outlet — and the mock would happily "advance" a REAL order id in
    // memory, showing staff a state the server never agreed to. Refuse loudly
    // instead. The detail screen hides these actions anyway.
    throw const OutletApiException(
      'This order is handled by the team — it can\'t be advanced from here.',
    );
  }
}

/// Thrown when the server rejects or can't answer an outlet call. Carries the
/// user-facing message the screens already show.
class OutletApiException implements Exception {
  const OutletApiException(this.message);

  final String message;

  @override
  String toString() => message;
}