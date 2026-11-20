import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
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

  /// The email address the user signed in with.
  ///
  /// Email + OTP is the primary sign-in method (see OtpAuthService); the
  /// password path leaves this null and fills [phone] instead, so screens that
  /// show "you are signed in as …" should fall back from one to the other.
  static String? email;

  /// The buyer's registration type, as the backend stores it ("Shop / Pharmacy"
  /// vs "Hospital / Clinic") together with the finer `shop_type`.
  ///
  /// Kept on the session because the catalogue prices one product three ways and
  /// the rate card is derived from these two values — a restored session that
  /// lost them would silently drop the account back to the retail price.
  static String? vendorType;
  static String? shopType;

  /// The signed-in account's own id, as the backend returns it (`id` on the
  /// login response). Several role-scoped calls need it — the Area Agent's
  /// pincode feed and the per-user notification inbox both key on it.
  static String? userId;

  // ---------------------------------------------------------------------------
  // ADOPTING A LOGIN RESPONSE
  // ---------------------------------------------------------------------------

  /// Captures a successful authentication response into the shared session.
  ///
  /// Both sign-in paths end here — [login] for password, OtpAuthService for
  /// email + OTP — so neither can drift from the other or forget to persist a
  /// field. The backend returns the SAME body shape for both
  /// (server/controller/emailverifyController.js mirrors userController.login
  /// field for field), which is what makes one adopter possible.
  static void adoptAuthResponse(
    Map<String, dynamic> body, {
    String? emailUsed,
    String? phoneUsed,
  }) {
    if (body['token'] is String && (body['token'] as String).isNotEmpty) {
      authToken = body['token'] as String;
    }

    final name =
        body['store_name'] ?? body['contact_person_name'] ?? body['name'];
    if (name is String && name.trim().isNotEmpty) {
      storeName = name.trim();
    }

    if (body['role'] is String) role = body['role'] as String;
    if (body['id'] != null) userId = body['id'].toString();
    if (body['vendor_type'] != null) vendorType = body['vendor_type'].toString();
    if (body['shop_type'] != null) shopType = body['shop_type'].toString();

    // Prefer what the server echoed back; fall back to what the user typed.
    final serverEmail = body['email'];
    if (serverEmail is String && serverEmail.trim().isNotEmpty) {
      email = serverEmail.trim();
    } else if (emailUsed != null && emailUsed.trim().isNotEmpty) {
      email = emailUsed.trim();
    }

    if (phoneUsed != null && phoneUsed.trim().isNotEmpty) {
      phone = phoneUsed.trim();
    }

    _saveSession();
  }

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
  static const _kEmail = 'session_email';
  static const _kUserId = 'session_user_id';
  static const _kVendorType = 'session_vendor_type';
  static const _kShopType = 'session_shop_type';

  /// How long a saved session is trusted. Slightly less than the server's
  /// 1-day token so the app never starts with an about-to-expire session.
  static const Duration _sessionLife = Duration(hours: 23);

  /// How long to wait for the login response. The backend is on Render's free
  /// tier, where the first request after an idle period pays a cold start, so
  /// this is generous — but it is BOUNDED. Without it a dead server left the
  /// user on a spinner forever with no way back.
  static const Duration _loginTimeout = Duration(seconds: 45);

  static const String _unexpectedResponse =
      'The server sent an unexpected response. Please try again in a moment.';

  /// The shape [login] returns when the call never reached a usable response.
  /// `networkError` marks "we could not ask the server", as opposed to "the
  /// server answered and rejected the credentials" — the sign-in screen uses it
  /// to stop retrying the other login collections.
  static Map<String, dynamic> _networkFailure(String message) => {
        'success': false,
        'message': message,
        'networkError': true,
      };

  /// Signs a Vendor-collection account in.
  ///
  /// NEVER THROWS. Every failure — no connectivity, timeout, a 502 HTML error
  /// page from the host, a truncated body — comes back as a map with
  /// `success: false` and a `message` that is safe to show a user. Callers can
  /// therefore render `message` directly; previously a decode failure escaped as
  /// a raw exception and the sign-in screen printed it verbatim.
  ///
  /// [client] is for tests; production passes nothing and gets a fresh client
  /// that is closed before returning.
  static Future<Map<String, dynamic>> login({
    required String mobileNo,
    required String password,
    http.Client? client,
  }) async {
    // The mobile number is real, user-provided data — remember it for the UI.
    phone = mobileNo.trim();

    final httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .post(
            Uri.parse('$baseUrl/vsArogya/login'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'mobile_no': mobileNo,
              'password': password,
            }),
          )
          .timeout(_loginTimeout);
    } on TimeoutException {
      return _networkFailure(
          'The server took too long to respond. Please try again.');
    } catch (_) {
      // Offline, DNS failure, TLS error, connection reset — all indistinguishable
      // to the user, and none of them are worth showing a stack trace for.
      return _networkFailure(
          'Cannot reach the server. Check your internet connection and try again.');
    } finally {
      if (client == null) httpClient.close();
    }

    // Capture the JWT cookie so later authed calls (cart) can resend it (mobile).
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      sessionCookie = setCookie.split(';').first; // -> "token=<jwt>"
    }

    // A gateway timeout or a crashed route answers with HTML, not JSON.
    final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return _networkFailure(_unexpectedResponse);
      body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return _networkFailure(_unexpectedResponse);
    }

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
    // Same two fields the email-OTP path captures via [adoptAuthResponse], so a
    // password session and an OTP session carry identical state. Without this,
    // anything keyed on the account id would work after an OTP login and fail
    // after a password one.
    if (body['id'] != null) userId = body['id'].toString();
    if (body['vendor_type'] != null) vendorType = body['vendor_type'].toString();
    if (body['shop_type'] != null) shopType = body['shop_type'].toString();
    final loginEmail = body['email'];
    if (loginEmail is String && loginEmail.trim().isNotEmpty) {
      email = loginEmail.trim();
    }

    // Area Agent (a Vendor with role "agent") — capture the id + assigned
    // pincode the backend returns so the dashboard can pull its pincode-wise
    // orders live. Populated here so the sign-in screen's homeForRole() routing
    // lands on a LIVE Agent portal (isLive == true) rather than the mock.
    if ((role ?? '').toLowerCase().contains('agent') && body['success'] == true) {
      AgentSession.instance.signIn(
        name: (body['name'] ?? storeName)?.toString(),
        pincode: body['pincode']?.toString(),
        agentId: body['id']?.toString(),
        token: authToken,
      );
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
      await prefs.setString(_kEmail, email ?? '');
      await prefs.setString(_kUserId, userId ?? '');
      await prefs.setString(_kVendorType, vendorType ?? '');
      await prefs.setString(_kShopType, shopType ?? '');
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
      final em = prefs.getString(_kEmail) ?? '';
      email = em.isEmpty ? null : em;
      final uid = prefs.getString(_kUserId) ?? '';
      userId = uid.isEmpty ? null : uid;
      final vt = prefs.getString(_kVendorType) ?? '';
      vendorType = vt.isEmpty ? null : vt;
      final st = prefs.getString(_kShopType) ?? '';
      shopType = st.isEmpty ? null : st;
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
    email = null;
    userId = null;
    vendorType = null;
    shopType = null;
    // Also drop the saved copy so the next app start asks for a login.
    SharedPreferences.getInstance().then(_clearSaved).catchError((_) {});
  }

  static Future<void> _clearSaved(SharedPreferences prefs) async {
    for (final k in [
      _kToken,
      _kCookie,
      _kStoreName,
      _kPhone,
      _kRole,
      _kEmail,
      _kUserId,
      _kVendorType,
      _kShopType,
      _kSavedAt,
    ]) {
      await prefs.remove(k);
    }
  }
}
