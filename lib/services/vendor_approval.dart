// =============================================================================
// VS Arogya — Vendor approval state (a FRONTEND VIEW of a BACKEND value)
//
// The vendor document in MongoDB already carries an `approvalStatus` field with
// the values "Pending" / "Approved" / "Rejected" — the Admin portal reads it
// today (see AdminApi._statusFrom in lib/admin/admin_api.dart) and flips it via
// PUT /vsArogya/approval-mail/:id. This class is the *client-side mirror* of
// that single field so the shopping UI can hide or show distributor prices.
//
// WHAT THIS IS NOT
//   • It is NOT an approval mechanism. The app can never approve, reject or
//     change a vendor's status — that is the Admin portal + backend, and this
//     class has no method that writes anything to the server.
//   • It is NOT a source of truth. It only remembers what the server last told
//     us, and price visibility enforced here is presentational only. Real price
//     protection has to be done server-side (the backend must stop sending the
//     price to an unapproved vendor) — that is future backend work.
//
// ─── WHERE THE FUTURE BACKEND VALUE PLUGS IN ─────────────────────────────────
// [adoptFromAuthResponse] is the ONE seam. Feed it the login response body; the
// moment the backend starts returning `approvalStatus` on POST
// /vsArogya/login, every screen below starts reacting to the real value with no
// further change. Until then the field is simply absent and the status stays
// [VendorApprovalStatus.unknown] — see [treatUnknownAsApproved] for exactly
// what that means today and why.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four vendor states the UI is built around, plus [unknown] for "the
/// server has not told us".
enum VendorApprovalStatus {
  /// The login response carried no approval field at all — we genuinely do not
  /// know. See [VendorApproval.treatUnknownAsApproved].
  unknown,

  /// No vendor registration exists for this account yet.
  notRegistered,

  /// Submitted, waiting for the admin's decision (backend "Pending").
  pending,

  /// The admin rejected the registration (backend "Rejected").
  rejected,

  /// The admin approved the vendor (backend "Approved").
  approved,
}

/// Live vendor-approval state for the signed-in account.
///
/// A [ChangeNotifier] singleton, matching the pattern the customer app already
/// uses for shared state (CartController.instance, WishlistController.instance),
/// so screens observe it with `ListenableBuilder`.
class VendorApproval extends ChangeNotifier {
  VendorApproval._();

  static final VendorApproval instance = VendorApproval._();

  VendorApprovalStatus _status = VendorApprovalStatus.unknown;
  String? _rejectionReason;

  VendorApprovalStatus get status => _status;

  /// The admin's reason for a rejection, when the backend supplies one. Null
  /// otherwise — the UI then shows a neutral message rather than inventing one.
  String? get rejectionReason => _rejectionReason;

  // ---------------------------------------------------------------------------
  // PRICE VISIBILITY
  // ---------------------------------------------------------------------------

  /// How an ABSENT backend approval value is treated.
  ///
  /// FAIL CLOSED: prices are for approved vendors only, so "the server said
  /// nothing" must never unlock them. Email-OTP sign-in admits guests and
  /// pending / rejected vendors, and a backend build that doesn't send
  /// `approvalStatus` (e.g. an older deploy) would otherwise show them every
  /// price. Both current login routes send the field for approved vendors.
  static const bool treatUnknownAsApproved = false;

  /// Whether distributor prices may be shown to the signed-in vendor.
  ///
  /// PRESENTATIONAL ONLY — see the header note. The backend must still refuse
  /// to send prices to an unapproved vendor.
  bool get canSeePrices =>
      _status == VendorApprovalStatus.approved ||
      (_status == VendorApprovalStatus.unknown && treatUnknownAsApproved);

  // ---------------------------------------------------------------------------
  // READING THE BACKEND VALUE  ← the seam
  // ---------------------------------------------------------------------------

  /// Adopts the approval state from an authentication response body.
  ///
  /// Call this with the map returned by the existing `AuthService.login` (and,
  /// later, by the OTP verify call) right after a successful sign-in. Unknown /
  /// missing keys leave the status at [VendorApprovalStatus.unknown], so this
  /// is safe to call against today's response, which does not include the
  /// field yet.
  void adoptFromAuthResponse(Map<String, dynamic>? body) {
    if (body == null) {
      _set(VendorApprovalStatus.unknown, null);
      return;
    }

    // The backend's own spelling is `approvalStatus`; the snake_case variant is
    // accepted too so a future serializer change doesn't silently blank this.
    final raw = (body['approvalStatus'] ?? body['approval_status'])?.toString();

    // A reason is optional — the current backend does not send one.
    final reason =
        (body['rejectionReason'] ?? body['rejection_reason'] ?? body['remark'])
            ?.toString();

    _set(statusFromBackend(raw), reason);
    _save();
  }

  /// Maps the backend's `approvalStatus` string onto [VendorApprovalStatus].
  ///
  /// Mirrors AdminApi's mapping ("Approved" / "Rejected" / anything else →
  /// pending) so the vendor app and the admin portal never disagree about what
  /// a stored value means. `null` / empty → [VendorApprovalStatus.unknown].
  static VendorApprovalStatus statusFromBackend(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return VendorApprovalStatus.unknown;
    return switch (value.toLowerCase()) {
      'approved' => VendorApprovalStatus.approved,
      'rejected' => VendorApprovalStatus.rejected,
      'pending' => VendorApprovalStatus.pending,
      'not registered' || 'none' => VendorApprovalStatus.notRegistered,
      _ => VendorApprovalStatus.pending,
    };
  }

  /// Records that THIS DEVICE just submitted a registration, so the vendor sees
  /// "under review" instead of being asked to register again on the way back.
  ///
  /// This is optimistic UI only — it claims nothing about the server's decision
  /// and is overwritten by [adoptFromAuthResponse] at the next sign-in. Never
  /// use it to move a vendor towards `approved`; only the backend does that.
  void markSubmittedLocally() {
    _set(VendorApprovalStatus.pending, null);
    _save();
  }

  void _set(VendorApprovalStatus status, String? reason) {
    if (_status == status && _rejectionReason == reason) return;
    _status = status;
    _rejectionReason = reason;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE
  //
  // The saved login session survives an app restart (AuthService.restoreSession)
  // and is restored without a network call, so the approval state has to
  // survive with it — otherwise a restored approved vendor would come back as
  // "unknown". Kept in this class's own keys so the auth session code is
  // untouched.
  // ---------------------------------------------------------------------------

  static const _kStatus = 'vendor_approval_status';
  static const _kReason = 'vendor_approval_reason';

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStatus, _status.name);
      await prefs.setString(_kReason, _rejectionReason ?? '');
    } catch (_) {
      // Storage unavailable — the state simply won't survive a restart.
    }
  }

  /// Restores the last known status. Called from the splash screen alongside
  /// `AuthService.restoreSession()`.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kStatus) ?? '';
      if (saved.isEmpty) return;
      final reason = prefs.getString(_kReason) ?? '';
      _set(
        VendorApprovalStatus.values.firstWhere(
          (s) => s.name == saved,
          orElse: () => VendorApprovalStatus.unknown,
        ),
        reason.isEmpty ? null : reason,
      );
    } catch (_) {
      // Leave the status at unknown.
    }
  }

  /// Clears the state on logout so it never leaks into the next account.
  void clear() {
    _set(VendorApprovalStatus.unknown, null);
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.remove(_kStatus);
      await prefs.remove(_kReason);
    }).catchError((_) {});
  }
}
