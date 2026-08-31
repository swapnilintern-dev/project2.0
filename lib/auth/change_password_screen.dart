// =============================================================================
// MediCaPlus — Change Password (already logged in)
//
// Reached from Profile → Privacy & Security → Change Password. The user is
// already authenticated, so there is NO OTP step — just New Password + Confirm
// Password. Used by both Vendor and Delivery Partner.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'auth_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    // TODO(backend): POST change-password { newPassword } for the logged-in user.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _saving = false);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline,
            color: AppColors.primary, size: 40),
        title: const Text('Password Updated Successfully'),
        content: const Text('Your account password has been changed.'),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('Change Password',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.password_rounded,
                    color: AppColors.darkGreen, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Change your password',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              const SizedBox(height: 6),
              const Text(
                'Choose a new password for your account. You won’t need to '
                'enter an OTP since you’re signed in.',
                style: TextStyle(
                    fontSize: 13.5, color: AppColors.greyText, height: 1.45),
              ),
              const SizedBox(height: 24),
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
                onSubmitted: _submit,
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: 'Update Password',
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
