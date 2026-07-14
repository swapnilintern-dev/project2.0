// =============================================================================
// VS Arogya — Outlet Staff · Orders
//
// The Orders tab: every order for this outlet, newest first, with a status
// filter. Tap a row to open its detail. Wired to [OutletRepository] (mock).
// Reloads on open and on pull-to-refresh; the shell also re-keys this screen
// when the Orders tab is selected so freshly created orders appear.
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_enums.dart';
import '../outlet_models.dart';
import '../outlet_repository.dart';
import '../outlet_session.dart';
import '../outlet_theme.dart';
import 'outlet_order_detail_screen.dart';

/// Coarse status buckets for the filter chips.
enum _OrderFilter { all, awaiting, paid, fulfilled, cancelled }

extension _FilterX on _OrderFilter {
  String get label => switch (this) {
        _OrderFilter.all => 'All',
        _OrderFilter.awaiting => 'Awaiting',
        _OrderFilter.paid => 'Paid',
        _OrderFilter.fulfilled => 'Fulfilled',
        _OrderFilter.cancelled => 'Cancelled',
      };

  bool matches(OutletOrderStatus s) => switch (this) {
        _OrderFilter.all => true,
        _OrderFilter.awaiting => s.isAwaitingPayment,
        _OrderFilter.paid => s == OutletOrderStatus.paid,
        _OrderFilter.fulfilled => s == OutletOrderStatus.handedOver ||
            s == OutletOrderStatus.readyForPickup ||
            s == OutletOrderStatus.outForDelivery ||
            s == OutletOrderStatus.delivered,
        _OrderFilter.cancelled => s.isReleased,
      };
}

class OutletOrdersScreen extends StatefulWidget {
  const OutletOrdersScreen({super.key});

  @override
  State<OutletOrdersScreen> createState() => _OutletOrdersScreenState();
}

class _OutletOrdersScreenState extends State<OutletOrdersScreen> {
  final _repo = OutletRepository();
  late Future<List<OutletOrder>> _future;
  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchOrders();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.fetchOrders());
    await _future;
  }

  Future<void> _open(OutletOrder o) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OutletOrderDetailScreen(order: o)),
    );
    await _refresh(); // status may have changed in detail/payment
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutletHeader(title: 'Orders', subtitle: OutletSession.instance.outletLabel),
        _filterChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: OutletColors.success,
            child: FutureBuilder<List<OutletOrder>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child:
                          CircularProgressIndicator(color: OutletColors.success),
                    ),
                  );
                }
                final all = snap.data ?? const [];
                final rows =
                    all.where((o) => _filter.matches(o.status)).toList();
                if (rows.isEmpty) return _empty();
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _orderCard(rows[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          for (final f in _OrderFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _filter == f
                        ? OutletColors.badgeGreenBg
                        : OutletColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filter == f
                          ? OutletColors.success
                          : OutletColors.border,
                    ),
                  ),
                  child: Text(
                    f.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _filter == f
                          ? OutletColors.success
                          : OutletColors.textMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orderCard(OutletOrder o) {
    final (bg, fg) = _statusColors(o.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(o),
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: OutletColors.badgeGreenBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  o.type == OutletOrderType.delivery
                      ? Icons.local_shipping_outlined
                      : Icons.storefront_outlined,
                  color: OutletColors.grad1,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            o.customer.name.isEmpty
                                ? 'Walk-in customer'
                                : o.customer.name,
                            style: OutletTextStyles.prodName,
                          ),
                        ),
                        Text('₹${o.total.toStringAsFixed(0)}',
                            style: OutletTextStyles.prodName),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${o.id} · ${o.itemCount} item(s) · ${o.type.label}',
                            style: OutletTextStyles.prodSub,
                          ),
                        ),
                        OutletBadge(label: o.status.label, bg: bg, fg: fg),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 42, color: OutletColors.textMuted),
              const SizedBox(height: 12),
              Text(
                _filter == _OrderFilter.all
                    ? 'No orders yet'
                    : 'No ${_filter.label.toLowerCase()} orders',
                style: OutletTextStyles.prodName,
              ),
              const SizedBox(height: 2),
              const Text('Create a manual order from the Home tab',
                  style: OutletTextStyles.prodSub),
            ],
          ),
        ),
      ],
    );
  }

  (Color, Color) _statusColors(OutletOrderStatus s) {
    if (s.isReleased) return (OutletColors.badgeRedBg, OutletColors.danger);
    if (s.isPaid) return (OutletColors.badgeGreenBg, OutletColors.success);
    return (OutletColors.badgeAmberBg, OutletColors.amber);
  }
}
