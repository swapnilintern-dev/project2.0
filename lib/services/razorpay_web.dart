// =============================================================================
// Razorpay on the WEB — a thin bridge to Razorpay's official Checkout.js.
//
// The razorpay_flutter plugin is Android/iOS only: on Flutter web its gateway
// never opens. The website therefore opens the same checkout through
// Checkout.js (loaded in web/index.html), with the SAME server-created order
// id, key and amount, and hands back the same three fields the mobile plugin
// does (payment id, order id, signature) — so server-side verification is
// identical on every platform.
//
// Only compiled for the web (see razorpay_web_stub.dart for everything else).
// =============================================================================

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Razorpay')
extension type _RazorpayCheckout._(JSObject _) implements JSObject {
  external factory _RazorpayCheckout(JSObject options);
  external void open();
  external void on(String event, JSFunction handler);
}

/// True when Checkout.js has loaded and the gateway can be opened.
bool get razorpayWebAvailable => globalContext.has('Razorpay');

/// Opens Razorpay Checkout.js with [options] (the same map the mobile plugin
/// takes). Exactly ONE of the callbacks fires per call:
///   • [onSuccess] — payment captured; verify it on the server.
///   • [onFailure] — the user closed the checkout after a failed attempt.
///   • [onDismiss] — the user closed the checkout without paying.
///
/// Returns false (and calls nothing) when Checkout.js is not available.
bool openRazorpayWeb(
  Map<String, dynamic> options, {
  required void Function(String paymentId, String orderId, String signature)
      onSuccess,
  required void Function(String message) onFailure,
  required void Function() onDismiss,
}) {
  if (!razorpayWebAvailable) return false;

  var settled = false;
  // A failed attempt does NOT close Checkout.js — the user can retry inside
  // it. So a failure is only reported if they then close it without paying.
  String? lastFailure;

  final jsOptions = options.jsify()! as JSObject;

  jsOptions['handler'] = ((JSAny? response) {
    if (settled) return;
    settled = true;
    final map = (response.dartify() as Map?) ?? const {};
    onSuccess(
      (map['razorpay_payment_id'] ?? '').toString(),
      (map['razorpay_order_id'] ?? '').toString(),
      (map['razorpay_signature'] ?? '').toString(),
    );
  }).toJS;

  final modal = JSObject();
  modal['ondismiss'] = (() {
    if (settled) return;
    settled = true;
    final failure = lastFailure;
    if (failure != null) {
      onFailure(failure);
    } else {
      onDismiss();
    }
  }).toJS;
  jsOptions['modal'] = modal;

  final checkout = _RazorpayCheckout(jsOptions);
  checkout.on(
    'payment.failed',
    ((JSAny? response) {
      final map = (response.dartify() as Map?) ?? const {};
      final error = map['error'];
      lastFailure = (error is Map ? error['description'] : null)?.toString() ??
          'Payment failed';
    }).toJS,
  );
  checkout.open();
  return true;
}
