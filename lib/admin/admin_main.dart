// =============================================================================
// MediCaPlus — Admin (Platform Operator) · Shell
//
// Entry point for the Admin role. Hosts five persistent tabs in an IndexedStack
// (Overview, Vendors, Orders, Users, Settings) so each keeps its scroll / tab /
// search state when switching — mirroring the customer & marketing shells.
// Android back from a sub-tab returns to Overview first. Detail screens
// (Vendor Review, Dispute, Analytics, Products, Delivery, Add Product) are
// pushed on top via Navigator from within these tabs.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_widgets.dart' show maybeExitApp;
import 'screens/overview_screen.dart';
import 'screens/vendors_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/users_screen.dart';
import 'screens/settings_screen.dart';

class AdminRoleMain extends StatefulWidget {
  const AdminRoleMain({super.key});

  @override
  State<AdminRoleMain> createState() => _AdminRoleMainState();
}

class _AdminRoleMainState extends State<AdminRoleMain> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminOverviewScreen(onOpenTab: _select),
      const AdminVendorsScreen(),
      const AdminOrdersScreen(),
      const AdminUsersScreen(),
      const AdminSettingsScreen(),
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
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: AppColors.lightGreenBg,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? AppColors.darkGreen
                    : AppColors.greyText,
              ),
            ),
          ),
          child: NavigationBar(
            height: 64,
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: AppColors.darkGreen),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront, color: AppColors.darkGreen),
                label: 'Vendors',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: AppColors.darkGreen),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: AppColors.darkGreen),
                label: 'Users',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: AppColors.darkGreen),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared helper so any admin screen can push a detail page consistently.
Future<T?> adminPush<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(builder: (_) => page),
  );
}
