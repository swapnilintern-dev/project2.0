// =============================================================================
// MediCaPlus — Admin · Platform Overview (tab 0)
//
// The operator's landing screen, fully backed by the backend:
//   GET /vsArogya/total-revenue   -> realised revenue (Delivered orders)
//   GET /vsArogya/all-orders      -> total orders + delivered + recent feed
//   GET /vsArogya/active-vendors  -> active (approved) vendor count
//   GET /vsArogya/pending-vendor  -> pending approvals count
//
// A gradient hero with realised revenue, a 2×2 KPI grid, quick actions into the
// deeper tools, and a recent-orders feed. Pull-to-refresh reloads everything.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'analytics_screen.dart';
import 'products_screen.dart';
import 'delivery_management_screen.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key, required this.onOpenTab});

  /// Switches the shell to another bottom-nav tab (1=Vendors, 2=Orders…).
  final ValueChanged<int> onOpenTab;

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final AdminApi _api = AdminApi();

  bool _loading = true;
  double? _revenue;
  int? _activeVendors;
  int? _pending;
  List<AdminOrder> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads every headline metric in parallel. Each call is independent and
  /// null-safe, so a single failing endpoint never blanks the whole screen.
  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.getTotalRevenue(),
      _api.getAllOrders(),
      _api.getActiveVendorCount(),
      _api.getPendingVendors(),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _revenue = results[0] as double?;
      final orders = results[1] as List<AdminOrder>?;
      if (orders != null) _orders = orders;
      _activeVendors = results[2] as int?;
      final pending = results[3] as List<Vendor>?;
      _pending = pending?.length;
    });
  }

  int get _deliveredCount =>
      _orders.where((o) => o.status == AdminOrderStatus.delivered).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _hero(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kpiGrid(context),
                      const SizedBox(height: 22),
                      const AdminSectionTitle('Quick Actions'),
                      const SizedBox(height: 12),
                      _quickActions(context),
                      const SizedBox(height: 22),
                      AdminSectionTitle('Recent Orders',
                          actionLabel: 'View all',
                          onAction: () => widget.onOpenTab(2)),
                      const SizedBox(height: 12),
                      _recentOrders(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Gradient hero -------------------------------------------------------

  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.health_and_safety,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VS Arogya · Admin',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    SizedBox(height: 2),
                    Text('Platform Overview',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              AdminBell(
                count: _pending ?? 0,
                light: true,
                onTap: () => widget.onOpenTab(1),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Total Revenue (Delivered)',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          if (_loading && _revenue == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              ),
            )
          else
            AnimatedCount(
              target: _revenue ?? 0,
              grouped: true,
              prefix: '₹',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }

  // ---- KPI grid ------------------------------------------------------------

  String _kpi(int? v) => v == null ? '—' : groupInt(v);

  Widget _kpiGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        KpiCard(
          icon: Icons.receipt_long_outlined,
          value: _kpi(_orders.isEmpty && _loading ? null : _orders.length),
          label: 'Total Orders',
          color: AdminColors.blue,
          onTap: () => widget.onOpenTab(2),
        ),
        KpiCard(
          icon: Icons.storefront_outlined,
          value: _kpi(_activeVendors),
          label: 'Active Vendors',
          color: AdminColors.green,
          onTap: () => widget.onOpenTab(1),
        ),
        KpiCard(
          icon: Icons.pending_actions_outlined,
          value: _kpi(_pending),
          label: 'Pending Approvals',
          color: AdminColors.orange,
          onTap: () => widget.onOpenTab(1),
        ),
        KpiCard(
          icon: Icons.check_circle_outline,
          value: _kpi(_orders.isEmpty && _loading ? null : _deliveredCount),
          label: 'Delivered',
          color: AdminColors.darkGreen,
          onTap: () => widget.onOpenTab(2),
        ),
      ],
    );
  }

  // ---- Quick actions -------------------------------------------------------

  Widget _quickActions(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.insights_outlined, 'Analytics',
          () => adminPush(context, const AdminAnalyticsScreen())),
      (Icons.medication_outlined, 'Products',
          () => adminPush(context, const AdminProductsScreen())),
      (Icons.delivery_dining_outlined, 'Delivery',
          () => adminPush(context, const DeliveryManagementScreen())),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
              child: _QuickAction(
            icon: items[i].$1,
            label: items[i].$2,
            onTap: items[i].$3,
          )),
          if (i != items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  // ---- Recent orders -------------------------------------------------------

  Widget _recentOrders(BuildContext context) {
    if (_loading && _orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2))),
      );
    }
    if (_orders.isEmpty) {
      return const AdminEmpty(label: 'No orders yet');
    }
    final recent = _orders.take(5).toList();
    return Column(
      children: [for (final o in recent) _OrderRow(order: o)],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: adminCard(),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.darkGreen, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final AdminOrder order;

  (IconData, Color) get _visual => switch (order.status) {
        AdminOrderStatus.delivered => (
            Icons.check_circle_outline,
            AdminColors.darkGreen
          ),
        AdminOrderStatus.cancelled => (Icons.cancel_outlined, AdminColors.red),
        AdminOrderStatus.pending => (
            Icons.pending_actions_outlined,
            AdminColors.orange
          ),
        AdminOrderStatus.confirmed => (
            Icons.inventory_2_outlined,
            AdminColors.blue
          ),
        AdminOrderStatus.shipped => (
            Icons.local_shipping_outlined,
            AdminColors.purple
          ),
        AdminOrderStatus.outForDelivery => (
            Icons.delivery_dining_outlined,
            AdminColors.amber
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: adminCard(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${_shortId(order.id)} · ${money(order.amount)}',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text('${order.status.label} · ${order.buyer}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${order.itemCount} items',
              style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

/// Short, readable order reference from a Mongo _id (last 6 chars, upper-case).
String _shortId(String id) {
  if (id.length <= 6) return id.toUpperCase();
  return id.substring(id.length - 6).toUpperCase();
}
