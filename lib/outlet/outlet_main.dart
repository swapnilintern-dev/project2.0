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
import '../services/live_refresh.dart';
import 'outlet_api.dart';
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

  /// Adds a medicine to the cart already pinned to the lot staff chose in the
  /// Stock tab's batch picker — an outlet line is never created without one.
  void _onAddToCart(OutletStockItem item, OutletBatch batch) {
    OutletCart.instance.add(item, batch: batch);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(batch.batchNumber.isEmpty
            ? '${item.name} added to cart'
            : '${item.name} added · batch ${batch.batchNumber}'),
        duration: const Duration(milliseconds: 1200),
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

/// Profile tab — the outlet's full account, fetched live from the backend
/// (GET /vsArogya/outlet-profile/:id) so every field stays in sync with what
/// marketing registered. A demo (non-live) session falls back to the identity
/// captured at sign-in. Always ends with a sign-out action.
class _OutletProfileTab extends StatefulWidget {
  @override
  State<_OutletProfileTab> createState() => _OutletProfileTabState();
}

class _OutletProfileTabState extends State<_OutletProfileTab>
    with LiveRefreshMixin {
  final _api = OutletApi();

  OutletAccount? _profile;
  bool _loading = false;
  String? _error;

  // The profile changes rarely — a slow poll keeps it fresh without noise.
  @override
  Duration get liveRefreshInterval => const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // First load, then keep it live (poll + app-resume); immediate: false avoids
    // a duplicate fetch on open.
    _load();
    startLiveRefresh(immediate: false);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _load();

  Future<void> _load() async {
    final session = OutletSession.instance;

    // Demo login (no backend id) — show what we captured at sign-in.
    if (!session.isLive) {
      setState(() {
        _profile = OutletAccount(
          id: '',
          outletName: session.outletName ?? 'Outlet',
          ownerName: session.staffName ?? 'Outlet Staff',
          city: session.district ?? '',
        );
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final (profile, error) = await _api.fetchProfile(session.outletId!);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (error != null) {
        _error = error;
      } else {
        _profile = profile;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutletHeader(
          title: 'Profile',
          subtitle: 'Outlet Staff account',
          bottomPadding: 22,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: OutletColors.success,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _identityCard(),
                if (_loading && _profile == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: OutletColors.success),
                    ),
                  )
                else if (_error != null && _profile == null)
                  _errorBox(_error!)
                else if (_profile != null) ...[
                  const SizedBox(height: 12),
                  _detailsCard(_profile!),
                ],
                const SizedBox(height: 12),
                _signOutButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _identityCard() {
    final p = _profile;
    final name = p?.ownerName.isNotEmpty == true
        ? p!.ownerName
        : (OutletSession.instance.staffName ?? 'Outlet Staff');
    final subtitle = p != null && p.outletName.isNotEmpty
        ? p.outletName
        : OutletSession.instance.outletLabel;

    return OutletCardOverlay(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: OutletColors.badgeGreenBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: OutletColors.grad1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: OutletTextStyles.sectionTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: OutletTextStyles.prodSub),
              ],
            ),
          ),
          if (p != null)
            OutletBadge(
              label: p.isActive ? 'Active' : 'Inactive',
              bg: p.isActive
                  ? OutletColors.badgeGreenBg
                  : OutletColors.badgeRedBg,
              fg: p.isActive ? OutletColors.success : OutletColors.danger,
            ),
        ],
      ),
    );
  }

  Widget _detailsCard(OutletAccount p) {
    final rows = <Widget>[
      if (p.outletName.isNotEmpty)
        _infoRow(Icons.storefront_outlined, 'Outlet name', p.outletName),
      if (p.ownerName.isNotEmpty)
        _infoRow(Icons.person_outline, 'Owner', p.ownerName),
      if (p.mobileNo.isNotEmpty)
        _infoRow(Icons.call_outlined, 'Mobile', p.mobileNo),
      if (p.email.isNotEmpty)
        _infoRow(Icons.mail_outline, 'Email', p.email),
      if (p.gstNumber.isNotEmpty)
        _infoRow(Icons.receipt_long_outlined, 'GST number', p.gstNumber),
      if (p.fullAddress.isNotEmpty)
        _infoRow(Icons.location_on_outlined, 'Address', p.fullAddress),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: OutletColors.border),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: OutletColors.grad2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: OutletTextStyles.prodSub),
                const SizedBox(height: 2),
                Text(value, style: OutletTextStyles.prodName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 32, 4, 8),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: OutletColors.textMuted, size: 34),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: OutletTextStyles.prodSub),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _signOutButton() {
    return Material(
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
    );
  }
}
