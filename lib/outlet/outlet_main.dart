// =============================================================================
// VS Arogya — Outlet Staff · Role Shell
//
// Entry point for the Outlet Staff role, reached the SAME way every other role
// is: sign-in → homeForRole() (auth/session.dart) → this shell. Hosts the tabs
// in an IndexedStack (like DeliveryMain): Dashboard, Stock, Orders, Profile.
//
// ROUTE GUARD: renders only when an outlet staff member is signed in
// ([OutletSession]); otherwise it bounces back to the sign-in screen. Android
// back from a sub-tab returns to the Dashboard first.
//
// Dashboard is live now. Stock (Step 5), Manual order (Step 6), Payment
// (Step 7) and Orders (Step 8) replace the placeholders below as they land —
// the shell wiring stays the same.
// =============================================================================

import 'package:flutter/material.dart';

import '../auth/session.dart' show logout;
import 'outlet_cart.dart';
import 'outlet_models.dart';
import 'outlet_session.dart';
import 'outlet_theme.dart';
import 'screens/outlet_dashboard_screen.dart';
import 'screens/outlet_manual_order_screen.dart';
import 'screens/outlet_orders_screen.dart';
import 'screens/outlet_stock_screen.dart';

class OutletMain extends StatefulWidget {
  const OutletMain({super.key});

  @override
  State<OutletMain> createState() => _OutletMainState();
}

class _OutletMainState extends State<OutletMain> {
  int _index = 0;

  /// Bumped when the Orders tab is opened so it rebuilds fresh (an IndexedStack
  /// keeps child state, which would otherwise hide newly created orders).
  int _ordersTick = 0;

  void _select(int i) => setState(() {
        if (i == 2 && _index != 2) _ordersTick++;
        _index = i;
      });

  void _openManualOrder() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OutletManualOrderScreen()),
    );
  }

  void _onNewOrder() {
    if (OutletCart.instance.isEmpty) {
      _select(1); // jump to Stock so staff can add items first
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add items from stock to start an order.')),
      );
      return;
    }
    _openManualOrder();
  }

  void _onAddToCart(OutletStockItem item) {
    OutletCart.instance.add(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Route guard: no outlet session → back to sign-in.
    if (!OutletSession.instance.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) logout(context);
      });
      return const Scaffold(
        backgroundColor: OutletColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: OutletColors.success),
        ),
      );
    }

    final tabs = [
      OutletDashboardScreen(
        onNewOrder: _onNewOrder,
        onViewStock: () => _select(1),
        onViewOrders: () => _select(2),
      ),
      OutletStockScreen(onAddToCart: _onAddToCart),
      OutletOrdersScreen(key: ValueKey('outlet-orders-$_ordersTick')),
      _OutletProfileTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          _select(0);
        }
      },
      child: Scaffold(
        backgroundColor: OutletColors.bg,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: tabs),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live cart bar — visible across tabs whenever the cart has items.
            ListenableBuilder(
              listenable: OutletCart.instance,
              builder: (context, _) {
                final cart = OutletCart.instance;
                if (cart.isEmpty) return const SizedBox.shrink();
                return _CartBar(
                  itemCount: cart.itemCount,
                  total: cart.total,
                  onReview: _openManualOrder,
                );
              },
            ),
            OutletBottomNav(currentIndex: _index, onTap: _select),
          ],
        ),
      ),
    );
  }
}

/// Bottom cart bar shown above the nav whenever the cart has items. Tapping it
/// opens the Create Manual Order screen.
class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.itemCount,
    required this.total,
    required this.onReview,
  });

  final int itemCount;
  final double total;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReview,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: OutletColors.headerGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: OutletColors.cardShadow,
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                '$itemCount item(s) · ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text('Review order',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal profile tab — signed-in identity + sign out. Fleshed out later if
/// needed; for now it gives the shell a working logout entry point.
class _OutletProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = OutletSession.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OutletHeader(title: 'Profile', subtitle: 'Outlet Staff account'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              OutletCardOverlay(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: OutletColors.badgeGreenBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: OutletColors.grad1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.staffName ?? 'Outlet Staff',
                              style: OutletTextStyles.sectionTitle),
                          const SizedBox(height: 2),
                          Text(session.outletLabel,
                              style: OutletTextStyles.prodSub),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => logout(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: OutletColors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: OutletColors.cardShadow,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.logout_rounded, color: OutletColors.danger),
                        SizedBox(width: 12),
                        Text('Sign out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: OutletColors.danger,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
