// =============================================================================
// MediCaPlus — Marketing Head · Register Outlet screen
//
// Opened from the "Register Outlet" card on the marketing dashboard. Creates a
// physical outlet on the backend (POST /vsArogya/outlet-register).
//
// The outlet signs in with the mobile number entered here plus the password the
// marketing head sets at the bottom of the form — so both are validated hard
// before submitting. The server requires EVERY field on this form (it answers
// "Missing fields" if any one is blank), which is why nothing here is optional.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart' show showAppSnack;
import 'marketing_api.dart';

class OutletRegistrationScreen extends StatefulWidget {
  const OutletRegistrationScreen({super.key});

  @override
  State<OutletRegistrationScreen> createState() =>
      _OutletRegistrationScreenState();
}

class _OutletRegistrationScreenState extends State<OutletRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = OutletApi();

  final _outletName = TextEditingController();
  final _ownerName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _gst = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    for (final c in [
      _outletName, _ownerName, _mobile, _email, _address, _city,
      _state, _pincode, _gst, _password, _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Register Outlet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _introCard(),
            const SizedBox(height: 16),

            _sectionHeader(Icons.storefront_outlined, 'Outlet Details'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  _field(
                    icon: Icons.store_outlined,
                    hint: 'e.g. VS Arogya Ballari',
                    label: 'Outlet Name',
                    controller: _outletName,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  _gap(),
                  _field(
                    icon: Icons.person_outline,
                    hint: 'e.g. Ravi Kumar',
                    label: 'Owner Name',
                    controller: _ownerName,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionHeader(Icons.contact_phone_outlined, 'Contact'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  _field(
                    icon: Icons.phone_outlined,
                    hint: '10-digit mobile number',
                    label: 'Mobile Number',
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: _mobileNo,
                  ),
                  _gap(),
                  _field(
                    icon: Icons.email_outlined,
                    hint: 'outlet@example.com',
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailAddress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionHeader(Icons.location_on_outlined, 'Address'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  _field(
                    icon: Icons.home_outlined,
                    hint: 'Shop no., street, area',
                    label: 'Full Address',
                    controller: _address,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  _gap(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          icon: Icons.location_city_outlined,
                          hint: 'City',
                          label: 'City',
                          controller: _city,
                          textCapitalization: TextCapitalization.words,
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          icon: Icons.map_outlined,
                          hint: 'State',
                          label: 'State',
                          controller: _state,
                          textCapitalization: TextCapitalization.words,
                          validator: _required,
                        ),
                      ),
                    ],
                  ),
                  _gap(),
                  _field(
                    icon: Icons.pin_drop_outlined,
                    hint: '6-digit pincode',
                    label: 'Pincode',
                    controller: _pincode,
                    keyboardType: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: _pin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionHeader(Icons.receipt_long_outlined, 'Business'),
            const SizedBox(height: 8),
            _card(
              child: _field(
                icon: Icons.badge_outlined,
                hint: '15-character GSTIN',
                label: 'GST Number',
                controller: _gst,
                textCapitalization: TextCapitalization.characters,
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(15),
                  _UpperCaseFormatter(),
                ],
                validator: _gstin,
              ),
            ),
            const SizedBox(height: 16),

            _sectionHeader(Icons.lock_outline, 'Login Credentials'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  _field(
                    icon: Icons.lock_outline,
                    hint: 'At least 6 characters',
                    label: 'Password',
                    controller: _password,
                    obscure: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    validator: _pass,
                  ),
                  _gap(),
                  _field(
                    icon: Icons.lock_reset_outlined,
                    hint: 'Re-enter the password',
                    label: 'Confirm Password',
                    controller: _confirm,
                    obscure: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: _confirmPass,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 15, color: AppColors.greyText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'The outlet signs in with its mobile number and this '
                          'password. Share it with them after registering.',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppColors.greyText.withValues(alpha: 0.95)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _submitButton(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Please fix the highlighted fields', success: false);
      return;
    }

    setState(() => _saving = true);
    final error = await _api.registerOutlet(
      outletName: _outletName.text.trim(),
      ownerName: _ownerName.text.trim(),
      mobileNo: _mobile.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
      gstNumber: _gst.text.trim().toUpperCase(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      showAppSnack(context, error, success: false);
      return;
    }
    showAppSnack(context, '${_outletName.text.trim()} registered');
    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _mobileNo(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(s)) return 'Enter a valid 10-digit number';
    return null;
  }

  String? _emailAddress(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(s)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _pin(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Enter a valid 6-digit pincode';
    return null;
  }

  /// A GSTIN is always 15 alphanumeric characters. Kept to length + charset
  /// rather than the full state/PAN pattern so a legitimate number is never
  /// rejected — the server is the authority.
  String? _gstin(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.length != 15) return 'GST number must be 15 characters';
    return null;
  }

  String? _pass(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length < 6) return 'At least 6 characters';
    return null;
  }

  String? _confirmPass(String? v) {
    if ((v ?? '').isEmpty) return 'Required';
    if (v != _password.text) return 'Passwords do not match';
    return null;
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_business_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Outlet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Register a physical outlet and set its login.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText)),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );

  Widget _gap() => const SizedBox(height: 12);

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Icon(Icons.check_circle_outline),
        label: Text(_saving ? 'Registering…' : 'Register Outlet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _field({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    String? label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: formatters,
      textCapitalization: textCapitalization,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.darkText),
      decoration: _decoration(
        hint: hint,
        label: label,
        prefixIcon: icon,
        suffix: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                  color: AppColors.greyText,
                ),
                tooltip: obscure ? 'Show password' : 'Hide password',
              ),
      ),
    );
  }

  InputDecoration _decoration({
    required String hint,
    String? label,
    IconData? prefixIcon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: hint,
      labelText: label,
      floatingLabelStyle: const TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 19, color: AppColors.greyText),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.pageBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
    );
  }
}

/// Keeps the GSTIN field uppercase as it is typed, so what the user sees is
/// exactly what gets sent.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}