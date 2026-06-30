// =============================================================================
// MediCaPlus — Marketing Head · Orders tab
//
// Incoming orders with status filter tabs (New / Packing / Ready / Shipped /
// Done), a search bar + filter icon, and order cards with a contextual action
// button (Accept, Pack, Ship …) that advances the order through the pipeline.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart'
    show formatRupees, showAppSnack, EmptyState;
import 'marketing_controllers.dart';
import 'marketing_models.dart';
import 'order_details_screen.dart';

class MarketingOrdersScreen extends StatefulWidget {
  const MarketingOrdersScreen({super.key});

  @override
  State<MarketingOrdersScreen> createState() => _MarketingOrdersScreenState();
}

class _MarketingOrdersScreenState extends State<MarketingOrdersScreen> {
  MarketingOrderStatus _filter = MarketingOrderStatus.pending;
  String _query = '';

  MarketingOrdersController get _controller => MarketingOrdersController.instance;

  @override
  void initState() {
    super.initState();
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _header(),
          _statusTabs(),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                var orders = _controller.byStatus(_filter);
                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  orders = orders
                      .where((o) =>
                          o.id.toLowerCase().contains(q) ||
                          o.buyer.toLowerCase().contains(q))
                      .toList();
                }
                if (orders.isEmpty) {
                  return EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No ${_filter.label} orders',
                    message: _query.isEmpty
                        ? 'Orders in this stage will appear here.'
                        : 'No orders match "$_query".',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _OrderCard(
                    order: orders[i],
                    onAction: () => _onAction(orders[i]),
                    onDetails: () => _onDetails(orders[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onAction(MarketingOrder order) {
    final next = order.status.next;
    _controller.advance(order.id);
    if (next != null) {
      showAppSnack(context, 'Order ${order.id} moved to ${next.label}');
    }
  }

  void _onDetails(MarketingOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id)),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
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
          const Text('MedSupply Co.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          const Text('Orders',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search order ID, buyer…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: () =>
                      showAppSnack(context, 'Filters coming soon', success: true),
                  icon: const Icon(Icons.tune, color: Colors.white),
                  tooltip: 'Filter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTabs() {
    return SizedBox(
      height: 52,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final status in MarketingOrderStatus.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _StatusTab(
                    label: status.label,
                    count: _controller.countByStatus(status),
                    selected: _filter == status,
                    onTap: () => setState(() => _filter = status),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          count > 0 ? '$label ($count)' : label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.greyText,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onAction,
    required this.onDetails,
  });

  final MarketingOrder order;
  final VoidCallback onAction;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: order.urgent ? AppColors.error : AppColors.border,
          width: order.urgent ? 1.4 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${order.id}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.darkText)),
              const SizedBox(width: 8),
              if (order.urgent) _pill('Urgent', AppColors.error),
              const Spacer(),
              if (order.isNew)
                _pill('New', MarketingColors.orange)
              else
                _pill(order.status.label, order.status.color),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.lightGreenBg,
                child: Text(order.initials,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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
                            fontSize: 14,
                            color: AppColors.darkText)),
                    const SizedBox(height: 2),
                    Text(
                      '${order.itemCount} items · ${order.unitCount} units · ${order.timeAgo}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.greyText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(formatRupees(order.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.darkGreen)),
              const Spacer(),
              OutlinedButton(
                onPressed: onDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGreen,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Details',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (order.status.actionLabel != null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(order.status.actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );
}
