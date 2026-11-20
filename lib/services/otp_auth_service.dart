// =============================================================================
// VS Arogya — Email + OTP sign-in
//
// The PRIMARY sign-in method. The user types their registered email address, the
// server mails a 6-digit code, and exchanging that code returns the SAME
// authentication body the password login returns — so both paths feed the one
// `_completeSignIn` + `homeForRole` routing on the sign-in screen.
//
//   POST /vsArogya/eotp          { email }        → mails the code
//   POST /vsArogya/eotp-verify   { email, otp }   → { success, token, role, … }
//
// WHY EMAIL AND NOT SMS: mobile OTP needs a completed DLT registration, which
// is still pending. The server's OTP collection and controller are email-based
// today (server/controller/emailverifyController.js). When DLT lands, the mobile
// path can be added alongside without touching the sign-in screen — it only
// talks to this service.
//
// Works for EVERY role. The server looks the address up in the Vendor
// collection (which holds admin / marketing / delivery / agent / buyer) and, if
// it isn't there, in the separate Outlet collection, then signs the matching
// account in with its real role.
//
// NEVER THROWS. Every failure — offline, timeout, a 502 HTML page from the host,
// a truncated body — comes back as `success: false` with a message that is safe
// to show a user, exactly like AuthService.login.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';
import '../agent/agent_session.dart';
import '../delivery/delivery_models.dart' show DeliveryController;
import '../outlet/outlet_session.dart';

/// Outcome of an OTP step. Mirrors the shape the password login already uses
/// (`success` + a user-safe `message`) so the sign-in screen handles both the
/// same way. [body] carries the authentication response on a successful
/// [OtpAuthService.verifyOtp] — the same map the password path produces.
class OtpAuthResult {
  const OtpAuthResult({
    required this.success,
    required this.message,
    this.body,
  });

  final bool success;
  final String message;
  final Map<String, dynamic>? body;
}

class OtpAuthService {
  const OtpAuthService();

  /// Whether OTP sign-in can reach a backend. The endpoints exist now, so this
  /// is true; the sign-in screen keys its "use password instead" notice on it.
  static const bool isAvailable = true;

  /// Shown if [isAvailable] is ever flipped back off.
  static const String unavailableMessage =
      'OTP sign-in is not enabled on the server yet. Please use Password login.';

  /// The host sits on Render's free tier, so the first request after an idle
  /// period pays a cold start. Generous, but BOUNDED — without it a dead server
  /// leaves the user on a spinner with no way back.
  static const Duration _timeout = Duration(seconds: 45);

  static const String _unexpectedResponse =
      'The server sent an unexpected response. Please try again in a moment.';

  static const OtpAuthResult _unavailable = OtpAuthResult(
    success: false,
    message: unavailableMessage,
  );

  /// Basic shape check so an obvious typo is caught before a network round trip.
  /// The server is the real authority on whether the address exists.
  static bool isValidEmail(String value) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim());

  // ---------------------------------------------------------------------------

  /// Asks the backend to email a one-time code to [email].
  ///
  /// NOTE: the server answers the same way whether or not an account exists, so
  /// this endpoint cannot be used to discover which addresses are registered.
  /// A wrong address therefore reports "code sent" and simply never arrives —
  /// that is deliberate, and the verify step is where it actually fails.
  Future<OtpAuthResult> requestOtp(String email) async {
    if (!isAvailable) return _unavailable;

    final address = email.trim().toLowerCase();
    if (address.isEmpty) {
      return const OtpAuthResult(
        success: false,
        message: 'Email address is required',
      );
    }
    if (!isValidEmail(address)) {
      return const OtpAuthResult(
        success: false,
        message: 'Enter a valid email address',
      );
    }

    final client = http.Client();
    http.Response response;
    try {
      response = await client
          .post(
            Uri.parse(ApiConfig.sendEmailOtp),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': address}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const OtpAuthResult(
        success: false,
        message: 'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      return const OtpAuthResult(
        success: false,
        message:
            'Cannot reach the server. Check your internet connection and try again.',
      );
    } finally {
      client.close();
    }

    final body = _decode(response.body);
    if (body == null) {
      return const OtpAuthResult(success: false, message: _unexpectedResponse);
    }

    final ok = body['success'] == true;
    return OtpAuthResult(
      success: ok,
      message: body['message']?.toString() ??
          (ok ? 'OTP sent to your email.' : 'Could not send the OTP.'),
    );
  }

  /// Verifies [code] for [email] and, on success, captures the session so every
  /// authenticated call in the app keeps working.
  ///
  /// Returns the decoded authentication body so the sign-in screen can route on
  /// `role` exactly as it does for the password login.
  Future<OtpAuthResult> verifyOtp({
    required String email,
    required String code,
  }) async {
    if (!isAvailable) return _unavailable;

    final address = email.trim().toLowerCase();
    final otp = code.trim();

    if (address.isEmpty || otp.isEmpty) {
      return const OtpAuthResult(
        success: false,
        message: 'Enter the code sent to your email',
      );
    }

    final client = http.Client();
    http.Response response;
    try {
      response = await client
          .post(
            Uri.parse(ApiConfig.verifyEmailOtp),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': address, 'otp': otp}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const OtpAuthResult(
        success: false,
        message: 'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      return const OtpAuthResult(
        success: false,
        message:
            'Cannot reach the server. Check your internet connection and try again.',
      );
    } finally {
      client.close();
    }

    // Capture the session cookie too. Browsers don't expose Set-Cookie to JS, so
    // this stays null on web — the Bearer token below is the path that works
    // everywhere, which is why it is the one the app relies on.
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      AuthService.sessionCookie = setCookie.split(';').first;
    }

    final body = _decode(response.body);
    if (body == null) {
      return const OtpAuthResult(success: false, message: _unexpectedResponse);
    }

    if (body['success'] != true) {
      return OtpAuthResult(
        success: false,
        // The server distinguishes wrong code / expired / too many attempts /
        // pending approval — show its wording rather than flattening them.
        message: body['message']?.toString() ?? 'Could not verify the code.',
      );
    }

    // One adopter shared with the password login, so the two session shapes can
    // never drift. This also persists the session to disk, which is what lets
    // the splash screen restore it on the next app start.
    AuthService.adoptAuthResponse(body, emailUsed: address);

    // Outlet and Area Agent keep their own in-memory session, and homeForRole()
    // REFUSES to open either portal without it — it bounces back to sign-in.
    // The password path fills these in (AuthService.login for the agent,
    // OutletApi.login for the outlet), so the OTP path has to as well or those
    // two roles would authenticate successfully and then land on the sign-in
    // screen again.
    _adoptRoleSession(body, address);

    return OtpAuthResult(
      success: true,
      message: body['message']?.toString() ?? 'Login successful',
      body: body,
    );
  }

  // ---------------------------------------------------------------------------

  /// Populates the per-role in-memory sessions that `homeForRole` guards on.
  ///
  /// Mirrors what the password path already does for each role, so an OTP
  /// sign-in lands in exactly the same place:
  ///   • outlet   → OutletSession (OutletApi.login does this)
  ///   • agent    → AgentSession (AuthService.login does this)
  ///   • delivery → DeliveryController (homeForRole does this itself, but it
  ///                needs the mobile/name, which only the response carries)
  static void _adoptRoleSession(Map<String, dynamic> body, String address) {
    final role = (body['role'] ?? '').toString().toLowerCase();
    final id = body['id']?.toString();
    final name = (body['name'] ?? AuthService.storeName)?.toString();

    if (role.contains('outlet')) {
      // The server returns the full outlet document alongside the flat fields.
      final outlet = body['outlet'];
      final doc = outlet is Map ? Map<String, dynamic>.from(outlet) : const {};

      OutletSession.instance.signIn(
        name: (doc['ownerName'] ?? name)?.toString(),
        outlet: (doc['outletName'] ?? name)?.toString(),
        district: (doc['city'] ?? '')?.toString(),
        // isLive keys on this id — every outlet-scoped call is built from it.
        outletId: (doc['_id'] ?? id)?.toString(),
        token: AuthService.authToken,
        cookie: AuthService.sessionCookie,
      );
      // The outlet's own phone, not the email that was typed.
      final mobile = doc['mobileNo']?.toString();
      if (mobile != null && mobile.isNotEmpty) AuthService.phone = mobile;
      return;
    }

    // Checked AFTER delivery below would be wrong here: the server sends the
    // exact role string, so "delivery" and "agent" can be told apart directly
    // rather than by substring order.
    if (role == 'agent' || (role.contains('agent') && !role.contains('delivery'))) {
      AgentSession.instance.signIn(
        name: name,
        pincode: body['pincode']?.toString(),
        agentId: id,
        token: AuthService.authToken,
      );
      return;
    }

    if (role.contains('delivery')) {
      DeliveryController.instance.setAgent(
        mobile: AuthService.phone ?? address,
        name: name,
        token: AuthService.authToken,
      );
    }
  }

  /// A gateway timeout or a crashed route answers with HTML, not JSON. Returns
  /// null when the payload isn't a JSON object so callers can report it as an
  /// unexpected response instead of throwing.
  static Map<String, dynamic>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
}
