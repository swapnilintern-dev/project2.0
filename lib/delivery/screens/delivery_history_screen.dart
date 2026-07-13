// =============================================================================
// MediCaPlus — Delivery Partner · My Deliveries (history)
//
// The agent's completed deliveries, fetched LIVE from the backend
// (GET /all-orders filtered to "Delivered"). Filterable by date range —
// Today / This Week / This Month / All — with a summary of count + value for
// the selected range. Kept in sync via pull-to-refresh and a short live poll.
//
// NOTE: the backend order has no per-agent field yet, so this shows every
// delivered order platform-wide. See DeliveryApi.getDeliveredOrders.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../../theme/app_theme.dart' show AppShadows;
import '../../services/live_refresh.dart';
import '../../customer/customer_widgets.dart' show formatRupees, EmptyState;
import '../delivery_api.dart';
import '../delivery_models.dart';

/// Date ranges the history can be filtered by.
enum HistoryRange { today, week, month, all }

extension HistoryRangeX on HistoryRange {
  String get label => switch (this) {
        HistoryRange.today => 'Today',
        HistoryRange.week => 'This Week',
        HistoryRange.month => 'This Month',
        HistoryRange.all => 'All',
      };

  /// True when [when] falls inside this range (relative to now).
  bool contains(DateTime when) {
    final now = DateTime.now();
    return switch (this) {
      HistoryRange.today => when.year == now.year &&
          when.month == now.month &&
          when.day == now.day,
      HistoryRange.week =>
        when.isAfter(now.subtract(const Duration(days: 7))),
      HistoryRange.month =>
        when.year == now.year && when.month == now.month,
      HistoryRange.all => true,
    };
  }
}

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen>
    with LiveRefreshMixin {
  final DeliveryApi _api = DeliveryApi();

  List<DeliveredRecord> _all = [];
  bool _loaded = false;
  HistoryRange _range = HistoryRange.today;

  @override
  void initState() {
    super.initState();
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    _api.dispose();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _load();

  Future<void> _load() async {
    final list = await _api.getDeliveredOrders();
    if (!mounted) return;
    setState(() {
      if (list != null) _all = list;
      _loaded = true;
    });
  }

  List<DeliveredRecord> get _filtered =>
      _all.where((d) => _range.contains(d.deliveredAt)).toList();

  double get _totalValue =>
      _filtered.fold(0.0, (sum, d) => sum + d.amount);

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('My Deliveries',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          _filterBar(),
          _summaryCard(list.length),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: (!_loaded && _all.isEmpty)
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.5,
                              child: EmptyState(
                                icon: Icons.local_shipping_outlined,
                                title: 'No deliveries',
                                message:
                                    'No completed deliveries for "${_range.label}".',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _record(list[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final r in HistoryRange.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(r.label),
                selected: _range == r,
                showCheckmark: false,
                onSelected: (_) => setState(() => _range = r),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _range == r ? Colors.white : AppColors.darkText,
                ),
                backgroundColor: Colors.white,
                selectedColor: AppColors.primary,
                side: BorderSide(
                    color:
                        _range == r ? AppColors.primary : AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const Text('Deliveries',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
              width: 1, height: 34, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatRupees(_totalValue),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const Text('Order value',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _record(DeliveredRecord d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${_shortId(d.id)} · ${d.buyer}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${d.itemCount} items · ${_dateTime(d.deliveredAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
          Text(formatRupees(d.amount),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen)),
        ],
      ),
    );
  }

  String _dateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day} ${months[d.month - 1]}, $h:$m $ap';
  }

  static String _shortId(String id) {
    if (id.length <= 6) return id.toUpperCase();
    return id.substring(id.length - 6).toUpperCase();
  }
}
