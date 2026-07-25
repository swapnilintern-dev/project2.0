// =============================================================================
// VS Arogya — Outlet Billing (POS) · Step 3 · Review, fulfilment & payment
//
// The POS summary: every line with MRP, selling price, discount, quantity and
// subtotal (+ remove), then the totals (GST extracted from the GST-inclusive
// prices, discount vs MRP, grand total). Below it the fulfilment choice (Outlet
// Handover; Home Delivery is shown but deferred for v1) and the payment method
// (Cash / Razorpay). Everything reads + writes the shared BillingController.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../customer/customer_widgets.dart' show EmptyState, formatRupees;
import '../../outlet_enums.dart';
import '../../outlet_theme.dart';
import '../billing_controller.dart';
import '../billing_widgets.dart';

class BillingReviewStep extends StatelessWidget {
  const BillingReviewStep({super.key, required this.controller});

  final BillingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No items yet',
            message: 'Go back and add medicines to build the bill.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _lines(),
            const SizedBox(height: 12),
            _totals(),
            const SizedBox(height: 12),
            _fulfilment(),
            const SizedBox(height: 12),
            _payment(),
          ],
        );
      },
    );
  }

  // --- Items -----------------------------------------------------------------

  Widget _lines() {
    return BillingCard(
      icon: Icons.medication_outlined,
      title: 'Items (${controller.distinctCount})',
      child: Column(
        children: [
          for (final line in controller.lines) ...[
            _LineRow(line: line, controller: controller),
            if (line != controller.lines.last)
              const Divider(height: 18, color: OutletColors.border),
          ],
        ],
      ),
    );
  }

  // --- Totals ----------------------------------------------------------------

  Widget _totals() {
    return BillingCard(
      icon: Icons.calculate_outlined,
      title: 'Bill Summary',
      child: Column(
        children: [
          _totalRow('MRP total', formatRupees(controller.mrpTotal)),
          if (controller.discountTotal > 0)
            _totalRow('Discount', '- ${formatRupees(controller.discountTotal)}',
                valueColor: OutletColors.success),
          _totalRow('Taxable + GST (incl.)', formatRupees(controller.grandTotal)),
          _totalRow('GST (included)', formatRupees(controller.gstTotal),
              muted: true),
          const Divider(height: 18, color: OutletColors.border),
          _totalRow('Grand Total', formatRupees(controller.grandTotal),
              bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, bool muted = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: muted ? OutletColors.textMuted : OutletColors.textMid)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ??
                      (bold ? OutletColors.success : OutletColors.textDark))),
        ],
      ),
    );
  }

  // --- Fulfilment ------------------------------------------------------------

  Widget _fulfilment() {
    return BillingCard(
      icon: Icons.local_shipping_outlined,
      title: 'Fulfilment',
      child: Row(
        children: [
          Expanded(
            child: _ChoiceCard(
              icon: Icons.storefront_outlined,
              title: 'Outlet Handover',
              subtitle: 'Given at the counter',
              selected: controller.orderType == OutletOrderType.counter,
              onTap: () => controller.orderType = OutletOrderType.counter,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ChoiceCard(
              icon: Icons.delivery_dining_outlined,
              title: 'Home Delivery',
              subtitle: 'Coming soon',
              selected: false,
              disabled: true,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  // --- Payment ---------------------------------------------------------------

  Widget _payment() {
    return BillingCard(
      icon: Icons.payments_outlined,
      title: 'Payment',
      child: Column(
        children: [
          _PaymentTile(
            icon: Icons.money_rounded,
            title: 'Cash',
            subtitle: 'Collected at the counter',
            selected: controller.payment == BillingPayment.cod,
            onTap: () => controller.payment = BillingPayment.cod,
          ),
          const SizedBox(height: 10),
          _PaymentTile(
            icon: Icons.qr_code_rounded,
            title: 'Razorpay',
            subtitle: 'UPI / card / QR — verified online',
            selected: controller.payment == BillingPayment.razorpay,
            onTap: () => controller.payment = BillingPayment.razorpay,
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.controller});

  final BillingLine line;
  final BillingController controller;

  @override
  Widget build(BuildContext context) {
    final item = line.item;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OutletTextStyles.prodName),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text('₹${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: OutletColors.textDark)),
                  if (item.mrp > item.price) ...[
                    const SizedBox(width: 6),
                    Text('MRP ₹${item.mrp.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: OutletColors.textMuted,
                            decoration: TextDecoration.lineThrough)),
                  ],
                  if (item.discountPercent > 0) ...[
                    const SizedBox(width: 6),
                    Text('${item.discountPercent.toStringAsFixed(0)}% off',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: OutletColors.success)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              BillingQtyStepper(
                qty: line.qty,
                atMax: line.qty >= item.qtyAvailable,
                onDecrement: () => controller.decrement(item.id),
                onIncrement: () => controller.increment(item.id),
                onEdit: () => showQtyEntryDialog(
                  context,
                  current: line.qty,
                  max: item.qtyAvailable,
                  onSet: (v) => controller.setQty(item.id, v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatRupees(line.lineTotal),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: OutletColors.textDark)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => controller.remove(item.id),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.delete_outline_rounded,
                    size: 20, color: OutletColors.danger),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = disabled ? OutletColors.textMuted : OutletColors.textDark;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? OutletColors.badgeGreenBg : OutletColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? OutletColors.success : OutletColors.border,
                width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? OutletColors.success : base),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: base)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 10.5, color: OutletColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? OutletColors.badgeGreenBg : OutletColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? OutletColors.success : OutletColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? OutletColors.success : OutletColors.textMid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OutletColors.textDark)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: OutletColors.textMuted)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? OutletColors.success : OutletColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
