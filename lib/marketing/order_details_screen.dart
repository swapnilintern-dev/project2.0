// =============================================================================
// MediCaPlus — Marketing Head · Order Details screen
//
// Pushed from the Orders tab "Details" button. Shows the full order placed by
// the customer: buyer + delivery info, every purchased line item, a bill
// summary and the contextual pipeline action (Accept / Pack / Ship …) which
// advances the order live and reflects the new status in-place.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart' show formatRupees, showAppSnack;
import 'marketing_controllers.dart';
import 'marketing_models.dart';
import 'assign_agent_sheet.dart';

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  MarketingOrdersController get _controller => MarketingOrdersController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('Order Details',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final order = _controller.byId(orderId);
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _summaryHeader(order),
              const SizedBox(height: 14),
              _buyerCard(order),
              if (_controller.assignedAgentFor(order.id) != null) ...[
                const SizedBox(height: 14),
                _agentCard(_controller.assignedAgentFor(order.id)!),
              ],
              const SizedBox(height: 14),
              _sectionTitle('Items Ordered (${order.itemCount})'),
              const SizedBox(height: 8),
              _itemsCard(order),
              const SizedBox(height: 14),
              _sectionTitle('Bill Summary'),
              const SizedBox(height: 8),
              _billCard(order),
              const SizedBox(height: 14),
              _paymentCard(order),
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final order = _controller.byId(orderId);
          final action = order?.status.actionLabel;
          if (order == null || action == null) return const SizedBox.shrink();
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Shipped -> Out for Delivery: pick a real delivery agent.
                  if (order.status.next ==
                      MarketingOrderStatus.outForDelivery) {
                    final agent = await showAssignAgentSheet(context, order);
                    if (agent == null || !context.mounted) return;
                    _controller.assignAgent(order.id, agent);
                    showAppSnack(context,
                        'Assigned to ${agent.name} · Out for Delivery');
                    return;
                  }
                  final next = order.status.next;
                  _controller.advance(order.id);
                  if (next != null) {
                    showAppSnack(
                        context, 'Order ${order.id} moved to ${next.label}');
                  }
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text('$action Order',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _summaryHeader(MarketingOrder order) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${order.id}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.status.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Placed ${order.timeAgo}',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _headerStat('${order.itemCount}', 'Items'),
              _headerDivider(),
              _headerStat('${order.unitCount}', 'Units'),
              _headerDivider(),
              _headerStat(formatRupees(order.amount), 'Total'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ],
        ),
      );

  Widget _headerDivider() => Container(
        width: 1,
        height: 30,
        color: Colors.white.withValues(alpha: 0.25),
      );

  Widget _buyerCard(MarketingOrder order) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.lightGreenBg,
                child: Text(order.initials,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGreen)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.buyer,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.darkText)),
                    const SizedBox(height: 2),
                    Text('Order #${order.id}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.greyText)),
                  ],
                ),
              ),
              if (order.urgent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Urgent',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error)),
                ),
            ],
          ),
          const Divider(height: 24, color: AppColors.border),
          _infoRow(Icons.phone_outlined, 'Phone', order.phone),
          const SizedBox(height: 10),
          _infoRow(Icons.location_on_outlined, 'Delivery address', order.address),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.greyText)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemsCard(MarketingOrder order) {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < order.items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(order.items[i].icon,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.items[i].name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.darkText)),
                        const SizedBox(height: 2),
                        Text(
                          '${order.items[i].brand} · ${formatRupees(order.items[i].price)} × ${order.items[i].quantity}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.greyText),
                        ),
                      ],
                    ),
                  ),
                  Text(formatRupees(order.items[i].lineTotal),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.darkGreen)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _billCard(MarketingOrder order) {
    return _card(
      child: Column(
        children: [
          _billRow('Subtotal', formatRupees(order.subtotal)),
          const SizedBox(height: 8),
          _billRow('Taxes & fees', formatRupees(order.taxesAndFees)),
          const Divider(height: 20, color: AppColors.border),
          _billRow('Grand Total', formatRupees(order.amount), bold: true),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 15 : 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? AppColors.darkText : AppColors.greyText)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13.5,
                fontWeight: FontWeight.w800,
                color: bold ? AppColors.darkGreen : AppColors.darkText)),
      ],
    );
  }

  Widget _paymentCard(MarketingOrder order) {
    return _card(
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Text('Payment',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyText)),
          const Spacer(),
          Text(order.paymentTerm.isEmpty ? 'Not specified' : order.paymentTerm,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
        ],
      ),
    );
  }

  /// The assigned delivery agent, shown once marketing has picked one.
  Widget _agentCard(String agentName) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: MarketingColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.two_wheeler_outlined,
                color: MarketingColors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery Agent',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.greyText)),
                const SizedBox(height: 2),
                Text(agentName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.darkText));

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}
