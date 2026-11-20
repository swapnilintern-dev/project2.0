// Non-web builds use the razorpay_flutter plugin; the Checkout.js bridge in
// razorpay_web.dart does not exist there. These stubs keep the shared checkout
// code compiling and are never called (callers check kIsWeb first).

bool get razorpayWebAvailable => false;

bool openRazorpayWeb(
  Map<String, dynamic> options, {
  required void Function(String paymentId, String orderId, String signature)
      onSuccess,
  required void Function(String message) onFailure,
  required void Function() onDismiss,
}) =>
    false;
