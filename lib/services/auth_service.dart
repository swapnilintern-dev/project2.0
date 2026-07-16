import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import '../agent/agent_auth.dart';
import '../agent/agent_session.dart';

class AuthService {
  /// Shared base URL — see [ApiConfig].
  static String get baseUrl => ApiConfig.baseUrl;

  /// Raw session cookie (`token=...`) captured from the login response's
  /// Set-Cookie header. Resent as the Cookie header on authenticated calls
  /// (e.g. the cart). Null until a successful login.
  ///
  /// WEB CAVEAT: browsers don't expose Set-Cookie to JS and block manually
  /// setting a Cookie header, so this stays null on web — authed calls there
  /// need backend CORS + `SameSite=None; Secure` to work.
  static String? sessionCookie;

  /// JWT captured from the login response BODY (`token`). Sent as
  /// `Authorization: Bearer <token>` on authed calls. Unlike the httpOnly
  /// cookie, this works on web AND mobile, localhost AND production — so it's
  /// the reliable auth path. (Requires the backend to return `token` on login
  /// and to read the Authorization header in isAuthenticated.)
  static String? authToken;

  /// The logged-in user's display name (store / company name, falling back to
  /// the contact person). Populated from the login response when the backend
  /// includes it. Null until then — the UI shows a neutral label, never a fake
  /// company. (Requires the backend login to return `store_name` /
  /// `contact_person_name` for this to be populated.)
  static String? storeName;

  /// The mobile number the user signed in with. This is REAL, known
  /// client-side without any backend change, so screens can show the user's
  /// actual phone instead of a hardcoded placeholder.
  static String? phone;

  /// The account's role from the login response ("admin", "marketing head",
  /// "delivery", …). Saved so a restored session can route to the right portal.
  static String? role;

  // ---------------------------------------------------------------------------
  // SESSION PERSISTENCE
  //
  // The backend token is valid for 1 DAY (server: userController.login signs
  // the JWT with expiresIn "1d"). Before this, the token lived only in memory,
  // so closing the app logged the user out. Now the session is saved on-device
  // (shared_preferences) and restored at app start — the user stays signed in
  // until the token actually expires or they tap Logout.
  // ---------------------------------------------------------------------------

  static const _kToken = 'session_token';
  static const _kCookie = 'session_cookie';
  static const _kStoreName = 'session_store_name';
  static const _kPhone = 'session_phone';
  static const _kRole = 'session_role';
  static const _kSavedAt = 'session_saved_at';

  /// How long a saved session is trusted. Slightly less than the server's
  /// 1-day token so the app never starts with an about-to-expire session.
  static const Duration _sessionLife = Duration(hours: 23);

  static Future<Map<String, dynamic>> login({
    required String mobileNo,
    required String password,
  }) async {
    // The mobile number is real, user-provided data — remember it for the UI.
    phone = mobileNo.trim();

    // Area Agent DEMO login (backend "agent" role not live yet — see
    // lib/agent/agent_auth.dart). Short-circuits to a fake success with
    // role "agent" WITHOUT hitting the API, so the sign-in screen's existing
    // homeForRole() routing lands on the Agent portal. This keeps the sign-in
    // screen untouched. Remove this block once the server returns role: "agent".
    if (matchesAgentDemoLogin(mobileNo.trim(), password)) {
      role = 'agent';
      storeName = kAgentDemoName;
      AgentSession.instance.signIn(
        name: kAgentDemoName,
        pincode: kAgentDemoPincode,
      );
      return {'success': true, 'role': 'agent'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/vsArogya/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mobile_no': mobileNo,
        'password': password,
      }),
    );

    // Capture the JWT cookie so later authed calls (cart) can resend it (mobile).
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      sessionCookie = setCookie.split(';').first; // -> "token=<jwt>"
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // Token-based auth — the reliable path on web + mobile (see [authToken]).
    if (body['token'] is String && (body['token'] as String).isNotEmpty) {
      authToken = body['token'] as String;
    }
    // Capture the display name if the backend sends one (store or contact
    // person). Stays null otherwise so the UI never shows a fabricated name.
    final name = body['store_name'] ?? body['contact_person_name'] ?? body['name'];
    if (name is String && name.trim().isNotEmpty) {
      storeName = name.trim();
    }
    if (body['role'] is String) {
      role = body['role'] as String;
    }

    // Successful login → save the session on-device so it survives app
    // restarts (fire-and-forget; login never fails because of storage).
    if (body['success'] == true && (authToken != null || sessionCookie != null)) {
      _saveSession();
    }
    return body;
  }

  /// Writes the current session to device storage.
  static Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, authToken ?? '');
      await prefs.setString(_kCookie, sessionCookie ?? '');
      await prefs.setString(_kStoreName, storeName ?? '');
      await prefs.setString(_kPhone, phone ?? '');
      await prefs.setString(_kRole, role ?? '');
      await prefs.setInt(_kSavedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Storage unavailable — the session simply won't survive a restart.
    }
  }

  /// Loads the saved session at app start. Returns true when a still-valid
  /// session was restored (the splash screen then skips the sign-in screen).
  /// A session older than [_sessionLife] is discarded — the server token has
  /// expired by then, so keeping it would only produce 401s.
  static Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken) ?? '';
      final cookie = prefs.getString(_kCookie) ?? '';
      if (token.isEmpty && cookie.isEmpty) return false;

      final savedAt = prefs.getInt(_kSavedAt) ?? 0;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(savedAt));
      if (age > _sessionLife || age.isNegative) {
        await _clearSaved(prefs); // expired — force a fresh login
        return false;
      }

      authToken = token.isEmpty ? null : token;
      sessionCookie = cookie.isEmpty ? null : cookie;
      final name = prefs.getString(_kStoreName) ?? '';
      storeName = name.isEmpty ? null : name;
      final ph = prefs.getString(_kPhone) ?? '';
      phone = ph.isEmpty ? null : ph;
      final r = prefs.getString(_kRole) ?? '';
      role = r.isEmpty ? null : r;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears the captured session (memory + device storage). Call on logout.
  static void clearSession() {
    sessionCookie = null;
    authToken = null;
    storeName = null;
    phone = null;
    role = null;
    // Also drop the saved copy so the next app start asks for a login.
    SharedPreferences.getInstance().then(_clearSaved).catchError((_) {});
  }

  static Future<void> _clearSaved(SharedPreferences prefs) async {
    for (final k in [_kToken, _kCookie, _kStoreName, _kPhone, _kRole, _kSavedAt]) {
      await prefs.remove(k);
    }
  }
}
