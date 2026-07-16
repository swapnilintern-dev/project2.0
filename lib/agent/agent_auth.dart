// =============================================================================
// VS Arogya — Area Agent · Demo Sign-in
//
// The backend does NOT yet issue an "agent" role, so this file provides a LOCAL
// demo credential that lets you sign in as an Area Agent and exercise the role
// end-to-end while the API is built.
//
// Isolated inside lib/agent/ (mirrors lib/outlet/outlet_auth.dart) so the login
// path only needs a single one-line hook. Because the sign-in SCREEN must not be
// touched, the hook lives in AuthService.login (services/auth_service.dart):
// when these creds match it short-circuits to a fake success with role "agent",
// and the screen's existing homeForRole() routing takes it to the Agent portal.
//
// When the real backend login returns role: "agent", delete this file + the
// AuthService hook — the keyword route in auth/session.dart (`homeForRole` →
// contains('agent')) already handles the production path.
// =============================================================================

/// Demo credentials for the Area Agent role (development only).
const String kAgentDemoId = '9000000000';
const String kAgentDemoPassword = 'agent123';

/// Demo identity shown on the agent dashboard until the backend supplies real
/// agent details (name + assigned pincode).
const String kAgentDemoName = 'Area Agent';
const String kAgentDemoPincode = '411001';

/// True when the entered credentials match the Area Agent demo login.
///
/// Matching is trimmed + case-insensitive on the identifier; the password is
/// compared exactly.
bool matchesAgentDemoLogin(String identifier, String password) {
  return identifier.trim().toLowerCase() == kAgentDemoId &&
      password == kAgentDemoPassword;
}
