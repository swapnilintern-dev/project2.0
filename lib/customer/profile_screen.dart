// =============================================================================
// MediCaPlus — Profile Screen
//
// User header, quick stats, and a settings list: My Orders, Addresses, Saved
// items, Payment methods, Notifications, Support, About and Logout. Every row
// navigates or shows a placeholder action — no dead buttons.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../services/auth_service.dart';
import '../theme/app_theme.dart' show AppShadows;
import '../account_deletion/account_deletion_controller.dart';
import '../account_deletion/privacy_security_screen.dart';
import 'customer_controllers.dart';
import 'customer_widgets.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';
import 'saved_items_screen.dart';
import 'about_us_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.embedded = false, this.onLogout});

  final bool embedded;

  /// Invoked when the user confirms logout (the shell wires this to sign-out).
  final VoidCallback? onLogout;

  /// Real display name when the backend provides one (see AuthService.storeName);
  /// a neutral, non-fake label otherwise.
  String get _displayName => AuthService.storeName ?? 'MediCaPlus Buyer';

  /// The real mobile number the user signed in with.
  String get _displayPhone =>
      (AuthService.phone == null || AuthService.phone!.isEmpty)
          ? '—'
          : AuthService.phone!;

  /// Two-letter initials from the display name.
  String get _initials {
    final parts = _displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

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
          ),/////PAYMENTS METHOD
          /////
          
        ]),
        _group(context, [
          _Tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Security',
            subtitle: 'Account & data controls',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PrivacySecurityScreen(
                  role: DeletionRole.vendor,
                  userName: _displayName,
                  contact: _displayPhone,
                ),
              ),
            ),
          ),
          _Tile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Order & offer alerts',
            onTap: () => showAppSnack(context, 'Notification settings'),
          ),
          ///// SUPPORT TILE
          _Tile(
            icon: Icons.headset_mic_outlined,
            title: 'Support',
            subtitle: 'Help & contact us',
           onTap: () => _showSupportCard(context),
          ),
          _Tile(
  icon: Icons.info_outline,
  title: 'About Us',
  subtitle: 'Learn more about VS Arogya',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AboutUsScreen(),
      ),
    );
  },
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
              child: Center(
                child: Text(_initials,
                    style: const TextStyle(
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
                  Text(_displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(_displayPhone,
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
        final orderList = OrdersController.instance.orders;
        final orders = orderList.length;
        final saved = WishlistController.instance.count;
        // Real lifetime spend = sum of the user's actual order totals.
        final spent = orderList.fold<double>(0, (sum, o) => sum + o.total);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _stat('$orders', 'Orders'),
              _stat('$saved', 'Saved'),
              _stat(_formatSpent(spent), 'Spent'),
            ],
          ),
        );
      },
    );
  }

  /// Compact rupee formatting for the lifetime-spend stat (₹0, ₹950, ₹12.4k).
  String _formatSpent(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.round()}';
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
          boxShadow: AppShadows.card,
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
    // Adaptive: native Cupertino alert on iOS, Material dialog on Android.
    showAdaptiveDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ///LOGOUT BUTTON OF CUSTOMER
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
void _showSupportCard(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Support & Contact',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),
            //// PHONE CALL
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('+91 9876543210, 0651-4502340'),
              subtitle: const Text('Customer Support'),
              onTap: () {},
            ),
///// LATER IT SHOULD DIRECTLY REDIRECT TO THE GMAIL WITH ADDED SENDER.
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('support@vsarogya.co.IN'),
              subtitle: const Text('Email Support'),
              onTap: () {},
            ),

            Card(
  child: ListTile(
    leading: const Icon(
      Icons.location_on,
      color: Colors.green,
    ),
    title: const Text(
      'VS Arogya Meda Pvt Ltd',
      style: TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    subtitle: const Text(
      'Darbhanga, Bihar, India\n\n'
      'Flat No. - D3, First Floor, Block B,\n'
      'S. K. Residency, Road No.- 4, Bariatu Housing Colony,\n'
      'District: Ranchi,\n'
      'State: Jharkhand (India) - 834009',
    ),
  ),
 ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact Us'),
                onPressed: () {
                  Navigator.pop(context);
                  _showContactUsDialog(context);
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}
void _showContactUsDialog(BuildContext context) {
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final messageController = TextEditingController();

  bool consent = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Center(
              child: Text('Contact Us'),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Your Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Mobile Number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Write something...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: consent,
                          onChanged: (value) {
                            setState(() {
                              consent = value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'I consent to be contacted by our representative.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // API Call Here
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Request submitted successfully',
                        ),
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}