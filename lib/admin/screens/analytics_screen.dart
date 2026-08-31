// =============================================================================
// MediCaPlus — Admin · Analytics
//
// Pushed from the Overview "Analytics" quick action. Every figure on this
// screen is computed from LIVE backend data — GET /total-revenue for the
// realised-revenue headline and GET /all-orders for everything else (orders by
// city, delivered rate, repeat buyers, category split). Pull-to-refresh
// reloads both.
// =============================================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../../services/live_refresh.dart';
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_models.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with LiveRefreshMixin {
  final AdminApi _api = AdminApi();

  bool _loading = true;
  bool _failed = false;
  double? _revenue;
  List<AdminOrder> _orders = const [];

  // Analytics recomputes from two endpoints — poll a little slower to stay light.
  @override
  Duration get liveRefreshInterval => const Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    // Load on open, then keep every figure live (poll + app-resume).
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final results = await Future.wait([
      _api.getTotalRevenue(),
      _api.getAllOrders(),
    ]);
    if (!mounted) return;
    final orders = results[1] as List<AdminOrder>?;
    setState(() {
      _revenue = results[0] as double?;
      if (orders != null) _orders = orders;
      _failed = orders == null && _orders.isEmpty;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // LIVE-COMPUTED SERIES
  // ---------------------------------------------------------------------------

  /// Top cities by order count, from each order's shipping city.
  List<CitySales> get _ordersByCity {
    final counts = <String, int>{};
    for (final o in _orders) {
      final c = o.city.trim();
      if (c.isEmpty) continue;
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in entries.take(6))
        CitySales(
          e.key.length > 3 ? e.key.substring(0, 3) : e.key,
          e.value.toDouble(),
        ),
    ];
  }

  /// Share of orders the platform has actually delivered.
  double get _deliveredRate {
    if (_orders.isEmpty) return 0;
    final done =
        _orders.where((o) => o.status == AdminOrderStatus.delivered).length;
    return done / _orders.length;
  }

  /// Share of buyers who have ordered more than once.
  double get _repeatBuyerRate {
    final perBuyer = <String, int>{};
    for (final o in _orders) {
      perBuyer[o.buyer] = (perBuyer[o.buyer] ?? 0) + 1;
    }
    if (perBuyer.isEmpty) return 0;
    final repeat = perBuyer.values.where((n) => n > 1).length;
    return repeat / perBuyer.length;
  }

  /// Quantity-weighted split across the app's three canonical categories,
  /// from each order line's product category.
  List<CategorySplit> get _categorySplit {
    int injections = 0, vaccines = 0, medicine = 0;
    for (final o in _orders) {
      for (final l in o.lines) {
        final c = l.category.toLowerCase();
        if (c.contains('injection')) {
          injections += l.quantity;
        } else if (c.contains('vaccine')) {
          vaccines += l.quantity;
        } else {
          medicine += l.quantity;
        }
      }
    }
    final total = injections + vaccines + medicine;
    if (total == 0) return const [];
    return [
      CategorySplit('Medicine', medicine / total, AdminColors.green),
      CategorySplit(
          'Lifesaving Injections', injections / total, AdminColors.blue),
      CategorySplit('Vaccines', vaccines / total, AdminColors.purple),
    ];
  }

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
      ),
      body: _loading && _orders.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _failed
              ? _ErrorState(onRetry: _load)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _body(),
                ),
    );
  }

  Widget _body() {
    final cities = _ordersByCity;
    final split = _categorySplit;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: adminScroll),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: _HeadlineStat(
                value: _revenue == null ? '—' : moneyCompact(_revenue!),
                label: 'Realised Revenue',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HeadlineStat(
                value: '${_orders.length}',
                label: 'Total Orders',
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
          child: cities.isEmpty
              ? const Center(
                  child: Text('No orders with a shipping city yet',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.greyText)))
              : _CityBars(cities: cities),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: adminCard(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RingGauge(
                percent: _deliveredRate,
                label: 'Delivered Rate',
                color: AppColors.primary,
              ),
              RingGauge(
                percent: _repeatBuyerRate,
                label: 'Repeat Buyers',
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
          child: split.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: Text('No order items yet',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.greyText))),
                )
              : Column(
                  children: [
                    for (final c in split)
                      LabeledBar(
                        label: c.name,
                        fraction: c.fraction,
                        color: c.color,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Couldn\'t load analytics',
              style: TextStyle(fontSize: 14, color: AppColors.greyText)),
          const SizedBox(height: 12),
          AdminButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            expand: false,
            height: 40,
            onPressed: onRetry,
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
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: adminCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
  const _CityBars({required this.cities});
  final List<CitySales> cities;

  @override
  Widget build(BuildContext context) {
    final maxV = cities.map((c) => c.value).reduce((a, b) => a > b ? a : b);
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
                if (i < 0 || i >= cities.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(cities[i].city,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.greyText)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < cities.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: cities[i].value,
                  width: 20,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
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
