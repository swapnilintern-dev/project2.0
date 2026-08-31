// =============================================================================
// VS Arogya — Outlet Billing (POS) · Wizard shell
//
// A 3-step counter-billing flow for a walk-in customer:
//   1. Customer details   → collected for the auto vendor registration
//   2. Products           → picked from this outlet's own stock
//   3. Review & pay        → summary, fulfilment, payment → place the bill
//
// On "Place Bill" the BillingController places a stock-deducting outlet order
// (server renders the HTML invoice) and — for Razorpay — hands off to the
// existing OutletPaymentScreen. It ends on a success screen that submits the
// customer's vendor registration to Admin in the background and offers the
// printable invoice (download / share / view).
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_theme.dart';
import '../screens/outlet_payment_screen.dart';
import 'billing_controller.dart';
import 'billing_success_screen.dart';
import 'billing_widgets.dart';
import 'steps/billing_customer_step.dart';
import 'steps/billing_products_step.dart';
import 'steps/billing_review_step.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final BillingController _controller = BillingController();
  final _customerKey = GlobalKey<BillingCustomerStepState>();

  int _step = 0;

  static const _titles = ['Customer', 'Medicines', 'Review & Pay'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _step -= 1);
    }
  }

  void _next() {
    if (_step == 0) {
      if (!(_customerKey.currentState?.validateAndSave() ?? false)) return;
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_controller.isEmpty) {
        _snack('Add at least one medicine to continue.');
        return;
      }
      setState(() => _step = 2);
    }
  }

  Future<void> _placeBill() async {
    // Block only on a real, unresolved batch problem (e.g. an over-allocated
    // manual override). A plain empty/loading allocation is fine — the backend
    // does the final FEFO + validation inside the billing transaction.
    if (_controller.lines.any((l) => l.allocError != null)) {
      _snack('Fix the highlighted batch allocation before placing the bill.');
      return;
    }
    final result = await _controller.submit();
    if (!mounted) return;
    if (!result.ok) {
      _snack(result.error ?? 'Could not place the bill.');
      return;
    }
    final order = result.order!;

    // Razorpay → collect payment on the existing outlet payment screen first,
    // with the checkout sheet opening straight away (the same shared flow the
    // manual-order screen uses). The QR / payment link and a retry stay on that
    // screen for a customer who cancels or would rather pay on their own phone.
    if (_controller.payment == BillingPayment.razorpay) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutletPaymentScreen(order: order, autoCollect: true),
        ),
      );
      if (!mounted) return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BillingSuccessScreen(
          order: order,
          registrationPayload: _controller.vendorRegistrationPayload,
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step -= 1);
      },
      child: Scaffold(
        backgroundColor: OutletColors.bg,
        body: Column(
          children: [
            _header(),
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  BillingCustomerStep(key: _customerKey, controller: _controller),
                  BillingProductsStep(controller: _controller),
                  BillingReviewStep(controller: _controller),
                ],
              ),
            ),
            _actionBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: const BoxDecoration(gradient: OutletColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const Expanded(
                  child: Text('New Bill',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                Text('Step ${_step + 1} of 3',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(_titles[_step],
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final onLast = _step == 2;
        final busy = _controller.submitting;
        final cod = _controller.payment == BillingPayment.cod;
        return Container(
          padding: EdgeInsets.fromLTRB(
              14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            color: OutletColors.white,
            border: Border(top: BorderSide(color: OutletColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onLast && !_controller.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total',
                          style: TextStyle(
                              fontSize: 13, color: OutletColors.textMid)),
                      Text('₹${_controller.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: OutletColors.textDark)),
                    ],
                  ),
                ),
              if (busy && _controller.phase.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_controller.phase,
                      style: const TextStyle(
                          fontSize: 12, color: OutletColors.textMuted)),
                ),
              Row(
                children: [
                  if (_step > 0) ...[
                    BillingGhostButton(
                        label: 'Back', onPressed: busy ? null : _back),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: BillingButton(
                      label: onLast
                          ? (cod ? 'Place Bill' : 'Pay & Place Bill')
                          : 'Continue',
                      icon: onLast
                          ? (cod
                              ? Icons.check_circle_outline_rounded
                              : Icons.qr_code_rounded)
                          : Icons.arrow_forward_rounded,
                      loading: busy,
                      onPressed:
                          busy ? null : (onLast ? _placeBill : _next),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

