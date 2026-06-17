// =============================================================================
// MediCaPlus — Admin · All Orders (tab 2)
//
// Marketplace-wide order monitor. Status segment tabs (All / Processing /
// Transit / Delivered / Disputed), search across id / buyer / vendor, and order
// cards showing the buyer → vendor flow, amount and a contextual action
// (Track, or Resolve Dispute → opens the dispute screen).
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'dispute_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  // TODO: GET /api/admin/orders
  final List<AdminOrder> _orders = kOrders;
  int _tab = 0;
  String _query = '';

  static const _tabs = ['All', 'Processing', 'Transit', 'Delivered', 'Disputed'];

  List<AdminOrder> get _filtered {
    Iterable<AdminOrder> list = _orders;
    if (_tab > 0) {
      final status = switch (_tab) {
        1 => AdminOrderStatus.processing,
        2 => AdminOrderStatus.transit,
        3 => AdminOrderStatus.delivered,
        _ => AdminOrderStatus.disputed,
      };
      list = list.where((o) => o.status == status);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((o) =>
          o.id.toLowerCase().contains(q) ||
          o.buyer.toLowerCase().contains(q) ||
          o.vendor.toLowerCase().contains(q));
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AdminScreenHeader(
              title: 'All Orders',
              subtitle: '14,208 total · 642 today',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AdminSearchField(
                hint: 'Order ID, buyer, vendor…',
                onChanged: (v) => setState(() => _query = v),
                onFilter: () => adminSnack(context, 'Filters'),
              ),
            ),
            AdminSegmentTabs(
              tabs: _tabs,
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const AdminEmpty(label: 'No orders here')
                  : ListView.builder(
                      physics: adminScroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _OrderCard(
                        order: list[i],
                        onTrack: () =>
                            adminSnack(context, 'Tracking #${list[i].id}'),
                        onResolve: () => adminPush(
                            context, const DisputeScreen(dispute: kSampleDispute)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTrack,
    required this.onResolve,
  });

  final AdminOrder order;
  final VoidCallback onTrack;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final disputed = order.status == AdminOrderStatus.disputed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: adminCard(
        borderColor: disputed ? AdminColors.red.withValues(alpha: 0.45) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${order.id}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              const Spacer(),
              StatusBadge(label: order.status.label, color: order.status.color),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _party(Icons.shopping_bag_outlined, order.buyer),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: AppColors.greyText),
              ),
              Expanded(
                child: _party(Icons.storefront_outlined, order.vendor),
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.border),
          Row(
            children: [
              Text('${order.items} items',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.greyText)),
              const Spacer(),
              Text(money(order.amount),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: disputed
                ? AdminButton(
                    label: 'Resolve Dispute',
                    icon: Icons.gavel_outlined,
                    color: AdminColors.red,
                    height: 40,
                    expand: false,
                    onPressed: onResolve,
                  )
                : TextButton(
                    onPressed: onTrack,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.lighterGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Track →',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _party(IconData icon, String name) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.greyText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
        ),
      ],
    );
  }
}
