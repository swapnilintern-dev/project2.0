# =============================================================================
# VS Arogya — R8 / ProGuard keep rules
#
# NOT APPLIED YET. `isMinifyEnabled` is false in app/build.gradle.kts, because
# shrinking can only be validated by running a real payment on a device. These
# are the rules to switch on with it, so the work is already done when someone
# does that testing.
# =============================================================================

# --- Razorpay checkout ------------------------------------------------------
# The SDK drives its WebView checkout through @JavascriptInterface methods and
# reflectively invoked onPayment* callbacks. R8 sees no caller for either and
# removes them, which fails only at runtime, mid-payment.
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclasseswithmembers class * {
    public void onPayment*(...);
}
-optimizations !method/inlining/*

# --- Google Pay / UPI intent surfaced by Razorpay ---------------------------
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.** { *; }
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**
