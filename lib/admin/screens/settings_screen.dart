// =============================================================================
// MediCaPlus — Admin · Settings (tab 4)
//
// Platform-operator settings. A profile header, a PLATFORM group (commission,
// delivery zones, verification rules), an OPERATIONS group (delivery agents →
// the console, notifications, admin roles, audit logs) and Sign Out.
// =============================================================================

import 'package:flutter/material.dart';

import '../../sign_in_screen.dart';
import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_main.dart';
import 'analytics_screen.dart';
import 'delivery_management_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: adminScroll,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const AdminScreenHeader(title: 'Settings'),
            _profile(),
            const SizedBox(height: 22),
            const AdminGroupLabel('Platform'),
            _Group(items: [
              _Item(
                icon: Icons.percent_rounded,
                label: 'Commission & Fees',
                trailing: '8.5% take rate',
                onTap: () => adminSnack(context, 'Commission & Fees'),
              ),
              _Item(
                icon: Icons.map_outlined,
                label: 'Delivery Zones',
                trailing: '24 active cities',
                onTap: () => adminSnack(context, 'Delivery Zones'),
              ),
              _Item(
                icon: Icons.verified_user_outlined,
                label: 'Verification Rules',
                trailing: '3 mandatory docs',
                onTap: () => adminSnack(context, 'Verification Rules'),
              ),
              _Item(
                icon: Icons.insights_outlined,
                label: 'Analytics & Reports',
                onTap: () => adminPush(context, const AdminAnalyticsScreen()),
              ),
            ]),
            const SizedBox(height: 18),
            const AdminGroupLabel('Operations'),
            _Group(items: [
              _Item(
                icon: Icons.delivery_dining_outlined,
                label: 'Delivery Agents',
                trailing: '128 agents',
                onTap: () =>
                    adminPush(context, const DeliveryManagementScreen()),
              ),
              _Item(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => adminSnack(context, 'Notifications'),
              ),
              _Item(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Roles',
                trailing: '6 admins',
                onTap: () => adminSnack(context, 'Admin Roles'),
              ),
              _Item(
                icon: Icons.history_outlined,
                label: 'Audit Logs',
                onTap: () => adminSnack(context, 'Audit Logs'),
              ),
            ]),
            const SizedBox(height: 8),
            AdminButton(
              label: 'Sign Out',
              icon: Icons.logout,
              color: AdminColors.red,
              outlined: true,
              height: 52,
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SignInScreen()),
                (route) => false,
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('MediCaPlus Admin · v1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.greyText)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: adminCard(),
      child: Row(
        children: [
          const AdminAvatar(label: 'VS', size: 54, color: AppColors.darkGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('VS Arogya',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
                SizedBox(height: 4),
                StatusBadge(label: 'Super Admin', color: AppColors.primary),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.greyText),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.items});
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: adminCard(),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: AppColors.darkGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.greyText)),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: AppColors.greyText, size: 20),
          ],
        ),
      ),
    );
  }
}
