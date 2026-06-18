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
import '../theme/app_widgets.dart' show maybeExitApp, BrandStatusBar;
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
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          _select(0);
        } else {
          maybeExitApp(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        // No app bar: each tab draws its own gradient header. We fill the
        // status-bar strip with the same brand gradient so the green banner
        // reads edge-to-edge (no white gap), and float the logout at top-right.
        body: BrandStatusBar(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.paddingOf(context).top,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.darkGreen, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              IndexedStack(index: _index, children: tabs),
              Positioned(
                top: 0,
                right: 8,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.18),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        onPressed: _logout,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Logout',
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
