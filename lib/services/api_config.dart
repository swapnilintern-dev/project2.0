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

  /// Production backend (used when no --dart-define override is supplied).
  static const String _defaultBaseUrl = "http://localhost:3000";

  /// The base URL every service must use.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    return override.isNotEmpty ? override : _defaultBaseUrl;
  }
}
