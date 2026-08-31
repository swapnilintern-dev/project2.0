// =============================================================================
// MediCaPlus — Marketing Head · Register Agent screen
//
// Opened from the "Register Agent" card on the marketing dashboard. Creates an
// Area Agent on the backend (POST /vsArogya/agent-register).
//
// An agent is assigned ONE pincode and monitors every order delivering to it.
// They sign in on the normal sign-in screen with the mobile number entered here
// plus the password set at the bottom — so both are validated hard before
// submitting. The server needs name, mobile, pincode and password.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart' show showAppSnack;
import 'marketing_api.dart';

class AgentRegistrationScreen extends StatefulWidget {
  const AgentRegistrationScreen({super.key});

  @override
  State<AgentRegistrationScreen> createState() =>
      _AgentRegistrationScreenState();
}

class _AgentRegistrationScreenState extends State<AgentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = MarketingAgentApi();

  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _pincode = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _pincode, _password, _confirm]) {
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
        title: const Text('Register Agent',
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

            _sectionHeader(Icons.badge_outlined, 'Agent Details'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  _field(
                    icon: Icons.person_outline,
                    hint: 'e.g. Ravi Kumar',
                    label: 'Agent Name',
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  _gap(),
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
                    hint: 'agent@example.com',
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailAddress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionHeader(Icons.location_on_outlined, 'Assigned Area'),
            const SizedBox(height: 8),
            _card(
              child: _field(
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
                          'The agent signs in with this mobile number and '
                          'password, and sees every order delivering to the '
                          'assigned pincode. Share it with them after '
                          'registering.',
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
    final error = await _api.registerAgent(
      name: _name.text.trim(),
      mobileNo: _mobile.text.trim(),
      email: _email.text.trim(),
      pincode: _pincode.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      showAppSnack(context, error, success: false);
      return;
    }
    showAppSnack(context, '${_name.text.trim()} registered as agent');
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
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(s)) {
      return 'Enter a valid 10-digit number';
    }
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
            child: const Icon(Icons.person_pin_circle_outlined,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Area Agent',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Assign one pincode and set the agent\'s login.',
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
        label: Text(_saving ? 'Registering…' : 'Register Agent',
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
