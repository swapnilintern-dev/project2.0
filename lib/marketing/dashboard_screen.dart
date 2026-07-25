// =============================================================================
// MediCaPlus — Marketing Head · Dashboard tab
//
// Lightweight overview: a greeting header, a 2×2 stat grid (pending orders,
// ready to ship, low stock, active coupons) sourced live from the controllers,
// and a short "recent orders" preview. Tapping a stat or "View all" jumps to
// the relevant tab via [onOpenTab]. Intentionally minimal — the heavy lifting
// lives in the dedicated tabs.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../services/auth_service.dart';
import '../services/live_refresh.dart';
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart'
    show formatRupees, SectionHeader;
import 'agent_registration_screen.dart';
import 'marketing_controllers.dart';
import 'marketing_models.dart';
import 'order_details_screen.dart';
import 'outlet_registration_screen.dart';
import 'reports_screen.dart';
import 'select_outlet_screen.dart';

class MarketingDashboardScreen extends StatefulWidget {
  const MarketingDashboardScreen({super.key, required this.onOpenTab});

  /// Switches the shell to another tab (1 = Orders, 2 = Products, 3 = Coupons).
  final ValueChanged<int> onOpenTab;

  @override
  State<MarketingDashboardScreen> createState() =>
      _MarketingDashboardScreenState();
}

class _MarketingDashboardScreenState extends State<MarketingDashboardScreen>
    with LiveRefreshMixin {
  /// Backs the pull-to-refresh gesture. The dashboard also auto-syncs via
  /// [LiveRefreshMixin], so the stats stay live with no manual refresh.
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Fetch on open, then keep every summarised controller live (poll +
    // app-resume) so orders, stock and coupons update on their own.
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  /// Reloads every controller the dashboard summarises, so a single sync keeps
  /// orders, stock and coupons all up to date.
  @override
  Future<void> onLiveRefresh() => _refreshAll();

  Future<void> _refreshAll() async {
    await Future.wait([
      MarketingOrdersController.instance.refresh(),
      MarketingProductsController.instance.refresh(),
      MarketingCouponsController.instance.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final orders = MarketingOrdersController.instance;
    final products = MarketingProductsController.instance;
    final coupons = MarketingCouponsController.instance;

    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([orders, products, coupons]),
        builder: (context, _) {
          final recent = orders.byStatus(MarketingOrderStatus.pending);
          return RefreshIndicator(
            key: _refreshKey,
            onRefresh: _refreshAll,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(
                      icon: Icons.inbox_outlined,
                      value: '${orders.countByStatus(MarketingOrderStatus.pending)}',
                      label: 'Pending Orders',
                      color: AppColors.primary,
                      onTap: () => widget.onOpenTab(1),
                    ),
                    _StatCard(
                      icon: Icons.local_shipping_outlined,
                      value:
                          '${orders.countByStatus(MarketingOrderStatus.confirmed)}',
                      label: 'Ready to Ship',
                      color: MarketingColors.blue,
                      onTap: () => widget.onOpenTab(1),
                    ),
                    _StatCard(
                      icon: Icons.warning_amber_outlined,
                      value: '${products.lowCount + products.outCount}',
                      label: 'Low / Out of Stock',
                      color: MarketingColors.orange,
                      onTap: () => widget.onOpenTab(2),
                    ),
                    _StatCard(
                      icon: Icons.local_offer_outlined,
                      value: '${coupons.activeCount}',
                      label: 'Active Coupons',
                      color: AppColors.darkGreen,
                      onTap: () => widget.onOpenTab(3),
                    ),
                  ],
                ),
              ),
              // Full-width "Register Outlet" entry — creates a physical outlet
              // on the backend and sets the login it will sign in with.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _ActionCard(
                  icon: Icons.add_business_outlined,
                  iconColor: AppColors.primary,
                  title: 'Register Outlet',
                  subtitle: 'Add a new outlet and set its login details',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const OutletRegistrationScreen()),
                  ),
                ),
              ),
              // Full-width "Register Agent" entry — creates an Area Agent
              // (Vendor role "agent" + pincode) that monitors its pincode's
              // orders, and sets the login it signs in with.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _ActionCard(
                  icon: Icons.person_pin_circle_outlined,
                  iconColor: AppColors.darkGreen,
                  title: 'Register Agent',
                  subtitle: 'Add an area agent and assign a pincode',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AgentRegistrationScreen()),
                  ),
                ),
              ),
              // Full-width "Select Outlet" entry — opens the outlet-ordering
              // flow (enter pincode → pick outlet → select product → qty).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _ActionCard(
                  icon: Icons.storefront_outlined,
                  iconColor: AppColors.primary,
                  title: 'Select Outlet',
                  subtitle: 'Enter a pincode & place an order for an outlet',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SelectOutletScreen()),
                  ),
                ),
              ),
              // Full-width Reports entry — opens the report screen that
              // downloads shareable Excel exports from the backend.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _ActionCard(
                  icon: Icons.assessment_outlined,
                  iconColor: AppColors.darkGreen,
                  title: 'Reports',
                  subtitle: 'Generate vendor, stock & order reports (Excel)',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const MarketingReportsScreen()),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SectionHeader(
                  title: 'New Orders',
                  actionLabel: 'View all',
                  onAction: () => widget.onOpenTab(1),
                ),
              ),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Text('No new orders right now.',
                      style: TextStyle(color: AppColors.greyText)),
                )
              else
                ...recent.take(3).map((o) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _MiniOrderRow(
                        order: o,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailsScreen(orderId: o.id),
                          ),
                        ),
                      ),
                    )),
              const SizedBox(height: 16),
            ],
            ),
          );
        },
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Real logged-in store/company name; the line is hidden entirely when
          // the backend hasn't provided one (no fake company shown).
          if (AuthService.storeName != null) ...[
            Text(AuthService.storeName!,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
          ],
          const Text('Marketing Head',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Manage orders, stock & promotions',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyText)),
          ],
        ),
      ),
    );
  }
}

/// Full-width entry card shown under the stat grid — one row per destination
/// (Register Outlet, Select Outlet, Reports).
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.greyText)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}

class _MiniOrderRow extends StatelessWidget {
  const _MiniOrderRow({required this.order, required this.onTap});

  final MarketingOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.lightGreenBg,
              child: Text(order.initials,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppColors.darkGreen)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.buyer,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.darkText)),
                  Text('#${order.id} · ${order.timeAgo}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.greyText)),
                ],
              ),
            ),
            Text(formatRupees(order.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.darkGreen)),
          ],
        ),
      ),
    );
  }
}
