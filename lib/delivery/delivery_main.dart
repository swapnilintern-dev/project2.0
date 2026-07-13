// =============================================================================
// MediCaPlus — Delivery Partner Shell
//
// Entry point for the delivery role. Hosts two persistent tabs (Tasks,
// Profile) in an IndexedStack. Android back from a sub-tab returns to Tasks
// first.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_widgets.dart';
import 'delivery_models.dart';
import 'screens/profile_screen.dart';
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
    // Warm the live dispatch queue on entry (the dashboard also keeps it live).
    DeliveryController.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      TasksDashboardScreen(),
      DeliveryProfileScreen(),
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
        // Every delivery tab has a dark top (brand gradient heroes / dark map),
        // so light status-bar icons read correctly across the whole shell.
        body: BrandStatusBar(
          child: IndexedStack(index: _index, children: tabs),
        ),
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
                selectedIcon: Icon(
                  Icons.assignment,
                  color: AppColors.darkGreen,
                ),
                label: 'Tasks',
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
