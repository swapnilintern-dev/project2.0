// =============================================================================
// MediCaPlus — Privacy & Security (Vendor + Delivery Partner)
//
// Reached from Profile → Settings → Privacy & Security. Hosts the account-data
// controls, including the Play-Store-required Delete Account entry. Admin and
// Marketing roles never link here.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../auth/change_password_screen.dart';
import 'account_deletion_controller.dart';
import 'delete_account_screen.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({
    super.key,
    required this.role,
    required this.userName,
    this.contact = '',
  });

  final DeletionRole role;
  final String userName;
  final String contact;

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.darkGreen,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('Privacy & Security',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _group([
            _Row(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your login password',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen()),
              ),
            ),
            _Row(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we use and protect your data',
              onTap: () => _snack(context, 'Opening privacy policy'),
            ),
          ]),
          const SizedBox(height: 8),
          // Destructive zone — visually separated.
          _group([
            _Row(
              icon: Icons.delete_outline,
              title: 'Delete Account',
              subtitle: 'Request permanent account deletion',
              destructive: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeleteAccountScreen(
                    role: role,
                    userName: userName,
                    contact: contact,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _group(List<_Row> rows) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i != rows.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 56),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppColors.error : AppColors.darkGreen;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: destructive
              ? AppColors.error.withValues(alpha: 0.10)
              : AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: destructive ? AppColors.error : AppColors.darkText,
        ),
      ),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.greyText),
    );
  }
}
