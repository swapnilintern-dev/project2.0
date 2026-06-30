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

  static Future<Map<String, dynamic>> login({
    required String mobileNo,
    required String password,
  }) async {
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

    // Capture the JWT cookie so later authed calls (cart) can resend it.
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      sessionCookie = setCookie.split(';').first; // -> "token=<jwt>"
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Clears the captured session. Call on logout.
  static void clearSession() => sessionCookie = null;
}