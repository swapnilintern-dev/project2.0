// =============================================================================
// VS Arogya — Outlet Staff · Demo Sign-in
//
// The backend does NOT yet issue an "outlet" role, so this file provides a
// LOCAL demo credential that lets you sign in as Outlet Staff and exercise the
// role end-to-end while the API is built.
//
// This is intentionally isolated inside lib/outlet/ so the sign-in screen only
// needs a single one-line hook. When the real backend login returns
// `role: "outlet"`, delete this file and the hook — the keyword route in
// auth/session.dart (`homeForRole` → contains('outlet')) already handles the
// production path, so nothing else changes.
// =============================================================================

/// Demo credentials for the Outlet Staff role (development only).
//
const String kOutletDemoId = '9942694523';
const String kOutletDemoPassword = '000000';

/// True when the entered credentials match the Outlet Staff demo login.
///
/// Matching is trimmed + case-insensitive on the identifier so "Outlet" and
/// "outlet " also work; the password is compared exactly.
bool matchesOutletDemoLogin(String identifier, String password) {
  return identifier.trim().toLowerCase() == kOutletDemoId &&
      password == kOutletDemoPassword;
}
