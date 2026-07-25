// =============================================================================
// VS Arogya — Outlet Staff · Order Detail
//
// Full view of one order: status, customer, line items, total, and the actions
// available for its current state:
//   • AWAITING_PAYMENT → Collect payment (opens the Payment screen).
//   • PAID + COUNTER   → Mark handed over.
//   • PAID + DELIVERY  → Mark ready for pickup (a delivery agent takes it from
//                        there — Step 9).
// All state changes go through the server-owned status (locked rule #3); this
// screen re-reads the order after every action instead of assuming success.
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_enums.dart';
import '../outlet_models.dart';
import '../outlet_repository.dart';
import '../outlet_theme.dart';
import '../../services/live_refresh.dart';
import 'outlet_invoice_screen.dart';
import 'outlet_payment_screen.dart';

class OutletOrderDetailScreen extends StatefulWidget {
  const OutletOrderDetailScreen({super.key, required this.order});

  final OutletOrder order;

  @override
  State<OutletOrderDetailScreen> createState() =>
      _OutletOrderDetailScreenState();
}

class _OutletOrderDetailScreenState extends State<OutletOrderDetailScreen>
    with LiveRefreshMixin {
  final _repo = OutletRepository();
  late OutletOrder _order = widget.order;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Keep the order status live (poll + app-resume) so a payment/status change
    // made elsewhere surfaces here on its own — no manual refresh.
    startLiveRefresh(immediate: false);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _refresh();

  Future<void> _refresh() async {
    try {
      final fresh = await _repo.fetchOrder(_order.id);
      if (mounted) setState(() => _order = fresh);
    } catch (_) {/* keep current */}
  }

  Future<void> _collectPayment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OutletPaymentScreen(order: _order)),
    );
    // Payment screen owns status transitions; re-read on return.
    await _refresh();
  }

  Future<void> _advance(OutletOrderStatus to) async {
    setState(() => _busy = true);
    try {
      final updated = await _repo.advanceOrder(_order.id, to);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${updated.status.label.toLowerCase()}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      backgroundColor: OutletColors.bg,
      appBar: AppBar(
        backgroundColor: OutletColors.grad1,
        foregroundColor: Colors.white,
        title: Text('Order ${o.id}'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'View invoice',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OutletInvoiceScreen(
                    orderId: o.id, buyer: o.customer.name),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: OutletColors.success,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _statusRow(),
            const SizedBox(height: 14),
            _customerCard(),
            const SizedBox(height: 14),
            _itemsCard(),
            const SizedBox(height: 14),
            _timelineCard(),
            const SizedBox(height: 18),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _statusRow() {
    final (bg, fg) = _statusColors(_order.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(_statusIcon(_order.status), color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_order.status.label,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
                const SizedBox(height: 2),
                Text('${_order.type.label} · ${_order.paymentMethod.label}',
                    style: TextStyle(fontSize: 12, color: fg)),
              ],
            ),
          ),
          Text('₹${_order.total.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  Widget _customerCard() {
    final c = _order.customer;
    return _card(
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(Icons.person_outline, c.name.isEmpty ? 'Walk-in' : c.name),
          const SizedBox(height: 8),
          _kv(Icons.phone_outlined, c.phone.isEmpty ? '—' : c.phone),
          if (c.hasAddress) ...[
            const SizedBox(height: 8),
            _kv(Icons.location_on_outlined, c.address!),
          ],
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return _card(
      title: 'Items (${_order.itemCount})',
      child: Column(
        children: [
          for (final l in _order.lines) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.name, style: OutletTextStyles.prodName),
                      const SizedBox(height: 2),
                      Text(
                        '${l.qty} × ₹${l.price.toStringAsFixed(0)}'
                        '${l.packSize.isNotEmpty ? ' · ${l.packSize}' : ''}',
                        style: OutletTextStyles.prodSub,
                      ),
                    ],
                  ),
                ),
                Text('₹${l.lineTotal.toStringAsFixed(0)}',
                    style: OutletTextStyles.prodName),
              ],
            ),
            if (l != _order.lines.last)
              const Divider(height: 18, color: OutletColors.border),
          ],
          const Divider(height: 22, color: OutletColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: OutletTextStyles.prodName),
              Text('₹${_order.total.toStringAsFixed(2)}',
                  style: OutletTextStyles.statNum),
            ],
          ),
        ],
      ),
    );
  }

  /// A compact lifecycle timeline: which stages this order has reached.
  Widget _timelineCard() {
    final steps = <OutletOrderStatus>[
      OutletOrderStatus.awaitingPayment,
      OutletOrderStatus.paid,
      if (_order.type == OutletOrderType.counter)
        OutletOrderStatus.handedOver
      else ...[
        OutletOrderStatus.readyForPickup,
        OutletOrderStatus.outForDelivery,
        OutletOrderStatus.delivered,
      ],
    ];
    final currentIdx = steps.indexOf(_order.status);
    // Released orders (cancelled/expired) short-circuit the timeline.
    final released = _order.status.isReleased;

    return _card(
      title: 'Progress',
      child: released
          ? _kv(Icons.cancel_rounded, 'Order ${_order.status.label.toLowerCase()}',
              color: OutletColors.danger)
          : Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _timelineRow(
                    steps[i].label,
                    done: currentIdx >= 0 && i <= currentIdx,
                    isLast: i == steps.length - 1,
                  ),
              ],
            ),
    );
  }

  Widget _timelineRow(String label, {required bool done, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: done ? OutletColors.success : OutletColors.textMuted,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 20,
                color: done ? OutletColors.success : OutletColors.border,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              color: done ? OutletColors.textDark : OutletColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  /// Status panel for an order the team fulfils. Shows the SERVER's own status
  /// word rather than the outlet-vocabulary approximation, so staff read what
  /// actually happened.
  Widget _teamFulfilledNote(OutletOrder o) {
    final label =
        o.serverStatusLabel.isEmpty ? o.status.label : o.serverStatusLabel;
    final done = o.status == OutletOrderStatus.delivered;
    final stopped = o.status == OutletOrderStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            stopped
                ? Icons.cancel_outlined
                : done
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_bottom_rounded,
            size: 20,
            color: stopped
                ? OutletColors.danger
                : done
                    ? OutletColors.success
                    : OutletColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $label',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: OutletColors.textDark)),
                const SizedBox(height: 3),
                Text(
                  stopped
                      ? 'This order was cancelled.'
                      : done
                          ? 'Delivered to ${o.customer.name}.'
                          : 'Placed for ${o.customer.name}. The team confirms, '
                              'invoices and delivers it — nothing to do here.',
                  style: const TextStyle(
                      fontSize: 12, height: 1.35, color: OutletColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final o = _order;
    // Placed for a vendor through the manual-order API: the team confirms,
    // invoices and delivers it. "Collect payment" is impossible here
    // (/create-payment 403s — the order belongs to the vendor, not us) and
    // "mark handed over" isn't ours to do. Show what's happening instead.
    if (o.teamFulfilled) return _teamFulfilledNote(o);
    if (o.isAwaitingPayment) {
      return _GradientButton(
        icon: Icons.qr_code_2_rounded,
        label: 'Collect payment',
        onTap: _collectPayment,
      );
    }
    if (o.status == OutletOrderStatus.paid) {
      final isCounter = o.type == OutletOrderType.counter;
      return _GradientButton(
        icon: isCounter ? Icons.check_circle_rounded : Icons.inventory_2_rounded,
        label: isCounter ? 'Mark handed over' : 'Mark ready for pickup',
        loading: _busy,
        onTap: _busy
            ? null
            : () => _advance(isCounter
                ? OutletOrderStatus.handedOver
                : OutletOrderStatus.readyForPickup),
      );
    }
    // readyForPickup / outForDelivery / delivered / terminal → no staff action.
    final msg = o.status.isReleased
        ? 'This order was ${o.status.label.toLowerCase()} and stock was released.'
        : o.status == OutletOrderStatus.handedOver
            ? 'Handed over to the customer. Nothing more to do.'
            : 'With the delivery team now (${o.status.label.toLowerCase()}).';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: OutletColors.textMid, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: OutletTextStyles.prodSub)),
        ],
      ),
    );
  }

  // --- helpers ---------------------------------------------------------------

  Widget _card({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OutletColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: OutletColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: OutletTextStyles.sectionTitle),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _kv(IconData icon, String value, {Color? color}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color ?? OutletColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: color ?? OutletColors.textDark,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );

  (Color, Color) _statusColors(OutletOrderStatus s) {
    if (s.isReleased) return (OutletColors.badgeRedBg, OutletColors.danger);
    if (s.isPaid) return (OutletColors.badgeGreenBg, OutletColors.success);
    return (OutletColors.badgeAmberBg, OutletColors.amber);
  }

  IconData _statusIcon(OutletOrderStatus s) {
    if (s.isReleased) return Icons.cancel_rounded;
    if (s == OutletOrderStatus.awaitingPayment) {
      return Icons.hourglass_bottom_rounded;
    }
    return Icons.verified_rounded;
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: OutletColors.headerGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.white, size: 19),
                        const SizedBox(width: 8),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
