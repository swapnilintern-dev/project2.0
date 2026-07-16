// =============================================================================
// VS Arogya — Area Agent · Order Detail
//
// Read-only view the agent opens from the dashboard. Shows the order's status
// as a lifecycle timeline (pending → confirmed → out for delivery → delivered),
// the customer's delivery address (the field the list is filtered on), and the
// line items — which medicine and how much quantity. No actions: the agent only
// monitors. UI-only; data is the mock AgentOrder passed in.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../customer/customer_widgets.dart' show formatRupees;
import 'agent_mock.dart';

class AgentOrderDetailScreen extends StatelessWidget {
  const AgentOrderDetailScreen({super.key, required this.order});

  final AgentOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Order #${order.id}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _statusCard(),
          const SizedBox(height: 14),
          _deliveryCard(),
          const SizedBox(height: 14),
          _itemsCard(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  Widget _statusCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Order status',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              const Spacer(),
              _statusPill(order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text('Placed ${order.placedAgo}',
              style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
          const SizedBox(height: 14),
          _timeline(),
        ],
      ),
    );
  }

  Widget _timeline() {
    final current = order.status.index;
    const steps = AgentOrderStatus.values;
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _timelineStep(
            label: steps[i].label,
            done: i <= current,
            isCurrent: i == current,
            isLast: i == steps.length - 1,
            color: steps[i].color,
          ),
      ],
    );
  }

  Widget _timelineStep({
    required String label,
    required bool done,
    required bool isCurrent,
    required bool isLast,
    required Color color,
  }) {
    final dotColor = done ? color : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: done ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? color : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                color: done ? AppColors.darkText : AppColors.greyText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delivery
  // ---------------------------------------------------------------------------

  Widget _deliveryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery address',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline, size: 18, color: AppColors.greyText),
              const SizedBox(width: 8),
              Text(order.customerName,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: AppColors.greyText),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${order.deliveryAddress} — ${order.deliveryPincode}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.darkText, height: 1.3)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------

  Widget _itemsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Medicines (${order.itemCount} items)',
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 10),
          for (int i = 0; i < order.lines.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _lineRow(order.lines[i]),
          ],
          const Divider(height: 20, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              Text(formatRupees(order.amount),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineRow(AgentOrderLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                if (line.packSize.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(line.packSize,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.greyText)),
                ],
              ],
            ),
          ),
          // Quantity is the headline for the agent ("kitna stock gaya").
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Qty ${line.qty}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(formatRupees(line.lineTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _statusPill(AgentOrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: status.color)),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
