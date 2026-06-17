// =============================================================================
// MediCaPlus — Profile Screen
//
// User header, quick stats, and a settings list: My Orders, Addresses, Saved
// items, Payment methods, Notifications, Support, About and Logout. Every row
// navigates or shows a placeholder action — no dead buttons.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'customer_controllers.dart';
import 'customer_widgets.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';
import 'saved_items_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.embedded = false, this.onLogout});

  final bool embedded;

  /// Invoked when the user confirms logout (the shell wires this to sign-out).
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        _header(),
        const SizedBox(height: 12),
        _statsRow(context),
        const SizedBox(height: 8),
        _group(context, [
          _Tile(
            icon: Icons.receipt_long_outlined,
            title: 'My Orders',
            subtitle: 'Track, return or reorder',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrdersScreen())),
          ),
          _Tile(
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: 'Manage delivery addresses',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddressesScreen())),
          ),
          _Tile(
            icon: Icons.favorite_border,
            title: 'Saved Items',
            subtitle: 'Your wishlist',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedItemsScreen())),
          ),
          _Tile(
            icon: Icons.credit_card_outlined,
            title: 'Payment Methods',
            subtitle: 'Cards, UPI & wallet',
            onTap: () => showAppSnack(context, 'Payment methods coming soon'),
          ),
        ]),
        _group(context, [
          _Tile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Order & offer alerts',
            onTap: () => showAppSnack(context, 'Notification settings'),
          ),
          _Tile(
            icon: Icons.headset_mic_outlined,
            title: 'Support',
            subtitle: 'Help & contact us',
            onTap: () => showAppSnack(context, 'Opening support'),
          ),
          _Tile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'MediCaPlus v1.0.0',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'MediCaPlus',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 MediCaPlus',
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size(double.infinity, 52),
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );

    if (embedded) return SafeArea(bottom: false, child: content);
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title:
            const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: content,
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(gradient: AppColors.greenGradient),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Center(
                child: Text('AP',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Apollo Pharmacy',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('+91 98765 43210',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('✔ Verified Buyer',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([OrdersController.instance, WishlistController.instance]),
      builder: (context, _) {
        OrdersController.instance.ensureSeeded();
        final orders = OrdersController.instance.orders.length;
        final saved = WishlistController.instance.count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _stat('$orders', 'Orders'),
              _stat('$saved', 'Saved'),
              _stat('₹12.4k', 'Spent'),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyText)),
          ],
        ),
      ),
    );
  }

  Widget _group(BuildContext context, List<_Tile> tiles) {
    // The white fill lives on the Material (not an outer DecoratedBox) so the
    // ListTiles can paint their ink splashes on their nearest Material ancestor.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i != tiles.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 56),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (onLogout != null) {
                onLogout!();
              } else {
                // Fallback: pop back to the previous (sign-in) route.
                Navigator.of(context).maybePop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.darkGreen, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.greyText),
    );
  }
}
