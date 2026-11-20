// =============================================================================
// MediCaPlus — Forgot Password flow (not logged in)
//
// Reached from the Sign In screen. A single stepped screen:
//   Email Address → OTP Verification (30s resend) → New Password → Success.
// On success the user goes back to the Sign In screen.
//
// OTP send/verify and the "number must exist" check are backend concerns and
// All three steps are LIVE against the backend:
//   POST /vsArogya/eotp          → mails the code
//   POST /vsArogya/eotp-verify   → mints a session, which IS the reset proof
//   PUT  /vsArogya/update-password → sets the new password with that session
//
// Email rather than SMS because mobile OTP needs a DLT registration that is
// still pending; the server's OTP flow is email-based today.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'auth_widgets.dart';
import '../services/otp_auth_service.dart';
import '../services/account_api.dart';
import '../services/auth_service.dart';

enum _Step { mobile, otp, password, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.mobile;

  final _mobileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _mobileCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String _otp = '';
  bool _busy = false;

  // Resend countdown.
  Timer? _resendTimer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _mobileCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AppColors.error : AppColors.darkGreen,
        ),
      );
  }

  /// Partially hides the address in the "code sent to …" line, so a shoulder
  /// surfer can't read the full email off the screen.
  String get _maskedEmail {
    final e = _mobileCtrl.text.trim();
    final at = e.indexOf('@');
    if (at <= 1) return e;
    final name = e.substring(0, at);
    final domain = e.substring(at);
    if (name.length <= 2) return '${name[0]}•••$domain';
    return '${name.substring(0, 2)}${'•' * (name.length - 2)}$domain';
  }

  // --- Step transitions ------------------------------------------------------

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (!(_mobileFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final result =
        await const OtpAuthService().requestOtp(_mobileCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      _snack(result.message, error: true);
      return;
    }

    setState(() {
      _step = _Step.otp;
      _otp = '';
    });
    _startResendTimer();
    // NOTE: the server answers identically whether or not the address is
    // registered, so this is "if that address has an account, a code is on its
    // way" — not a confirmation that one exists.
    _snack('If that address has an account, a code is on its way.');
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _busy) return;
    setState(() => _busy = true);
    final result =
        await const OtpAuthService().requestOtp(_mobileCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.success) _startResendTimer();
    _snack(result.message, error: !result.success);
  }

  /// Verifies the code.
  ///
  /// This is what actually authorises the reset: a correct code mints a real
  /// session token, and the password update below is made with it. There is no
  /// separate "reset token" — proving control of the email IS the proof.
  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      _snack('Enter the 6-digit code', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final result = await const OtpAuthService()
        .verifyOtp(email: _mobileCtrl.text.trim(), code: _otp);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      // Wrong / expired / too many attempts — the server distinguishes them.
      _snack(result.message, error: true);
      return;
    }

    setState(() => _step = _Step.password);
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    // No currentPassword: the OTP step above already proved this user controls
    // the account, and someone who has forgotten their password cannot supply
    // the old one.
    final result = await const AccountApi()
        .updatePassword(newPassword: _newPassCtrl.text);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      _snack(result.message, error: true);
      return;
    }

    // The OTP sign-in left a live session behind. Clear it so the user has to
    // sign in with the NEW password — landing them inside the app on a session
    // minted by a password-reset flow would be a surprise, and would skip the
    // one check that confirms the new password actually works.
    AuthService.clearSession();

    setState(() => _step = _Step.success);
    _resendTimer?.cancel();
  }

  void _onBack() {
    switch (_step) {
      case _Step.mobile:
      case _Step.success:
        Navigator.of(context).maybePop();
      case _Step.otp:
        setState(() => _step = _Step.mobile);
      case _Step.password:
        setState(() => _step = _Step.otp);
    }
  }

  void _backToLogin() => Navigator.of(context).popUntil((r) => r.isFirst);

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Success has its own full-screen layout (no app bar).
    if (_step == _Step.success) return _successScreen();

    return PopScope(
      canPop: _step == _Step.mobile,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.darkText,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: _onBack,
            tooltip: 'Back',
          ),
          title: const Text('Forgot Password',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              _stepHero(),
              const SizedBox(height: 24),
              switch (_step) {
                _Step.mobile => _mobileStep(),
                _Step.otp => _otpStep(),
                _Step.password => _passwordStep(),
                _Step.success => const SizedBox.shrink(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepHero() {
    final (icon, title, subtitle) = switch (_step) {
      _Step.mobile => (
          Icons.lock_reset_rounded,
          'Reset your password',
          'Enter your registered email address and we’ll send you a one-time '
              'code to verify it’s you.',
        ),
      _Step.otp => (
          Icons.sms_outlined,
          'Verify OTP',
          'Enter the 6-digit code sent to $_maskedEmail.',
        ),
      _Step.password => (
          Icons.password_rounded,
          'Create a new password',
          'Choose a strong password you haven’t used before.',
        ),
      _Step.success => (Icons.check, '', ''),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.lightGreenBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.darkGreen, size: 28),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.greyText, height: 1.45)),
      ],
    );
  }

  // --- Step 1: Mobile --------------------------------------------------------

  Widget _mobileStep() {
    return Form(
      key: _mobileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Email Address',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14, color: AppColors.darkText),
            decoration: _fieldDecoration(
              hint: 'you@pharmacy.com',
              icon: Icons.alternate_email_outlined,
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Email address is required';
              if (!OtpAuthService.isValidEmail(t)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          AuthPrimaryButton(
            label: 'Send OTP',
            loading: _busy,
            onPressed: _busy ? null : _sendOtp,
          ),
        ],
      ),
    );
  }

  // --- Step 2: OTP -----------------------------------------------------------

  Widget _otpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OtpInput(onChanged: (v) => _otp = v),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text("Didn't get the code? ",
                style: TextStyle(fontSize: 13, color: AppColors.greyText)),
            if (_secondsLeft > 0)
              Text('Resend in ${_secondsLeft}s',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greyText))
            else
              GestureDetector(
                onTap: _resendOtp,
                child: const Text('Resend OTP',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: 'Verify',
          loading: _busy,
          onPressed: _busy ? null : _verifyOtp,
        ),
      ],
    );
  }

  // --- Step 3: New password --------------------------------------------------

  Widget _passwordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          PasswordField(
            label: 'New Password',
            controller: _newPassCtrl,
            hint: 'At least $kMinPasswordLength characters',
            validator: validateNewPassword,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          PasswordField(
            label: 'Confirm Password',
            controller: _confirmPassCtrl,
            hint: 'Re-enter new password',
            validator: (v) => validateConfirmPassword(v, _newPassCtrl.text),
            textInputAction: TextInputAction.done,
            onSubmitted: _changePassword,
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: 'Change Password',
            loading: _busy,
            onPressed: _busy ? null : _changePassword,
          ),
        ],
      ),
    );
  }

  // --- Step 4: Success -------------------------------------------------------

  Widget _successScreen() {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.primary, size: 56),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Password Changed Successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.greyText),
              ),
              const SizedBox(height: 32),
              AuthPrimaryButton(label: 'Back To Login', onPressed: _backToLogin),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
      {required String hint, required IconData icon}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
      filled: true,
      fillColor: AppColors.lighterGreen,
      isDense: true,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Icon(icon, color: AppColors.greyText, size: 20),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
    );
  }
}
