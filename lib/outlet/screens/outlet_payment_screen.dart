// =============================================================================
// VS Arogya — Outlet Staff · Payment
//
// Shown after a manual order is created (AWAITING_PAYMENT). Offers BOTH ways to
// collect the walk-in customer's Razorpay payment:
//   • a scannable QR + a payment link the customer pays on THEIR phone, and
//   • a "Pay on this device" razorpay_flutter checkout sheet (reuses the app's
//     existing order-first → open → verify pattern from checkout_screen.dart).
//
// LOCKED RULE #3: the client NEVER marks the order paid. Whatever Razorpay's
// on-device success callback says, we only send it to the server to verify and
// then keep POLLING the server-owned status every 3 seconds. The order flips to
// PAID solely because the server says so. Only once PAID do the terminal action
// buttons (hand over / ready for pickup) appear.
//
// The checkout itself lives in [OutletRazorpayCheckout] — the one place the
// whole outlet role runs the order-first → open → verify sequence, so the
// Manual order and Billing screens collect payment through exactly this code.
// Those screens open this screen with [autoCollect] so the sheet appears the
// moment the order exists; a failed or cancelled attempt lands back here, where
// the QR, the payment link and a retry are all still available for the SAME
// order (never a second one).
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../outlet_enums.dart';
import '../../theme/app_widgets.dart' show shareOriginFor;
import '../outlet_models.dart';
import '../outlet_razorpay_checkout.dart';
import '../outlet_repository.dart';
import '../outlet_theme.dart';
import '../../shared/short_id.dart';

class OutletPaymentScreen extends StatefulWidget {
  const OutletPaymentScreen({
    super.key,
    required this.order,
    this.autoCollect = false,
  });

  final OutletOrder order;

  /// Opens the Razorpay checkout sheet as soon as the screen appears — used by
  /// the screens whose own button ("Create order", "Generate bill") is the
  /// payment trigger. The staff-driven "Pay on this device" button is unchanged.
  final bool autoCollect;

  @override
  State<OutletPaymentScreen> createState() => _OutletPaymentScreenState();
}

class _OutletPaymentScreenState extends State<OutletPaymentScreen> {
  final _repo = OutletRepository();
  final _checkout = OutletRazorpayCheckout();

  OutletPaymentInfo? _payment;
  late OutletOrderStatus _status;
  Timer? _poll;

  bool _loadingPayment = true;
  bool _payingOnDevice = false;
  bool _advancing = false;

  /// Polling cadence — the spec's 3-second status poll.
  static const Duration _pollEvery = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _loadPayment();
    _startPolling();
    if (widget.autoCollect) {
      // After the first frame, so the sheet opens over a built screen and its
      // snackbar/setState never lands mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _status.isAwaitingPayment) _payOnDevice();
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _checkout.dispose();
    super.dispose();
  }

  // --- Payment session + polling ---------------------------------------------

  Future<void> _loadPayment() async {
    try {
      final info =
          await _repo.createPayment(widget.order.id, widget.order.paymentMethod);
      if (!mounted) return;
      setState(() {
        _payment = info;
        _loadingPayment = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPayment = false);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollEvery, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    try {
      final status = await _repo.fetchOrderStatus(widget.order.id);
      if (!mounted) return;
      if (status != _status) setState(() => _status = status);
      // Payment resolved → stop polling; terminal transitions are staff-driven.
      if (status.isPaid || status.isReleased) _poll?.cancel();
    } catch (_) {
      // Transient — keep polling.
    }
  }

  // --- Razorpay on-device checkout -------------------------------------------

  /// Runs the shared outlet checkout: server-created Razorpay order → sheet →
  /// server-side verification. Per locked rule #3 nothing is marked paid here —
  /// on a capture we simply resume polling and let the server's own answer flip
  /// the screen to PAID. A cancel or failure leaves the order untouched, so
  /// tapping the button again retries the SAME order.
  Future<void> _payOnDevice() async {
    if (_payingOnDevice) return; // duplicate-tap guard
    setState(() => _payingOnDevice = true);

    final result = await _checkout.collect(widget.order);
    if (!mounted) return;

    setState(() => _payingOnDevice = false);
    _toast(result.message);

    if (result.isPaid || result.outcome == OutletCheckoutOutcome.externalWallet) {
      _startPolling();
      _pollOnce();
    }
  }

  // --- Terminal actions (only reachable once PAID) ---------------------------

  Future<void> _advance(OutletOrderStatus to) async {
    setState(() => _advancing = true);
    try {
      final order = await _repo.advanceOrder(widget.order.id, to);
      if (!mounted) return;
      setState(() {
        _status = order.status;
        _advancing = false;
      });
      _toast('Order ${order.status.label.toLowerCase()}.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _advancing = false);
      _toast('Could not update the order. $e');
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
            'This releases the reserved stock and cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order',
                  style: TextStyle(color: OutletColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await _advance(OutletOrderStatus.cancelled);
    if (mounted) Navigator.of(context).pop();
  }

  /// Asks before walking away from an uncollected payment. The order is left
  /// exactly as it is — unpaid, with its stock committed — so it can be settled
  /// later from Orders.
  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave without collecting?'),
        content: const Text(
            'The order stays unpaid. You can collect the payment later from '
            'Orders, or cancel the order to release the stock.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status.isPaid || _status.isReleased,
      // Leaving with the payment uncollected is allowed but never accidental:
      // the order is real (stock is already committed), so it must stay
      // findable. It does — Orders → the order → "Collect payment" reopens THIS
      // screen for the same order, which is how a cancelled checkout is retried.
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_status.isAwaitingPayment) return;
        final navigator = Navigator.of(context); // captured before the dialog
        final leave = await _confirmLeave();
        if (leave && mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: OutletColors.bg,
        appBar: AppBar(
          backgroundColor: OutletColors.grad1,
          foregroundColor: Colors.white,
          title: const Text('Payment'),
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _statusBanner(),
            const SizedBox(height: 14),
            _orderSummary(),
            const SizedBox(height: 14),
            if (_status.isAwaitingPayment) ...[
              _qrCard(),
              const SizedBox(height: 14),
              _payOnDeviceButton(),
              const SizedBox(height: 10),
              _cancelButton(),
            ] else if (_status.isPaid) ...[
              _paidActions(),
            ] else ...[
              _releasedCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBanner() {
    late final Color bg, fg;
    late final IconData icon;
    late final String title, sub;
    if (_status.isReleased) {
      bg = OutletColors.badgeRedBg;
      fg = OutletColors.danger;
      icon = Icons.cancel_rounded;
      title = _status.label;
      sub = 'Reserved stock has been released.';
    } else if (_status.isPaid) {
      bg = OutletColors.badgeGreenBg;
      fg = OutletColors.success;
      icon = Icons.verified_rounded;
      title = 'Payment confirmed';
      sub = 'Server-verified. You can now fulfil the order.';
    } else {
      bg = OutletColors.badgeAmberBg;
      fg = OutletColors.amber;
      icon = Icons.hourglass_bottom_rounded;
      title = 'Awaiting payment';
      sub = 'Checking every 3s — confirmed by the server, never the app.';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11.5, color: fg)),
              ],
            ),
          ),
          if (_status.isAwaitingPayment)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
        ],
      ),
    );
  }

  Widget _orderSummary() {
    final o = widget.order;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // spaceBetween only distributes space that is already spare, so
              // a full 24-char ObjectId pushed the badge off the right edge.
              Expanded(
                child: Text('Order ${shortId(o.id)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OutletTextStyles.prodName),
              ),
              const SizedBox(width: 8),
              OutletBadge(
                label: o.type.label,
                bg: OutletColors.badgeGreenBg,
                fg: OutletColors.grad1,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${o.customer.name} · ${o.customer.phone}'
            '${o.customer.hasAddress ? '\n${o.customer.address}' : ''}',
            style: OutletTextStyles.prodSub,
          ),
          const Divider(height: 20, color: OutletColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount due', style: OutletTextStyles.prodName),
              Text('₹${o.total.toStringAsFixed(2)}',
                  style: OutletTextStyles.statNum),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qrCard() {
    if (_loadingPayment) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child: CircularProgressIndicator(color: OutletColors.success)),
      );
    }
    final payment = _payment;
    final qrData = payment?.qrImageData ?? payment?.paymentLink;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        children: [
          const Text('Scan to pay',
              style: OutletTextStyles.sectionTitle),
          const SizedBox(height: 4),
          const Text('Customer scans with any UPI app',
              style: OutletTextStyles.prodSub),
          const SizedBox(height: 14),
          if (qrData != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OutletColors.border),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: OutletColors.grad1,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: OutletColors.textDark,
                ),
              ),
            )
          else
            const Text('QR unavailable', style: OutletTextStyles.prodSub),
          if (payment?.paymentLink != null) ...[
            const SizedBox(height: 16),
            const Divider(color: OutletColors.border),
            const SizedBox(height: 6),
            _paymentLinkRow(payment!.paymentLink!),
          ],
        ],
      ),
    );
  }

  Widget _paymentLinkRow(String link) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment link', style: OutletTextStyles.statLabel),
              const SizedBox(height: 2),
              Text(link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: OutletColors.grad2)),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            _toast('Payment link copied');
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: OutletColors.textMid,
          tooltip: 'Copy link',
        ),
        IconButton(
          onPressed: () => Share.share(
            link,
            subject: 'VS Arogya payment link',
            sharePositionOrigin: shareOriginFor(context),
          ),
          icon: const Icon(Icons.share_rounded, size: 18),
          color: OutletColors.textMid,
          tooltip: 'Share link',
        ),
      ],
    );
  }

  Widget _payOnDeviceButton() {
    return _GradientButton(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Pay on this device (Razorpay)',
      loading: _payingOnDevice,
      onTap: _payingOnDevice ? null : _payOnDevice,
    );
  }

  Widget _cancelButton() {
    return TextButton.icon(
      onPressed: _advancing ? null : _cancel,
      icon: const Icon(Icons.close_rounded, color: OutletColors.danger, size: 18),
      label: const Text('Cancel order',
          style: TextStyle(color: OutletColors.danger)),
    );
  }

  Widget _paidActions() {
    final isCounter = widget.order.type == OutletOrderType.counter;
    // After PAID: counter → hand over; delivery → ready for pickup (an agent
    // then takes it out for delivery — Step 9). Terminal for this screen.
    final done = _status == OutletOrderStatus.handedOver ||
        _status == OutletOrderStatus.readyForPickup ||
        _status.isTerminal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        children: [
          Icon(isCounter ? Icons.storefront_rounded : Icons.local_shipping_rounded,
              size: 36, color: OutletColors.success),
          const SizedBox(height: 10),
          Text(
            isCounter
                ? 'Payment done — hand over the medicine at the counter.'
                : 'Payment done — mark ready so an agent can pick it up.',
            textAlign: TextAlign.center,
            style: OutletTextStyles.prodSub,
          ),
          const SizedBox(height: 16),
          if (!done)
            _GradientButton(
              icon: isCounter
                  ? Icons.check_circle_rounded
                  : Icons.inventory_2_rounded,
              label: isCounter ? 'Mark handed over' : 'Mark ready for pickup',
              loading: _advancing,
              onTap: _advancing
                  ? null
                  : () => _advance(isCounter
                      ? OutletOrderStatus.handedOver
                      : OutletOrderStatus.readyForPickup),
            )
          else ...[
            OutletBadge(
              label: _status.label,
              bg: OutletColors.badgeGreenBg,
              fg: OutletColors.success,
            ),
            const SizedBox(height: 14),
            _GradientButton(
              icon: Icons.done_all_rounded,
              label: 'Done',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _releasedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel_rounded, size: 36, color: OutletColors.danger),
          const SizedBox(height: 10),
          Text('Order ${_status.label.toLowerCase()}.',
              style: OutletTextStyles.prodSub),
          const SizedBox(height: 16),
          _GradientButton(
            icon: Icons.done_all_rounded,
            label: 'Done',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
