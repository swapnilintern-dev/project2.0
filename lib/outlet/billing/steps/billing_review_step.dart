// =============================================================================
// VS Arogya — Outlet Billing (POS) · Step 3 · Review, fulfilment & payment
//
// The POS summary: every line with MRP, selling price, discount, quantity and
// subtotal (+ remove), then the totals (GST extracted from the GST-inclusive
// prices, discount vs MRP, grand total). Below it the fulfilment choice (Outlet
// Handover; Home Delivery is shown but deferred for v1) and the payment method
// (Cash / Razorpay). Everything reads + writes the shared BillingController.
//
// Each line also states WHICH BATCH it consumes — the backend's FEFO breakdown —
// and opens the app-wide batch picker to change it. Both the picker and the
// expiry colour scale are shared with Marketing, so a batch looks and behaves
// the same in every role.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../customer/customer_widgets.dart' show EmptyState, formatRupees;
import '../../../widgets/batch_selector.dart';
import '../../../widgets/expiry_alert.dart';
import '../../outlet_enums.dart';
import '../../outlet_models.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              // Price, struck-through MRP and discount badge are three separate
              // facts, and a line can carry all three at once. As a Row they
              // shared one unbreakable line: a four-figure price beside a
              // four-figure MRP runs out of room at the 1.3x text cap on a
              // narrow iPhone, and a Row overflows rather than reflows.
              // Wrap cannot overflow on its main axis — the discount badge
              // drops to a second line instead. Identical to the Row whenever
              // the three fit, which is the common case. `spacing` replaces
              // the SizedBox gaps exactly.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text('₹${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: OutletColors.textDark)),
                  if (item.mrp > item.price)
                    Text('MRP ₹${item.mrp.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: OutletColors.textMuted,
                            decoration: TextDecoration.lineThrough)),
                  if (item.discountPercent > 0)
                    Text('${item.discountPercent.toStringAsFixed(0)}% off',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: OutletColors.success)),
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
        ),
        const SizedBox(height: 8),
        _BatchDetails(line: line, controller: controller),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Batch Details — the FEFO breakdown for a line + manual override entry point.
// The allocation is always the backend's; this only displays it and opens the
// override picker.
// -----------------------------------------------------------------------------
class _BatchDetails extends StatefulWidget {
  const _BatchDetails({required this.line, required this.controller});

  final BillingLine line;
  final BillingController controller;

  @override
  State<_BatchDetails> createState() => _BatchDetailsState();
}

class _BatchDetailsState extends State<_BatchDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    return Container(
      decoration: BoxDecoration(
        color: OutletColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: line.allocError != null
              ? OutletColors.danger
              : OutletColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 15, color: OutletColors.textMid),
                  const SizedBox(width: 6),
                  const Text('Batch Details',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: OutletColors.textDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _status(line)),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: OutletColors.textMid),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (line.allocError != null)
                    Text(line.allocError!,
                        style: const TextStyle(
                            fontSize: 11.5, color: OutletColors.danger)),
                  for (final a in line.allocations) _allocRow(a),
                  if (line.remaining > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${line.remaining} unit(s) unallocated',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: OutletColors.danger)),
                    ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: line.allocLoading ? null : _openOverride,
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                          line.overridden ? 'Edit batches' : 'Change batches',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        foregroundColor: OutletColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _status(BillingLine line) {
    if (line.allocLoading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (line.allocError != null) {
      return const Text('Allocation error',
          style: TextStyle(fontSize: 11, color: OutletColors.danger));
    }
    final n = line.allocations.length;
    final label = line.overridden ? 'Manual · ' : 'FEFO · ';
    return Text('$label$n batch${n == 1 ? '' : 'es'}',
        style: const TextStyle(fontSize: 11, color: OutletColors.textMuted));
  }

  Widget _allocRow(OutletBatchAllocation a) {
    final tier = expiryTierOf(a.expiry);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(a.batchNumber,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: OutletColors.textDark)),
          ),
          if (a.expiry != null) ...[
            Icon(Icons.event_outlined, size: 13, color: tier.color),
            const SizedBox(width: 3),
            Text(formatExpiry(a.expiry),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: tier.color)),
            const SizedBox(width: 6),
            ExpiryTierBadge(expiry: a.expiry, dense: true),
            const SizedBox(width: 8),
          ],
          Text('${a.quantity}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: OutletColors.textDark)),
          const SizedBox(width: 2),
          const Text('units',
              style: TextStyle(fontSize: 10.5, color: OutletColors.textMuted)),
        ],
      ),
    );
  }

  /// Opens the SHARED FEFO picker (the same one Marketing uses for manual
  /// orders and stock assignment), so a batch reads identically in every role.
  /// The outlet's batches are fetched live; the pick goes straight back to the
  /// backend, which validates it and returns the authoritative allocation.
  Future<void> _openOverride() async {
    final line = widget.line;
    final (batches, error) =
        await widget.controller.availableBatches(line.item.id);
    if (!mounted) return;

    if (batches == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not load batches')),
      );
      return;
    }
    if (batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No sellable batch left for this medicine — every lot is empty '
              'or past its expiry date.'),
        ),
      );
      return;
    }

    final picked = await showBatchSelector(
      context: context,
      productName: line.item.name,
      quantity: line.qty,
      batches: [
        for (final b in batches)
          BatchOption(
            id: b.id,
            batchNumber: b.batchNumber,
            available: b.available,
            expiry: b.expiry,
            isExpiringSoon: b.isExpiringSoon,
          ),
      ],
      initial: [
        for (final a in line.allocations)
          BatchAllocation(
            batchId: a.batchId,
            batchNumber: a.batchNumber,
            quantity: a.quantity,
            expiry: a.expiry,
          ),
      ],
    );
    if (picked == null || !mounted) return;

    await widget.controller.overrideAllocation(
      line.item.id,
      [
        for (final a in picked)
          OutletBatchAllocation(
            batchId: a.batchId,
            batchNumber: a.batchNumber,
            quantity: a.quantity,
            expiry: a.expiry,
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
