// =============================================================================
// VS Arogya — Area Agent · Dashboard (portal home)
//
// Where a signed-in Area Agent lands. The agent's whole job: see the orders in
// their assigned pincode (filtered by the customer's DELIVERY-address pincode),
// and tap one to view its status + line items. Read-only monitoring — no actions
// on the order. UI-only for now — data comes from AgentOrderMock, scoped to the
// agent's pincode (AgentSession).
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../customer/customer_widgets.dart' show formatRupees;
import '../auth/session.dart' show logout;
import 'agent_session.dart';
import 'agent_mock.dart';
import 'agent_order_detail.dart';

class AgentMain extends StatelessWidget {
  const AgentMain({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AgentSession.instance;
    final pincode = session.pincode;
    final orders = AgentOrderMock.ordersForPincode(pincode);

    final pending = orders
        .where((o) => o.status == AgentOrderStatus.pending)
        .length;
    final delivered = orders
        .where((o) => o.status == AgentOrderStatus.delivered)
        .length;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context, session.name, pincode),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.receipt_long_outlined,
                    value: '${orders.length}',
                    label: 'Total Orders',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.hourglass_bottom_rounded,
                    value: '$pending',
                    label: 'Pending',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.check_circle_outline,
                    value: '$delivered',
                    label: 'Delivered',
                    color: AppColors.darkGreen,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              pincode.isEmpty ? 'Orders' : 'Orders · $pincode',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText),
            ),
          ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text('No orders in this pincode right now.',
                  style: TextStyle(color: AppColors.greyText)),
            )
          else
            ...orders.map((o) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _OrderRow(
                    order: o,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AgentOrderDetailScreen(order: o),
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String name, String pincode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Area Agent',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (pincode.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('Pincode $pincode',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => logout(context),
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Logout',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final AgentOrder order;
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.darkGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.darkText)),
                  const SizedBox(height: 2),
                  Text(
                      '#${order.id} · ${order.itemCount} items · ${order.placedAgo}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.greyText)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatRupees(order.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.darkText)),
                const SizedBox(height: 4),
                _StatusPill(status: order.status),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AgentOrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: status.color)),
    );
  }
}
