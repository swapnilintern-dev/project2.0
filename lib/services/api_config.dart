// =============================================================================
// MediCaPlus — API configuration
//
// SINGLE SOURCE OF TRUTH for the backend base URL. Every API service
// (AuthService, VendorApiService, CustomerApi, …) reads ApiConfig.baseUrl so
// the whole app always talks to the same server.
//
// Override at build/run time without editing code:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
//   - Android emulator → host machine = http://10.0.2.2:3000
//   - iOS sim / desktop → http://localhost:3000
//   - Physical device → your PC's LAN IP
// =============================================================================
class ApiConfig {
  ApiConfig._();

  /// Hosted Render backend (used when no --dart-define override is supplied).
  /// For local testing run with:
  ///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
  static const String _defaultBaseUrl = "https://backend-new-0ady.onrender.com";

  /// The base URL every service must use.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    return override.isNotEmpty ? override : _defaultBaseUrl;
  }

  /// Every route on the server is mounted under this prefix (server/index.js).
  static const String apiPrefix = '/vsArogya';

  /// Absolute URL for an API path, e.g. `api('/eotp')`.
  static String api(String path) => '$baseUrl$apiPrefix$path';

  // ---------------------------------------------------------------------------
  // Email + OTP sign-in  (server/routes/eotpRoute.js)
  //
  // The primary sign-in method. A code is mailed to the address, then exchanged
  // for the SAME authentication body the password login returns.
  // ---------------------------------------------------------------------------

  /// POST { email } → mails a 6-digit code (valid 10 minutes).
  static String get sendEmailOtp => api('/eotp');

  /// POST { email, otp } → { success, token, role, id, name, pincode, … }.
  static String get verifyEmailOtp => api('/eotp-verify');

  // ---------------------------------------------------------------------------
  // Account self-service  (server/routes/userRoute.js)
  // ---------------------------------------------------------------------------

  /// DELETE → permanently removes the signed-in account. No approval step: the
  /// server deletes the row immediately.
  static String get deleteAccount => api('/vendor-delete');

  /// PUT { newPassword, currentPassword? } → sets a new password.
  ///
  /// Used by BOTH password screens. Change Password sends currentPassword;
  /// Forgot Password does not, having already proved ownership via email OTP.
  static String get updatePassword => api('/update-password');

  /// PUT { category, enabled } → per-category notification opt-in/out.
  static String get notificationPreferences => api('/notifications/preferences');

  /// GET → the account's notification settings (categories + push opt-in).
  static String get notificationSettings => api('/notifications/settings');

  // ---------------------------------------------------------------------------
  // Bulk product upload  (server/routes/bulkUploadRoute.js)
  //
  // Marketing/admin only, enforced server-side from the signed JWT.
  // ---------------------------------------------------------------------------

  /// POST multipart `file` (.xlsx/.xls/.csv) → per-row upload result.
  static String get bulkUploadProducts => api('/bulk-upload');

  // ---------------------------------------------------------------------------
  // Per-user notification inbox  (server/routes/notificationRoute.js)
  //
  // Transactional notifications for ONE account (order shipped, payment taken,
  // vendor approved). Separate from the marketing broadcast campaign system,
  // which lives under /notifications/* and is handled by NotificationApi.
  // ---------------------------------------------------------------------------

  /// GET → this account's notifications, newest first.
  static String get myNotifications => api('/get-notification');

  /// GET → { count } of unread notifications.
  static String get unreadNotificationCount => api('/unread-notification');

  /// PATCH → marks ONE notification read.
  static String markNotificationRead(String id) =>
      api('/mark-read-notification/$id');

  /// POST → marks every notification read.
  static String get markAllNotificationsRead => api('/mark-all-read');

  /// POST → creates a notification for an account.
  static String get createNotification => api('/createNotification');

  // ---------------------------------------------------------------------------
  // Outlet Staff role (additive) — endpoint paths.
  //
  // Placeholders for the not-yet-ready backend. The Outlet repository (Step 3)
  // runs against a MOCK datasource for now; these constants are the single
  // source of truth to switch to when the real API lands. Adjust the paths to
  // match the server once it exists — nothing else references literals.
  // ---------------------------------------------------------------------------

  /// Base path for all Outlet Staff endpoints.
  static const String outletBasePath = '/outlet';

  /// Staff's own outlet stock (full) + district stock (read-only).
  static String get outletStock => '$baseUrl$outletBasePath/stock';

  /// Create a manual order (idempotent — client sends an idempotencyKey).
  static String get outletCreateOrder => '$baseUrl$outletBasePath/orders';

  /// List the outlet's orders.
  static String get outletOrders => '$baseUrl$outletBasePath/orders';

  /// A single order's detail / live status. Append `/{orderId}`.
  static String outletOrder(String orderId) =>
      '$baseUrl$outletBasePath/orders/$orderId';

  /// Poll a single order's payment status (server-owned; never set client-side).
  static String outletOrderStatus(String orderId) =>
      '$baseUrl$outletBasePath/orders/$orderId/status';

  /// Create the Razorpay QR / payment link for an order.
  static String outletPayment(String orderId) =>
      '$baseUrl$outletBasePath/orders/$orderId/payment';
}
