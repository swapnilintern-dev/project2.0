// =============================================================================
// MediCaPlus — Customer Shell
//
// The signed-in customer home. Hosts five persistent tabs in an IndexedStack
// (Home, Search, Cart, Orders, Profile) so each tab keeps its scroll position
// and state when switching. The Cart tab shows a live badge driven by
// CartController. Android back from a sub-tab returns to Home before exiting.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'customer_controllers.dart';
import 'home_screen.dart';
import 'product_list_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.onLogout});

  /// Wired by the host to return to the sign-in screen.
  final VoidCallback? onLogout;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(onOpenTab: _select),
      const ProductListScreen(embedded: true),
      CartScreen(embedded: true, onContinueShopping: () => _select(0)),
      const OrdersScreen(embedded: true),
      ProfileScreen(embedded: true, onLogout: widget.onLogout),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    return ListenableBuilder(
      listenable: CartController.instance,
      builder: (context, _) {
        final cartCount = CartController.instance.itemCount;
        return NavigationBarTheme(
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
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppColors.darkGreen),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search, color: AppColors.darkGreen),
                label: 'Search',
              ),
              NavigationDestination(
                icon: _cartIcon(Icons.shopping_cart_outlined, cartCount),
                selectedIcon: _cartIcon(Icons.shopping_cart, cartCount,
                    color: AppColors.darkGreen),
                label: 'Cart',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon:
                    Icon(Icons.receipt_long, color: AppColors.darkGreen),
                label: 'Orders',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: AppColors.darkGreen),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cartIcon(IconData icon, int count, {Color? color}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (count > 0)
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
