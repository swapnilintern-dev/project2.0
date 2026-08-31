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
import 'invoice_screen.dart';
import '../shared/short_id.dart';

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
              // BUSINESS RULE: the invoice exists only once the order has been
              // ACCEPTED — Pending / Cancelled orders show no invoice at all.
              if (_invoiceAvailable(order.status)) ...[
                const SizedBox(height: 14),
                _invoiceCard(context, order),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final order = _controller.byId(orderId);
          if (order == null) return const SizedBox.shrink();
          final action = order.status.actionLabel;
          final cancellable = _cancellable(order.status);
          if (action == null && !cancellable) return const SizedBox.shrink();
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action != null)
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _onAdvance(context, order),
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
                if (action != null && cancellable) const SizedBox(height: 8),
                // Staff cancel — allowed only BEFORE delivery. The backend
                // restores any deducted stock (see MarketingOrdersApi contract).
                if (cancellable)
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _onCancel(context, order),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel Order',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The invoice is generated at ACCEPT time — visible from Confirmed onwards.
  static bool _invoiceAvailable(MarketingOrderStatus s) => switch (s) {
        MarketingOrderStatus.confirmed ||
        MarketingOrderStatus.shipped ||
        MarketingOrderStatus.outForDelivery ||
        MarketingOrderStatus.delivered =>
          true,
        _ => false,
      };

  /// Staff may cancel any order BEFORE it is delivered (never after).
  static bool _cancellable(MarketingOrderStatus s) =>
      s != MarketingOrderStatus.delivered &&
      s != MarketingOrderStatus.cancelled;

  Future<void> _onAdvance(BuildContext context, MarketingOrder order) async {
    // Shipped -> Out for Delivery: pick a real delivery agent.
    if (order.status.next == MarketingOrderStatus.outForDelivery) {
      final agent = await showAssignAgentSheet(context, order);
      if (agent == null || !context.mounted) return;
      final err = await _controller.assignAgent(order.id, agent);
      if (!context.mounted) return;
      showAppSnack(
        context,
        err ?? 'Assigned to ${agent.name} · Out for Delivery',
        success: err == null,
      );
      return;
    }
    final next = order.status.next;
    if (next == null) return;
    // Awaited: an Accept that fails the server's stock check rolls back and
    // shows the exact reason (e.g. "Insufficient stock for <product>…").
    final err = await _controller.advance(order.id);
    if (!context.mounted) return;
    showAppSnack(
      context,
      err ?? 'Order ${order.id} moved to ${next.label}',
      success: err == null,
    );
  }

  Future<void> _onCancel(BuildContext context, MarketingOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Order #${order.id} for ${order.buyer} will be cancelled. Any stock '
          'reserved for it will be added back to inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final err = await _controller.cancelOrder(order.id);
    if (!context.mounted) return;
    showAppSnack(
      context,
      err ?? 'Order cancelled — stock restored to inventory',
      success: err == null,
    );
  }

  /// "View Invoice" card, shown once the order has been accepted. Opens the
  /// server-generated invoice PDF (preview + share/print) — the same document
  /// the vendor sees in their panel.
  Widget _invoiceCard(BuildContext context, MarketingOrder order) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tax Invoice',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
                SizedBox(height: 2),
                Text('Generated when the order was accepted',
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.greyText)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StaffInvoiceScreen(
                  orderId: order.id,
                  buyer: order.buyer,
                ),
              ),
            ),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('View',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkGreen,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
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
              // A 24-char ObjectId at 18/w800 is wider than this card, and a
              // Spacer only hands out space that is already left over — so the
              // row overflowed past the pill. Short form fixes it at the source.
              Expanded(
                child: Text('#${shortId(order.id)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
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
              // Audit badge: keyed in by marketing on the vendor's behalf.
              if (order.isManual)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MarketingColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Manual',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: MarketingColors.blue)),
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
