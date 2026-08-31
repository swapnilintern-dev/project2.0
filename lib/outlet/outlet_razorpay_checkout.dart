// =============================================================================
// VS Arogya — Outlet Staff · Razorpay checkout (shared)
//
// ONE place that runs the outlet role's on-device Razorpay checkout, so every
// outlet screen that collects money (Payment, Manual order, Billing/POS, and
// anything added later) shares the exact same order-first → open → verify
// sequence instead of re-implementing it.
//
// It reuses, unchanged:
//   • the razorpay_flutter package + event listeners the customer checkout uses,
//   • OutletRepository.createRazorpayOrder()  → POST /outlet/orders/:id/razorpay
//   • OutletRepository.verifyPayment()        → POST /outlet/orders/:id/verify
//   • the outlet session token that already authenticates those calls.
//
// Nothing on the server changes: those two endpoints (rolePaymentController.js)
// already existed for the outlet role and are scoped to order.outlet == the
// signed-in outlet. Because the checkout is opened against a SERVER-created
// Razorpay order id, the sheet offers every method Razorpay has enabled for the
// account — UPI (GPay / PhonePe / Paytm / BHIM / UPI id), cards, net banking,
// wallets, EMI, pay-later — plus anything Razorpay adds later, with no client
// change.
//
// LOCKED RULE #3 is untouched: a successful callback is only ever FORWARDED to
// the server to verify. This class never marks an order paid; callers still read
// the real state from fetchOrderStatus().
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'outlet_live_datasource.dart' show OutletApiException;
import 'outlet_models.dart';
import 'outlet_repository.dart';

/// How a checkout attempt ended.
enum OutletCheckoutOutcome {
  /// Razorpay captured the payment. [OutletCheckoutResult.verified] says
  /// whether the server also confirmed the signature.
  paid,

  /// The customer dismissed the sheet — nothing was charged.
  cancelled,

  /// The gateway (or the call that opens it) reported an error.
  failed,

  /// The customer left for an external wallet app; the payment settles there
  /// and the server reconciles it. Neither a success nor a failure yet.
  externalWallet,

  /// On-device checkout isn't available on this platform (Flutter web).
  unavailable,
}

/// The result of one checkout attempt — what the caller shows and acts on.
class OutletCheckoutResult {
  const OutletCheckoutResult({
    required this.outcome,
    required this.message,
    this.verified = false,
    this.paymentId,
    this.razorpayOrderId,
    this.signature,
  });

  final OutletCheckoutOutcome outcome;

  /// Ready-to-show text for a snackbar/dialog.
  final String message;

  /// True only when the SERVER recomputed and accepted the signature.
  final bool verified;

  /// Razorpay's success payload, kept so a caller can log or display it. The
  /// server stores its own copy during verification — this is never the source
  /// of truth for payment state.
  final String? paymentId;
  final String? razorpayOrderId;
  final String? signature;

  /// Razorpay captured the money (verified or awaiting server confirmation).
  bool get isPaid => outcome == OutletCheckoutOutcome.paid;

  /// Nothing was charged and the caller may offer a straight retry on the SAME
  /// order — a new order must never be created for a retry.
  bool get canRetry =>
      outcome == OutletCheckoutOutcome.cancelled ||
      outcome == OutletCheckoutOutcome.failed;
}

/// Runs the outlet role's Razorpay checkout for one order at a time.
///
/// Create one per screen and [dispose] it with the screen. [collect] is
/// re-entrancy safe: a second call while a sheet is open is refused rather than
/// opening a second checkout (the duplicate-tap guard).
class OutletRazorpayCheckout {
  OutletRazorpayCheckout({OutletRepository? repository})
      : _repo = repository ?? OutletRepository();

  final OutletRepository _repo;

  /// The sheet currently open, if any — cleared when the attempt ends.
  Razorpay? _razorpay;
  bool _busy = false;

  /// True while a checkout is in flight (button-disable / duplicate-tap guard).
  bool get isBusy => _busy;

  /// Creates the Razorpay order for [order] on the server, opens the checkout
  /// sheet and — on success — sends the callback back to the server to verify.
  ///
  /// Never throws: every failure comes back as an [OutletCheckoutResult] the
  /// caller can show directly.
  Future<OutletCheckoutResult> collect(OutletOrder order) async {
    if (_busy) {
      return const OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: 'A payment is already in progress.',
      );
    }
    if (kIsWeb) {
      // razorpay_flutter is a mobile-only plugin — the QR / payment link on the
      // Payment screen is the web path (same gateway, customer's own phone).
      return const OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.unavailable,
        message: 'On-device Razorpay checkout is available in the mobile app. '
            'Use the QR or payment link here.',
      );
    }
    if (order.id.isEmpty) {
      return const OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: 'This order has no id yet — reopen it from Orders to collect '
            'payment.',
      );
    }

    // Held for the WHOLE attempt (server call + sheet), so a second tap while
    // the order is being prepared can never open a second checkout.
    _busy = true;
    try {
      return await _run(order);
    } finally {
      _busy = false;
    }
  }

  Future<OutletCheckoutResult> _run(OutletOrder order) async {
    // 1) Server-created Razorpay order (amount + key live there, never here).
    final OutletOnlinePayment pay;
    try {
      pay = await _repo.createRazorpayOrder(order.id);
    } on OutletApiException catch (e) {
      // Carries the server's own reason ("This order is already paid", …).
      return OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: e.message,
      );
    } on TimeoutException {
      return const OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: 'The server took too long to start the payment. Please try '
            'again.',
      );
    } catch (e) {
      debugPrint('[OutletCheckout] createRazorpayOrder failed: $e');
      return const OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: 'Could not start the payment. Check your connection and try '
            'again.',
      );
    }

    if (pay.razorpayOrderId.isEmpty || pay.keyId.isEmpty || pay.amount <= 0) {
      return const OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: 'The payment could not be prepared. Please try again.',
      );
    }

    // 2) Open the sheet and wait for exactly one terminal callback.
    final response = await _open(pay, order);
    if (response is! PaymentSuccessResponse) return _nonSuccess(response);

    // 3) Verify server-side. Reaching here means Razorpay CAPTURED the payment,
    //    so we never re-open the sheet from this point — that would charge the
    //    customer twice. A verification hiccup is reconciled by polling.
    return _verify(order, response);
  }

  /// Opens the checkout sheet, returning the single Razorpay callback that ends
  /// it (success / failure / external wallet).
  Future<Object?> _open(OutletOnlinePayment pay, OutletOrder order) {
    final completer = Completer<Object?>();

    void finish(Object? event) {
      if (!completer.isCompleted) completer.complete(event);
    }

    // Razorpay wants a bare 10-digit number (no spaces / country-code
    // punctuation) — same normalisation as the customer checkout.
    final contact = order.customer.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final options = <String, dynamic>{
      'key': pay.keyId,
      'order_id': pay.razorpayOrderId, // server-created → enables verification
      'amount': pay.amount, // paise, from the server
      'currency': pay.currency,
      'name': 'VS Arogya',
      'description': 'Outlet order ${order.id}',
      if (contact.length >= 10)
        'prefill': <String, dynamic>{
          'contact': contact.substring(contact.length - 10),
        },
      'theme': <String, dynamic>{'color': '#159E76'},
    };

    // razorpay_flutter's open() is `void … async`: a platform-channel failure
    // (plugin missing, host-side crash) escapes as an UNCAUGHT async error and
    // no event is ever emitted — which would leave the caller waiting forever
    // on a spinner. Running the plugin inside a guarded zone turns that into a
    // normal failure result the screen can show and retry.
    runZonedGuarded(
      () {
        final razorpay = Razorpay()
          ..on(Razorpay.EVENT_PAYMENT_SUCCESS, finish)
          ..on(Razorpay.EVENT_PAYMENT_ERROR, finish)
          ..on(Razorpay.EVENT_EXTERNAL_WALLET, finish);
        _razorpay = razorpay;
        razorpay.open(options);
      },
      (e, _) {
        debugPrint('[OutletCheckout] open failed: $e');
        finish(_OpenFailure('Could not open Razorpay: $e'));
      },
    );

    return completer.future.whenComplete(_release);
  }

  /// Tears the sheet down after an attempt so the next one starts clean.
  void _release() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// Maps a non-success callback onto a result. Cancellation is separated from a
  /// real gateway error so the caller can word the retry correctly.
  OutletCheckoutResult _nonSuccess(Object? response) {
    if (response is _OpenFailure) {
      return OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: response.message,
      );
    }
    if (response is ExternalWalletResponse) {
      final wallet = response.walletName ?? 'wallet';
      return OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.externalWallet,
        message: 'Selected wallet: $wallet — the status updates once the '
            'payment is confirmed.',
      );
    }
    if (response is PaymentFailureResponse) {
      final code = response.code;
      debugPrint(
          '[OutletCheckout] error → code=$code message=${response.message}');
      if (code == Razorpay.PAYMENT_CANCELLED) {
        return const OutletCheckoutResult(
          outcome: OutletCheckoutOutcome.cancelled,
          message: 'Payment cancelled.',
        );
      }
      return OutletCheckoutResult(
        outcome: OutletCheckoutOutcome.failed,
        message: 'Payment failed ($code). Please try again.',
      );
    }
    return const OutletCheckoutResult(
      outcome: OutletCheckoutOutcome.failed,
      message: 'Payment could not be completed. Please try again.',
    );
  }

  /// Forwards the captured payment to the server, which recomputes the HMAC and
  /// (only then) marks the order paid.
  Future<OutletCheckoutResult> _verify(
    OutletOrder order,
    PaymentSuccessResponse response,
  ) async {
    final razorpayOrderId = response.orderId ?? '';
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';

    var verified = false;
    try {
      verified = await _repo.verifyPayment(
        orderId: order.id,
        razorpayOrderId: razorpayOrderId,
        paymentId: paymentId,
        signature: signature,
      );
    } catch (e) {
      // The money is captured either way — the server's own reconciliation plus
      // the caller's status poll settle the truth.
      debugPrint('[OutletCheckout] verify failed: $e');
    }

    return OutletCheckoutResult(
      outcome: OutletCheckoutOutcome.paid,
      message: 'Payment received — confirming with the server…',
      verified: verified,
      paymentId: paymentId,
      razorpayOrderId: razorpayOrderId,
      signature: signature,
    );
  }

  /// Releases the native listeners. Safe to call more than once.
  void dispose() => _release();
}

/// A failure raised before the sheet ever reached Razorpay (SDK exception).
class _OpenFailure {
  const _OpenFailure(this.message);
  final String message;
}
