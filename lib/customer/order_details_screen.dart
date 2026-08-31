// =============================================================================
// MediCaPlus — Order Details Screen
//
// Replaces the live-map tracking screen. Shows a status timeline, order info,
// delivery address, payment method, ordered items and an invoice summary, plus
// Reorder / Cancel actions.
//
// LIVE STATUS: the screen re-fetches the order from the backend (GET
// /get-order) on open, on pull-to-refresh, and on a short poll timer, so when
// the marketing/delivery team advances the order (Confirmed -> Shipped -> Out
// for Delivery -> Delivered) the customer's timeline updates without leaving
// the screen. All state still flows through OrdersController.byId(orderId).
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../services/live_refresh.dart';
import 'catalog.dart';
import 'customer_controllers.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'invoice_card.dart';
import '../shared/short_id.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    this.justPlaced = false,
  });

  final String orderId;

  /// When arriving straight from checkout we show a success banner.
  final bool justPlaced;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with LiveRefreshMixin {
  /// Backs the pull-to-refresh gesture. The order also auto-syncs via
  /// [LiveRefreshMixin], so the timeline stays live with no manual action.
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Pull the freshest order state on open, then keep it live via a short poll
    // and on app-resume. When the marketing/delivery team advances the order,
    // this screen's timeline updates on its own — no manual refresh needed.
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => OrdersController.instance.refresh();

  void _reorder(BuildContext context, Order order) {
    for (final item in order.items) {
      final match = Catalog.all.where((p) => p.title == item.title);
      if (match.isNotEmpty) {
        CartController.instance.add(match.first, quantity: item.quantity);
      }
    }
    showAppSnack(context, 'Items added to cart');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('Order Details',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        color: AppColors.primary,
        onRefresh: OrdersController.instance.refresh,
        child: ListenableBuilder(
          listenable: OrdersController.instance,
          builder: (context, _) {
            final order = OrdersController.instance.byId(widget.orderId);
            if (order == null) {
              // Keep it scrollable so pull-to-refresh still works while the
              // order is (re)loading or genuinely missing.
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: OrdersController.instance.isLoaded
                        ? const EmptyState(
                            icon: Icons.error_outline,
                            title: 'Order not found',
                            message:
                                'We could not find this order. It may have been removed.',
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                if (widget.justPlaced) _successBanner(),
                if (widget.justPlaced) const SizedBox(height: 16),
                _orderInfoCard(order),
                const SizedBox(height: 16),
                _card('Order Status', _timeline(order)),
                const SizedBox(height: 16),
                _card('Delivery Address', _addressBlock(order.address)),
                const SizedBox(height: 16),
                _card('Payment Method', _paymentBlock(order.paymentMethod)),
                const SizedBox(height: 16),
                _card('Ordered Items', _itemsBlock(order)),
                const SizedBox(height: 16),
                _card('Bill Summary', _invoiceBlock(order)),
                const SizedBox(height: 16),
                // BUSINESS RULE: the tax invoice is generated only when the
                // marketing team ACCEPTS the order. While it's pending there is
                // NO invoice — no button, no number — just a clear note.
                if (order.invoiceAvailable) ...[
                  InvoiceCard(order: order),
                  const SizedBox(height: 16),
                ] else if (order.status == OrderStatus.placed) ...[
                  _pendingInvoiceNote(),
                  const SizedBox(height: 16),
                ],
                _actions(context, order),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _successBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: const [
          Icon(Icons.check_circle, color: AppColors.primary, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order placed successfully!',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('You can track its progress below.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
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
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$m $ap';
  }

  Widget _orderInfoCard(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // "Order #" plus a 24-character ObjectId at 18/w800 is wider than
              // this card, so the row overflowed past the status pill. Showing
              // the last six (the short form Admin and Delivery already use)
              // fixes it at the source and matches the orders list, so the id
              // a user reads here is the one they just tapped. Expanded +
              // ellipsis stays as a guard for any longer id.
              Expanded(
                child: Text('Order #${shortId(order.id)}',
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.status.pillLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Placed on ${_dateTime(order.placedAt)}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
          const SizedBox(height: 4),
          Text('${order.totalUnits} units · ${order.items.length} products',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _timeline(Order order) {
    if (order.status == OrderStatus.cancelled) {
      return Row(
        children: const [
          Icon(Icons.cancel, color: AppColors.error),
          SizedBox(width: 10),
          Expanded(
            child: Text('This order was cancelled.',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    const steps = [
      OrderStatus.placed,
      OrderStatus.confirmed,
      OrderStatus.shipped,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    final currentIndex = steps.indexOf(order.status);

    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _timelineRow(
            label: steps[i].label,
            done: i <= currentIndex,
            current: i == currentIndex,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }

  Widget _timelineRow({
    required String label,
    required bool done,
    required bool current,
    required bool isLast,
  }) {
    final color = done ? AppColors.primary : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? AppColors.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    color: done ? AppColors.darkText : AppColors.greyText)),
          ),
        ],
      ),
    );
  }

  Widget _addressBlock(Address a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(a.label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text(a.phone,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyText)),
          ],
        ),
        const SizedBox(height: 4),
        Text(a.fullName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(a.formatted,
            style: const TextStyle(
                fontSize: 13, color: AppColors.greyText, height: 1.4)),
      ],
    );
  }

  Widget _paymentBlock(PaymentMethod m) {
    return Row(
      children: [
        Icon(m.icon, color: AppColors.darkGreen),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            Text(m.subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyText)),
          ],
        ),
      ],
    );
  }

  Widget _itemsBlock(Order order) {
    return Column(
      children: [
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      Text('${formatRupees(item.price)} × ${item.quantity}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.greyText)),
                    ],
                  ),
                ),
                Text(formatRupees(item.lineTotal),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _invoiceBlock(Order order) {
    Widget row(String l, String v, {bool bold = false, bool free = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color:
                          bold ? AppColors.darkGreen : AppColors.greyText)),
              Text(v,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: free
                          ? AppColors.primary
                          : bold
                              ? AppColors.darkGreen
                              : AppColors.darkText)),
            ],
          ),
        );

    return Column(
      children: [
        row('Subtotal', formatRupees(order.subtotal, decimals: true)),
        if (order.discount > 0)
          row('Discount', '- ${formatRupees(order.discount, decimals: true)}',
              free: true),
        row('Delivery',
            order.deliveryFee == 0 ? 'FREE' : formatRupees(order.deliveryFee),
            free: order.deliveryFee == 0),
        // Prices are GST-inclusive — old orders that stored an added-on-top
        // GST amount still show it, new ones show "Included in price".
        row(
            'GST',
            order.gst > 0
                ? formatRupees(order.gst, decimals: true)
                : 'Included in price'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: AppColors.border, height: 1),
        ),
        row('Total Paid', formatRupees(order.total, decimals: true),
            bold: true),
      ],
    );
  }

  /// Shown in place of the invoice card while the order awaits marketing
  /// approval — the invoice does not exist yet, so nothing invoice-shaped
  /// (button / number / placeholder) is rendered.
  Widget _pendingInvoiceNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: const [
          Icon(Icons.hourglass_top_rounded,
              color: Color(0xFFF59E0B), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending approval',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text(
                  'Your tax invoice will be generated once the order is '
                  'accepted by our team.',
                  style: TextStyle(fontSize: 12, color: AppColors.greyText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context, Order order) async {
    final ok = await OrdersController.instance.cancel(order.id);
    if (!context.mounted) return;
    showAppSnack(
      context,
      ok
          ? 'Order cancelled — any reserved stock has been released'
          : 'Order cancelled on this device. We could not reach the server — '
              'it will sync when you are back online.',
      success: false,
    );
  }

  Widget _actions(BuildContext context, Order order) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            label: 'Reorder',
            icon: Icons.refresh,
            onPressed: () => _reorder(context, order),
          ),
        ),
        // Cancellation is allowed only BEFORE delivery (and not while it's on
        // the rider) — delivered/cancelled orders hide the action entirely.
        if (order.status.isActive && order.status != OrderStatus.outForDelivery) ...[
          const SizedBox(width: 12),
          Expanded(
            child: SecondaryButton(
              label: 'Cancel Order',
              icon: Icons.close,
              onPressed: () => _cancelOrder(context, order),
            ),
          ),
        ],
      ],
    );
  }
}

