// =============================================================================
// MediCaPlus — Admin · Analytics
//
// Pushed from the Overview "Analytics" quick action. Headline revenue & take
// rate, an "orders by city" bar chart, two ring gauges (on-time delivery &
// buyer retention) and a category-split breakdown.
// =============================================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_models.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Analytics',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.darkText)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => adminSnack(context, 'Exporting report…'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                backgroundColor: AppColors.lightGreenBg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Report',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: adminScroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: _HeadlineStat(
                  value: moneyCompact(kPlatformRevenue),
                  label: 'Platform Revenue',
                  pct: 31,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeadlineStat(
                  value: '${kTakeRate.toStringAsFixed(1)}%',
                  label: 'Take Rate',
                  pct: 0.4,
                  color: AdminColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const AdminSectionTitle('Orders by City'),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(8, 18, 12, 8),
            decoration: adminCard(),
            child: _CityBars(),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: adminCard(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                RingGauge(
                  percent: kOnTimeDelivery,
                  label: 'On-time Delivery',
                  color: AppColors.primary,
                ),
                RingGauge(
                  percent: kBuyerRetention,
                  label: 'Buyer Retention',
                  color: AdminColors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const AdminSectionTitle('Category Split'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: adminCard(),
            child: Column(
              children: [
                for (final c in kCategorySplit)
                  LabeledBar(
                    label: c.name,
                    fraction: c.fraction,
                    color: c.color,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlineStat extends StatelessWidget {
  const _HeadlineStat({
    required this.value,
    required this.label,
    required this.pct,
    required this.color,
  });

  final String value;
  final String label;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: adminCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.show_chart, size: 18, color: color),
              ),
              const Spacer(),
              ChangeBadge(pct: pct),
            ],
          ),
          const SizedBox(height: 14),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

class _CityBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final maxV = kOrdersByCity.map((c) => c.value).reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final i = value.round();
                if (i < 0 || i >= kOrdersByCity.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(kOrdersByCity[i].city,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.greyText)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < kOrdersByCity.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: kOrdersByCity[i].value,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.darkGreen],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
