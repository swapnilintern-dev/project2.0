// =============================================================================
// MediCaPlus — Orders Screen
//
// Filterable order history (All / Active / Delivered / Cancelled) with order
// cards that open the Order Details screen and a one-tap Reorder action.
// Embedded as a tab inside the shell.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import 'catalog.dart';
import 'customer_controllers.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderFilter _filter = OrderFilter.all;

  @override
  void initState() {
    super.initState();
    OrdersController.instance.ensureSeeded();
    // Pull the latest orders from the backend (falls back to the seed on fail).
    unawaited(OrdersController.instance.refresh());
  }

  void _reorder(Order order) {
    for (final item in order.items) {
      // Resolve a catalogue product by title so the cart holds a real Product.
      final match = Catalog.all.where((p) => p.title == item.title);
      if (match.isNotEmpty) {
        CartController.instance.add(match.first, quantity: item.quantity);
      }
    }
    showAppSnack(context, 'Items added to cart');
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: OrdersController.instance,
      builder: (context, _) {
        final orders = OrdersController.instance.byFilter(_filter);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, widget.embedded ? 16 : 8, 20, 8),
              child: const Text('My Orders',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in OrderFilter.values) _filterChip(f),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: orders.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No ${_filter == OrderFilter.all ? '' : _filter.label.toLowerCase()} orders',
                      message:
                          'When you place an order it will appear here for tracking and reordering.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _OrderCard(order: orders[i], onReorder: _reorder),
                    ),
            ),
          ],
        );
      },
    );

    if (widget.embedded) return SafeArea(child: content);
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('My Orders',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: content,
    );
  }

  Widget _filterChip(OrderFilter f) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(f.label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = f),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.darkText,
        ),
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onReorder});

  final Order order;
  final void Function(Order) onReorder;

  String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(orderId: order.id)),
      ),
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
          children: [
            Row(
              children: [
                Text('#${order.id}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const Spacer(),
                _statusPill(order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(_date(order.placedAt),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyText)),
            const SizedBox(height: 10),
            Text(order.summaryLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${order.totalUnits} units',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyText)),
            const Divider(height: 22, color: AppColors.border),
            Row(
              children: [
                Text(formatRupees(order.total),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGreen)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onReorder(order),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reorder'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: status.color)),
    );
  }
}
