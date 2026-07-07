import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';

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

  static Future<Map<String, dynamic>> login({
    required String mobileNo,
    required String password,
  }) async {
    // The mobile number is real, user-provided data — remember it for the UI.
    phone = mobileNo.trim();
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
    return body;
  }

  /// Clears the captured session. Call on logout.
  static void clearSession() {
    sessionCookie = null;
    authToken = null;
    storeName = null;
    phone = null;
  }
}