// =============================================================================
// MediCaPlus — Delivery Partner Shell
//
// Entry point for the delivery role. Hosts four persistent tabs (Tasks, Route,
// Earnings, Profile) in an IndexedStack. Android back from a sub-tab returns
// to Tasks first.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'delivery_mock_data.dart';
import 'screens/earnings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/route_screen.dart';
import 'screens/tasks_dashboard_screen.dart';

class DeliveryMain extends StatefulWidget {
  const DeliveryMain({super.key});

  @override
  State<DeliveryMain> createState() => _DeliveryMainState();
}

class _DeliveryMainState extends State<DeliveryMain> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    DeliveryMockData.seed();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TasksDashboardScreen(onOpenRoute: () => _select(1)),
      const RouteScreen(embedded: true),
      const EarningsScreen(),
      const DeliveryProfileScreen(),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
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
                icon: Icon(Icons.assignment_outlined),
                selectedIcon:
                    Icon(Icons.assignment, color: AppColors.darkGreen),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.navigation_outlined),
                selectedIcon:
                    Icon(Icons.navigation, color: AppColors.darkGreen),
                label: 'Route',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet,
                    color: AppColors.darkGreen),
                label: 'Earnings',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: AppColors.darkGreen),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
