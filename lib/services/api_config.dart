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
