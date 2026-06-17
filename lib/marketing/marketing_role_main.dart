// =============================================================================
// MediCaPlus — Marketing Head Shell
//
// Entry point for the Marketing Head role. Hosts four persistent tabs in an
// IndexedStack (Dashboard, Orders, Products, Coupons) so each keeps its state
// when switching — mirroring the customer module's CustomerShell. The accent
// flips to purple on the Coupons tab to match the design. Android back from a
// sub-tab returns to Dashboard first.
// =============================================================================

import 'package:flutter/material.dart';

import '../sign_in_screen.dart';
import '../vendor_registration_screen.dart' show AppColors;
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'coupons_screen.dart';

class MarketingRoleMain extends StatefulWidget {
  const MarketingRoleMain({super.key});

  @override
  State<MarketingRoleMain> createState() => _MarketingRoleMainState();
}

class _MarketingRoleMainState extends State<MarketingRoleMain> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // One green/white theme across every tab.
    const accent = AppColors.primary;
    const accentBg = AppColors.lightGreenBg;

    final tabs = [
      MarketingDashboardScreen(onOpenTab: _select),
      const MarketingOrdersScreen(),
      const MarketingProductsScreen(),
      const MarketingCouponsScreen(),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: AppColors.pageBg,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: AppColors.darkText),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: accentBg,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? accent
                    : AppColors.greyText,
              ),
            ),
          ),
          child: NavigationBar(
            height: 64,
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded, color: accent),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2, color: accent),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: const Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication, color: accent),
                label: 'Products',
              ),
              NavigationDestination(
                icon: const Icon(Icons.local_offer_outlined),
                selectedIcon: Icon(Icons.local_offer, color: accent),
                label: 'Coupons',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
