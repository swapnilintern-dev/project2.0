// =============================================================================
// VS Arogya — account self-service
//
//   DELETE /vsArogya/vendor-delete   → permanently deletes the signed-in account
//
// ─── WHAT THE SERVER ACTUALLY DOES ───────────────────────────────────────────
// It calls Vendor.findByIdAndDelete(req.id) straight away. There is NO request
// queue and NO admin review step: the moment this returns success the account
// row is gone from MongoDB and cannot be recovered.
//
// That matters for the UI, which previously described this as submitting a
// "request" for an admin to approve. The screens now say what really happens —
// promising a reviewable request while the server deletes immediately would be
// the worst possible mismatch on an irreversible action.
//
// Scoped by the JWT (`req.id`), so an account can only ever delete ITSELF.
//
// NEVER THROWS — failures come back as a typed result with a user-safe message.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class AccountDeletionResult {
  const AccountDeletionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class AccountApi {
  const AccountApi();

  static const Duration _timeout = Duration(seconds: 45);

  /// Exposed so the PasswordApi extension below can reuse it.
  static Duration get timeout => _timeout;

  /// Permanently deletes the signed-in account.
  ///
  /// [reason] is sent for the server's benefit; the current controller does not
  /// store it, but it costs nothing to pass and means the field is already
  /// there if the server starts recording it.
  Future<AccountDeletionResult> deleteMyAccount({String reason = ''}) async {
    final token = AuthService.authToken;
    if (token == null || token.isEmpty) {
      return const AccountDeletionResult(
        success: false,
        message: 'Your session has expired. Please sign in again.',
      );
    }

    final client = http.Client();
    http.Response response;
    try {
      response = await client
          .delete(
            Uri.parse(ApiConfig.deleteAccount),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              if (AuthService.sessionCookie != null)
                'Cookie': AuthService.sessionCookie!,
            },
            // The controller reads req.body, so send one.
            body: jsonEncode({'confirm': true, 'reason': reason}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const AccountDeletionResult(
        success: false,
        message: 'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      return const AccountDeletionResult(
        success: false,
        message:
            'Cannot reach the server. Check your internet connection and try again.',
      );
    } finally {
      client.close();
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const AccountDeletionResult(
          success: false,
          message: 'The server sent an unexpected response. Please try again.',
        );
      }
      body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const AccountDeletionResult(
        success: false,
        message: 'The server sent an unexpected response. Please try again.',
      );
    }

    // The controller spells the key "succes" on both of its success paths and
    // "success" on its failure paths, so neither alone is reliable. Accept
    // either, and fall back to the HTTP status — getting this wrong would tell
    // a user their account survived when it did not.
    final flag = body['success'] ?? body['succes'];
    final ok = flag == true ||
        (flag == null && response.statusCode >= 200 && response.statusCode < 300);

    // "Vendor not found" comes back as HTTP 200 with success:false. The account
    // is already gone either way, so treat it as done rather than leaving the
    // user staring at an error they cannot act on.
    final message = (body['message'] ?? '').toString();
    if (!ok && message.toLowerCase().contains('not found')) {
      return const AccountDeletionResult(
        success: true,
        message: 'Account deleted.',
      );
    }

    return AccountDeletionResult(
      success: ok,
      message: message.isEmpty
          ? (ok ? 'Account deleted.' : 'Could not delete the account.')
          : message,
    );
  }
}

/// The floor the SERVER enforces (userController.MIN_PASSWORD_LENGTH).
///
/// Deliberately NOT named kMinPasswordLength — auth_widgets.dart already owns
/// that name with a stricter value (8), which is what the password FIELDS
/// validate against. This one exists only so the API layer can reject an
/// obviously-too-short value before spending a round trip.
const int kServerMinPasswordLength = 6;

class PasswordResult {
  const PasswordResult({required this.success, required this.message});

  final bool success;
  final String message;
}

extension PasswordApi on AccountApi {
  /// Sets a new password for the signed-in account.
  ///
  /// [currentPassword] is sent only by the Change Password screen, where the
  /// user is already signed in and must prove they know the old one. The
  /// Forgot Password flow omits it: by that point the user has already proved
  /// they control the account's email address via the OTP step, and has no old
  /// password to supply.
  ///
  /// NEVER THROWS.
  Future<PasswordResult> updatePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    final token = AuthService.authToken;
    if (token == null || token.isEmpty) {
      return const PasswordResult(
        success: false,
        message: 'Your session has expired. Please start again.',
      );
    }

    if (newPassword.length < kServerMinPasswordLength) {
      return const PasswordResult(
        success: false,
        message:
            'Password must be at least $kServerMinPasswordLength characters',
      );
    }

    final client = http.Client();
    http.Response response;
    try {
      response = await client
          .put(
            Uri.parse(ApiConfig.updatePassword),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              if (AuthService.sessionCookie != null)
                'Cookie': AuthService.sessionCookie!,
            },
            body: jsonEncode({
              'newPassword': newPassword,
              // The ? drops the entry entirely when null. That matters: the
              // server treats a MISSING currentPassword as the OTP-verified
              // flow, and an explicit null would not read the same.
              'currentPassword': ?currentPassword,
            }),
          )
          .timeout(AccountApi.timeout);
    } on TimeoutException {
      return const PasswordResult(
        success: false,
        message: 'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      return const PasswordResult(
        success: false,
        message:
            'Cannot reach the server. Check your internet connection and try again.',
      );
    } finally {
      client.close();
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const PasswordResult(
          success: false,
          message: 'The server sent an unexpected response. Please try again.',
        );
      }
      final body = Map<String, dynamic>.from(decoded);
      return PasswordResult(
        success: body['success'] == true,
        message: (body['message'] ?? '').toString().isEmpty
            ? (body['success'] == true
                ? 'Password updated'
                : 'Could not update your password')
            : body['message'].toString(),
      );
    } catch (_) {
      return const PasswordResult(
        success: false,
        message: 'The server sent an unexpected response. Please try again.',
      );
    }
  }
}
