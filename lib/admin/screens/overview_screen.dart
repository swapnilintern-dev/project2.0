// =============================================================================
// MediCaPlus — Admin · Platform Overview (tab 0)
//
// The operator's landing screen: a gradient hero with the headline GMV, a 2×2
// KPI grid (orders / vendors / pending approvals / open disputes), a 6-month
// GMV trend chart, quick actions into the deeper tools (Analytics, Products,
// Delivery), and a recent-activity feed.
// =============================================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'analytics_screen.dart';
import 'products_screen.dart';
import 'delivery_management_screen.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key, required this.onOpenTab});

  /// Switches the shell to another bottom-nav tab (1=Vendors, 2=Orders…).
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: adminScroll,
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
                    _trendCard(),
                    const SizedBox(height: 22),
                    const AdminSectionTitle('Quick Actions'),
                    const SizedBox(height: 12),
                    _quickActions(context),
                    const SizedBox(height: 22),
                    AdminSectionTitle('Recent Activity',
                        actionLabel: 'View all',
                        onAction: () => adminSnack(context, 'Full activity log')),
                    const SizedBox(height: 12),
                    ...kActivity.map((a) => _ActivityRow(item: a)),
                  ],
                ),
              ),
            ),
          ],
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
                count: 2,
                light: true,
                onTap: () => adminSnack(context, 'Notifications'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Gross Merchandise Value (MTD)',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCount(
                target: 2.84,
                decimals: 2,
                prefix: '₹',
                suffix: ' Cr',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: ChangeBadge(pct: kGmvChangePct, onLight: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- KPI grid ------------------------------------------------------------

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
          value: groupInt(kTotalOrders),
          label: 'Total Orders',
          color: AdminColors.blue,
          onTap: () => onOpenTab(2),
        ),
        KpiCard(
          icon: Icons.storefront_outlined,
          value: groupInt(kActiveVendors),
          label: 'Active Vendors',
          color: AdminColors.green,
          onTap: () => onOpenTab(1),
        ),
        KpiCard(
          icon: Icons.pending_actions_outlined,
          value: '$kPendingApprovals',
          label: 'Pending Approvals',
          color: AdminColors.orange,
          onTap: () => onOpenTab(1),
        ),
        KpiCard(
          icon: Icons.gavel_outlined,
          value: '$kOpenDisputes',
          label: 'Open Disputes',
          color: AdminColors.red,
          onTap: () => onOpenTab(2),
        ),
      ],
    );
  }

  // ---- GMV trend chart -----------------------------------------------------

  Widget _trendCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: adminCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('GMV Trend · 6 Months',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
              ),
              Row(
                children: const [
                  Icon(Icons.trending_up, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Steady growth',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(height: 150, child: _Chart()),
        ],
      ),
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
          Expanded(child: _QuickAction(
            icon: items[i].$1,
            label: items[i].$2,
            onTap: items[i].$3,
          )),
          if (i != items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 3.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, _) {
                final i = value.round();
                if (i < 0 || i >= kGmvMonths.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(kGmvMonths[i],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.greyText)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: kGmvTrend,
            isCurved: true,
            barWidth: 3,
            color: AppColors.primary,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.32),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

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

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
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
              color: item.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, size: 20, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(item.timeAgo,
              style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
        ],
      ),
    );
  }
}
