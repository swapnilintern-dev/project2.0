import 'package:flutter/material.dart';

import '../../sign_in_screen.dart';
import '../../vendor_registration_screen.dart' show AppColors;
import '../delivery_mock_data.dart';
import '../delivery_models.dart';

class DeliveryProfileScreen extends StatelessWidget {
  const DeliveryProfileScreen({super.key});

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

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DeliveryController.instance,
      builder: (context, _) {
        final rider =
            DeliveryController.instance.rider ?? DeliveryMockData.rider;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _header(rider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _vehicleCard(rider.vehicle),
            ),
            _menuGroup(context, [
              _MenuItem(
                icon: Icons.person_outline,
                label: 'Personal Details',
                onTap: () => _snack(context, 'Opening personal details'),
              ),
              _MenuItem(
                icon: Icons.description_outlined,
                label: 'Documents & Licence',
                onTap: () => _snack(context, 'Opening documents'),
              ),
              _MenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Bank & Payouts',
                onTap: () => _snack(context, 'Opening bank & payouts'),
              ),
              _MenuItem(
                icon: Icons.map_outlined,
                label: 'Service Areas',
                onTap: () => _snack(context, 'Opening service areas'),
              ),
            ]),
            _menuGroup(context, [
              _MenuItem(
                icon: Icons.headset_mic_outlined,
                label: 'Help & Support',
                onTap: () => _snack(context, 'Connecting to support'),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'App Settings',
                onTap: () => _snack(context, 'Opening app settings'),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(RiderProfile rider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    rider.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${rider.id} · ${rider.role}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${rider.rating} · ${rider.totalDeliveries} deliveries',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleCard(VehicleInfo vehicle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.two_wheeler, color: AppColors.darkGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.number,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vehicle.type,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          if (vehicle.verified)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _menuGroup(BuildContext context, List<_MenuItem> items) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              onTap: items[i].onTap,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(items[i].icon,
                    color: AppColors.darkGreen, size: 20),
              ),
              title: Text(
                items[i].label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.greyText),
            ),
            if (i != items.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
