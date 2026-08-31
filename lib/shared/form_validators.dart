// =============================================================================
// VS Arogya — Shared Form Validators
//
// The canonical validation rules used by BOTH the Vendor Registration screen
// and the Outlet Billing customer form (and any future form). Extracted here so
// the rules live in ONE place — the exact same messages and logic the vendor
// registration screen has always used, so behaviour is unchanged.
// =============================================================================

/// Field-level validators for `TextFormField.validator`. Every rule mirrors the
/// original inline logic from `vendor_registration_screen.dart` verbatim.
class FormValidators {
  FormValidators._();

  /// "`field` is required" when empty. Returns a validator bound to [field].
  static String? Function(String?) required(String field) =>
      (v) => (v == null || v.trim().isEmpty) ? '$field is required' : null;

  /// A 10-digit mobile number (digits are enforced by the field's formatter).
  static String? mobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    if (v.trim().length != 10) return 'Enter a valid 10-digit number';
    return null;
  }

  /// A syntactically valid email address.
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok =
        RegExp(r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email';
  }

  /// A 6-digit Indian pin code.
  static String? pincode(String? v) {
    if (v == null || v.trim().isEmpty) return 'Pin Code is required';
    if (v.trim().length != 6) return 'Enter a valid 6-digit pin';
    return null;
  }

  /// A 15-character GSTIN.
  static String? gstin(String? v) {
    if (v == null || v.trim().isEmpty) return 'GSTIN is required';
    if (v.trim().length != 15) return 'GSTIN must be 15 characters';
    return null;
  }
}
