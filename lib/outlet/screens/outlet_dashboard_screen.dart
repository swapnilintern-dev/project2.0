// =============================================================================
// VS Arogya — Outlet Staff · Dashboard
//
// The home tab of the outlet shell. Shows the signed-in outlet, live counters
// derived from the repository (orders + own-outlet stock), a primary
// "New manual order" action, and a short recent-orders strip.
//
// Fully wired to [OutletRepository] (mock for now). Quick actions that lead to
// not-yet-built screens (New order → Step 6) call the [onNewOrder] /
// [onViewStock] / [onViewOrders] callbacks the shell provides, so no wiring
// changes when those screens land.
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_enums.dart';
import '../outlet_models.dart';
import '../outlet_repository.dart';
import '../outlet_session.dart';
import '../outlet_theme.dart';

class OutletDashboardScreen extends StatefulWidget {
  const OutletDashboardScreen({
    super.key,
    required this.onNewOrder,
    required this.onViewStock,
    required this.onViewOrders,
  });

  final VoidCallback onNewOrder;
  final VoidCallback onViewStock;
  final VoidCallback onViewOrders;

  @override
  State<OutletDashboardScreen> createState() => _OutletDashboardScreenState();
}

class _OutletDashboardScreenState extends State<OutletDashboardScreen> {
  final _repo = OutletRepository();

  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final orders = await _repo.fetchOrders();
    final stock = await _repo.fetchStock();
    return _DashboardData(orders: orders, stock: stock);
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _future = Future.value(data));
  }

  @override
  Widget build(BuildContext context) {
    final session = OutletSession.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutletHeader(
          title: 'Hello${session.staffName != null ? ', ${session.staffName}' : ''} 👋',
          subtitle: session.outletLabel,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: OutletColors.success,
            child: FutureBuilder<_DashboardData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _CenteredLoader();
                }
                final data = snap.data ?? const _DashboardData(orders: [], stock: []);
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  children: [
                    _statsCard(data),
                    const SizedBox(height: 16),
                    _primaryAction(),
                    const SizedBox(height: 20),
                    _recentOrders(data.orders),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Stats -----------------------------------------------------------------

  Widget _statsCard(_DashboardData data) {
    final awaiting = data.orders.where((o) => o.isAwaitingPayment).length;
    final paid = data.orders.where((o) => o.isPaid).length;
    final lowStock = data.stock
        .where((s) => s.isOwnOutlet && s.qtyAvailable > 0 && s.qtyAvailable <= 5)
        .length;

    return OutletCardOverlay(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today at a glance', style: OutletTextStyles.sectionTitle),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('${data.orders.length}', 'Orders', Icons.receipt_long_outlined),
              _divider(),
              _stat('$awaiting', 'Awaiting pay', Icons.hourglass_bottom_rounded,
                  color: OutletColors.amber),
              _divider(),
              _stat('$paid', 'Paid', Icons.verified_rounded,
                  color: OutletColors.success),
              _divider(),
              _stat('$lowStock', 'Low stock', Icons.warning_amber_rounded,
                  color: OutletColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color ?? OutletColors.textMid),
          const SizedBox(height: 6),
          Text(value, style: OutletTextStyles.statNum),
          const SizedBox(height: 2),
          Text(label, style: OutletTextStyles.statLabel, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: OutletColors.border);

  // --- Primary action --------------------------------------------------------

  Widget _primaryAction() {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.add_shopping_cart_rounded,
          label: 'New manual order',
          onTap: widget.onNewOrder,
          filled: true,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'View stock',
                onTap: widget.onViewStock,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.list_alt_rounded,
                label: 'All orders',
                onTap: widget.onViewOrders,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Recent orders ---------------------------------------------------------

  Widget _recentOrders(List<OutletOrder> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent orders', style: OutletTextStyles.sectionTitle),
            if (orders.isNotEmpty)
              GestureDetector(
                onTap: widget.onViewOrders,
                child: const Text('See all',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OutletColors.success)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          _emptyOrders()
        else
          for (final o in orders.take(4)) _orderTile(o),
      ],
    );
  }

  Widget _orderTile(OutletOrder o) {
    final (bg, fg) = _statusColors(o.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: OutletColors.badgeGreenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              o.type == OutletOrderType.delivery
                  ? Icons.local_shipping_outlined
                  : Icons.storefront_outlined,
              size: 20,
              color: OutletColors.grad1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.customer.name.isEmpty ? 'Walk-in customer' : o.customer.name,
                    style: OutletTextStyles.prodName),
                const SizedBox(height: 2),
                Text('${o.itemCount} item(s) · ₹${o.total.toStringAsFixed(0)} · ${o.type.label}',
                    style: OutletTextStyles.prodSub),
              ],
            ),
          ),
          OutletBadge(label: o.status.label, bg: bg, fg: fg),
        ],
      ),
    );
  }

  Widget _emptyOrders() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        children: const [
          Icon(Icons.receipt_long_outlined, size: 36, color: OutletColors.textMuted),
          SizedBox(height: 10),
          Text('No orders yet', style: OutletTextStyles.prodName),
          SizedBox(height: 2),
          Text('Create a manual order to get started',
              style: OutletTextStyles.prodSub),
        ],
      ),
    );
  }

  (Color, Color) _statusColors(OutletOrderStatus s) {
    if (s.isReleased) return (OutletColors.badgeRedBg, OutletColors.danger);
    if (s.isPaid) return (OutletColors.badgeGreenBg, OutletColors.success);
    return (OutletColors.badgeAmberBg, OutletColors.amber);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            gradient: filled ? OutletColors.headerGradient : null,
            color: filled ? null : OutletColors.white,
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: OutletColors.border),
            boxShadow: filled ? null : OutletColors.cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 19,
                  color: filled ? Colors.white : OutletColors.grad1),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : OutletColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(color: OutletColors.success),
        ),
      );
}

class _DashboardData {
  const _DashboardData({required this.orders, required this.stock});
  final List<OutletOrder> orders;
  final List<OutletStockItem> stock;
}
