// =============================================================================
// VS Arogya — Outlet Staff · Create Manual Order
//
// Staff reviews the cart, captures the walk-in customer, picks fulfilment and
// payment, then creates the order. Locked rules honoured here:
//   #2 COUNTER vs DELIVERY — the address form appears ONLY for DELIVERY.
//   #3 QR / payment link only — no cash, no COD anywhere.
//   idempotency — the request carries OutletCart.idempotencyKey (generated once
//   per cart); the submit button is also disabled while in flight, so a
//   double-tap can never create two orders.
//
// The order is placed through the SAME manual-order API the marketing role
// uses (manual-cart ×qty → manual-order), tagged with this outlet's id so the
// server deducts THIS outlet's batches and lands the order in the normal vendor
// pipeline for the team to accept, invoice and fulfil.
//
// BATCH-WISE REVIEW: every line names the lot it will be issued from, and both
// the quantity and the lot stay editable here. Nothing is committed until the
// backend has re-checked each line against live inventory
// (POST /outlet/allocate-preview, non-mutating) — that single call validates
// stock, batch validity, expiry and this outlet's ownership of the lot.
//
// PAYMENT: "Create order" places the order and then collects the money in the
// same step — the order is handed straight to the Payment screen with
// autoCollect, which opens the shared Razorpay checkout (OutletRazorpayCheckout)
// against a SERVER-created Razorpay order. Both payment choices on this screen
// open that same checkout, so the customer gets every method Razorpay offers
// (UPI/GPay/PhonePe/Paytm/BHIM, cards, net banking, wallets, EMI, pay later);
// the QR and the shareable link stay on the Payment screen for a customer who
// would rather pay on their own phone. A cancelled or failed payment leaves the
// order sitting there for a retry — it never creates a second order.
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_batch_picker.dart';
import '../outlet_cart.dart';
import '../outlet_enums.dart';
import '../outlet_live_datasource.dart' show OutletApiException;
import '../outlet_models.dart';
import '../outlet_qty_field.dart';
import '../outlet_repository.dart';
import '../outlet_stock_signal.dart';
import '../outlet_theme.dart';
import '../../widgets/expiry_alert.dart';
import 'outlet_payment_screen.dart';

class OutletManualOrderScreen extends StatefulWidget {
  const OutletManualOrderScreen({super.key});

  @override
  State<OutletManualOrderScreen> createState() =>
      _OutletManualOrderScreenState();
}

class _OutletManualOrderScreenState extends State<OutletManualOrderScreen> {
  final _repo = OutletRepository();
  final _cart = OutletCart.instance;

  /// The verified vendor this order is placed for (replaces the old free-text
  /// walk-in name/phone). Chosen from the searchable picker; the vendor's
  /// registered phone + address are used automatically.
  OutletVendor? _vendor;

  OutletOrderType _type = OutletOrderType.counter;
  OutletPaymentMethod _payment = OutletPaymentMethod.qr;
  bool _submitting = false;

  /// Per-line problems the BACKEND reported for the current cart, keyed by
  /// product id (e.g. the pinned lot emptied, or the outlet is short). Populated
  /// by [_validateLines]; shown inline on the line it belongs to.
  final Map<String, String> _lineErrors = {};

  /// True while the backend re-check is in flight.
  bool _validating = false;

  /// True only when the LAST completed re-check found every line coverable from
  /// the lot it names. Any cart edit clears it, so the strip never claims a
  /// verification that no longer applies to what is on screen.
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    // Re-check the cart against live inventory as soon as the review opens: the
    // lines may have been sitting in the cart while another till sold from the
    // same lots. Nothing is mutated by this — it is a preview call. Deferred to
    // after the first frame so its setState never lands mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_cart.isEmpty) _validateLines();
    });
  }

  // ---------------------------------------------------------------------------
  // BACKEND VALIDATION (non-mutating; the server is the only authority)
  // ---------------------------------------------------------------------------

  /// Asks the backend, line by line, whether the pinned lot can still give the
  /// requested quantity — POST /outlet/allocate-preview. One call covers every
  /// rule at once: the lot must exist, belong to THIS outlet, be unexpired, and
  /// hold enough units.
  ///
  /// Returns true when every line is clear. Fills [_lineErrors] otherwise, so
  /// the failures are visible on the exact lines that caused them rather than as
  /// one anonymous toast.
  Future<bool> _validateLines() async {
    final lines = _cart.lines;
    if (lines.isEmpty) return false;

    setState(() {
      _validating = true;
      _verified = false;
      _lineErrors.clear();
    });

    final errors = <String, String>{};
    for (final line in lines) {
      if (!line.hasBatch) {
        errors[line.productId] = 'Select the batch this line is issued from.';
        continue;
      }
      try {
        final preview = await _repo.previewAllocation(
          line.productId,
          line.qty,
          overrides: [line.allocation],
        );
        if (!preview.isComplete) {
          final have = line.qty - preview.remaining;
          errors[line.productId] =
              'Only $have of ${line.qty} unit(s) are in stock right now.';
          continue;
        }
        // The server silently drops a pin it can no longer honour (lot emptied
        // or expired since it was chosen) and covers the line from other lots
        // instead. That would hand over a different batch than the one on
        // screen, so treat it as a failure the user must resolve.
        final honoured = preview.allocations.any((a) => a.batchId == line.batchId);
        if (!honoured) {
          errors[line.productId] = line.batch.isEmpty
              ? 'That batch is no longer available — pick another.'
              : 'Batch ${line.batch} is no longer available — pick another.';
        }
      } on OutletApiException catch (e) {
        // Carries the server's own reason ("Batch B12 has only 3 available", …).
        errors[line.productId] = e.message;
      } catch (_) {
        errors[line.productId] =
            'Could not verify this line. Check your connection and retry.';
      }
    }

    if (!mounted) return false;
    setState(() {
      _validating = false;
      _verified = errors.isEmpty;
      _lineErrors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  /// Drops the last verification result. Called on every quantity edit: the
  /// answer the server gave was about a different quantity, and the authoritative
  /// re-check runs when the order is confirmed.
  void _invalidateChecks(String productId) {
    if (!_verified && !_lineErrors.containsKey(productId)) return;
    setState(() {
      _verified = false;
      _lineErrors.remove(productId);
    });
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against double-tap
    if (_cart.isEmpty) {
      _toast('Add at least one item to the cart.');
      return;
    }
    final vendor = _vendor;
    if (vendor == null) {
      _toast('Select a verified vendor for this order.');
      return;
    }
    if (_type.needsAddress && !vendor.hasAddress) {
      _toast('This vendor has no registered address for delivery.');
      return;
    }
    final missingBatch = _cart.linesWithoutBatch;
    if (missingBatch.isNotEmpty) {
      _toast('Select a batch for ${missingBatch.first.name}.');
      return;
    }

    setState(() => _submitting = true);

    // Final gate: re-check every line against live inventory immediately before
    // the write, so the order can only be placed from stock that actually
    // exists in the lots on screen.
    final ok = await _validateLines();
    if (!mounted) return;
    if (!ok) {
      setState(() => _submitting = false);
      _toast(_lineErrors.values.first);
      return;
    }

    // Snapshot everything BEFORE the await so clearing the cart afterwards
    // can't affect the request that's already been built.
    final request = CreateOrderRequest(
      type: _type,
      paymentMethod: _payment,
      lines: _cart.lines,
      customer: OutletCustomerInfo.fromVendor(
        vendor,
        includeAddress: _type.needsAddress,
      ),
      idempotencyKey: _cart.idempotencyKey,
    );

    try {
      final order = await _repo.createOrder(request);
      if (!mounted) return;
      _cart.clear();
      // The server has now deducted this outlet's batches — tell the stock
      // screens to re-read rather than wait for their next poll.
      OutletStockSignal.bump();

      // The order is now REAL and sits in the vendor pipeline for marketing to
      // accept, invoice and fulfil — and, because it was tagged with this
      // outlet, it is payable through the outlet's own Razorpay endpoints
      // (order.outlet == the session's outlet id, enforced server-side).
      //
      // Hand it to the Payment screen with the checkout already opening. Every
      // outcome is handled there: PAID unlocks hand-over / ready-for-pickup,
      // and a cancel or failure keeps the QR, the link and a retry on the SAME
      // order.
      if (order.id.isEmpty) {
        // No id came back, so there is nothing to pay against — fall back to
        // the plain confirmation rather than opening a checkout that can't be
        // tied to the order.
        await _showPlaced(order);
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutletPaymentScreen(order: order, autoCollect: true),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // OutletApiException carries the server's own reason ("Vendor not found",
      // "Cart is empty", …) — show it instead of a generic line.
      _toast(e is OutletApiException
          ? e.message
          : 'Could not create the order. Please try again.');
    }
  }

  /// Confirms the order landed, with the id marketing will see it by.
  Future<void> _showPlaced(OutletOrder order) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Order placed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('For ${order.customer.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${order.itemCount} item'
                  '${order.itemCount == 1 ? '' : 's'} · '
                  '₹${order.total.toStringAsFixed(2)}'),
              if (order.id.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Order #${order.id}',
                    style: const TextStyle(
                        fontSize: 12, color: OutletColors.textMuted)),
              ],
              const SizedBox(height: 10),
              const Text(
                'Sent to the team for confirmation and invoicing. Payment is '
                'collected on that side — not here.',
                style: TextStyle(fontSize: 12, color: OutletColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutletColors.bg,
      appBar: AppBar(
        backgroundColor: OutletColors.grad1,
        foregroundColor: Colors.white,
        title: const Text('New manual order'),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _cart,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _sectionTitle('Cart', '${_cart.itemCount} item(s)'),
              const SizedBox(height: 8),
              if (_cart.isEmpty) _emptyCart() else _cartCard(),
              if (!_cart.isEmpty) ...[
                const SizedBox(height: 8),
                _validationStrip(),
              ],
              const SizedBox(height: 10),
              _addProductButton(),
              const SizedBox(height: 18),
              _sectionTitle('Vendor', 'Verified only'),
              const SizedBox(height: 8),
              _vendorCard(),
              const SizedBox(height: 18),
              _sectionTitle('Fulfilment', ''),
              const SizedBox(height: 8),
              _fulfilmentCard(),
              const SizedBox(height: 18),
              _sectionTitle('Payment', 'QR / link only'),
              const SizedBox(height: 8),
              _paymentCard(),
              const SizedBox(height: 22),
              _submitButton(),
            ],
          );
        },
      ),
    );
  }

  // --- Sections --------------------------------------------------------------

  Widget _sectionTitle(String title, String trailing) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: OutletTextStyles.sectionTitle),
          if (trailing.isNotEmpty)
            Text(trailing, style: OutletTextStyles.prodSub),
        ],
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OutletColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: OutletColors.cardShadow,
        ),
        child: child,
      );

  Widget _emptyCart() => _card(
        child: Row(
          children: const [
            Icon(Icons.remove_shopping_cart_outlined,
                color: OutletColors.textMuted),
            SizedBox(width: 10),
            Expanded(
              child: Text('Cart is empty. Add products below or from the '
                  'Stock tab.', style: OutletTextStyles.prodSub),
            ),
          ],
        ),
      );

  /// Full-width "Add product" button that opens the searchable own-outlet
  /// product picker — matches the marketing manual-order flow so staff can add
  /// items without leaving this screen.
  Widget _addProductButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addProduct,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add product',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: OutletColors.grad1,
          side: const BorderSide(color: OutletColors.grad2),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Picks a medicine, then immediately the LOT it will be issued from — the
  /// same two-step flow as the Stock tab. Backing out of the batch sheet adds
  /// nothing, because an outlet line without a lot is not a valid line.
  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<OutletStockItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OutletColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _OutletProductPickerSheet(),
    );
    if (picked == null || !mounted) return;

    final batch = await showOutletBatchPicker(
      context: context,
      productId: picked.id,
      productName: picked.name,
      selectedBatchId: _cart.lineOf(picked.id)?.batchId ?? '',
      repository: _repo,
    );
    if (batch == null || !mounted) return;

    _cart.add(picked, batch: batch);
    await _validateLines();
  }

  /// Re-pins a line to another lot and re-checks it against the server.
  Future<void> _changeBatch(OutletCartLine line) async {
    final batch = await showOutletBatchPicker(
      context: context,
      productId: line.productId,
      productName: line.name,
      selectedBatchId: line.batchId,
      repository: _repo,
    );
    if (batch == null || !mounted) return;

    _cart.setBatch(line.productId, batch);
    await _validateLines();
  }

  Widget _cartCard() {
    return _card(
      child: Column(
        children: [
          for (final line in _cart.lines) ...[
            _cartLineRow(line),
            if (line != _cart.lines.last)
              const Divider(height: 18, color: OutletColors.border),
          ],
          const Divider(height: 22, color: OutletColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: OutletTextStyles.prodName),
              Text('₹${_cart.total.toStringAsFixed(2)}',
                  style: OutletTextStyles.statNum),
            ],
          ),
        ],
      ),
    );
  }

  /// One review line: medicine, the LOT it is issued from, its expiry, an
  /// editable quantity, the unit price and the subtotal — plus whatever the
  /// backend said about it on the last check.
  Widget _cartLineRow(OutletCartLine line) {
    final error = _lineErrors[line.productId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.name, style: OutletTextStyles.prodName),
                  const SizedBox(height: 2),
                  // Unit price × quantity = subtotal, spelled out so the review
                  // reads the same way the invoice will.
                  Text(
                    '₹${line.price.toStringAsFixed(2)} × ${line.qty} = '
                    '₹${line.lineTotal.toStringAsFixed(2)}',
                    style: OutletTextStyles.prodSub,
                  ),
                ],
              ),
            ),
            OutletQtyField(
              qty: line.qty,
              max: line.maxQty,
              style: OutletQtyFieldStyle.outlined,
              // Frozen mid-submit so a quantity can't slip in between the
              // backend's validation and the order write.
              enabled: !_submitting,
              onSet: (v) {
                _cart.setQty(line.productId, v);
                _invalidateChecks(line.productId);
              },
              onRemove: () {
                _cart.remove(line.productId);
                _invalidateChecks(line.productId);
              },
            ),
            IconButton(
              onPressed:
                  _submitting ? null : () => _cart.remove(line.productId),
              icon: const Icon(Icons.delete_outline, size: 20),
              color: OutletColors.danger,
              tooltip: 'Remove',
            ),
          ],
        ),
        const SizedBox(height: 6),
        _batchStrip(line, error),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 14, color: OutletColors.danger),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(error,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: OutletColors.danger)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Where the cart stands against LIVE inventory: checking, clear, or a count
  /// of the lines the server refused. Offers a manual re-check so staff can
  /// resolve a problem (or a dropped connection) without leaving the screen.
  Widget _validationStrip() {
    final IconData icon;
    final Color color;
    final String text;
    if (_validating) {
      icon = Icons.sync;
      color = OutletColors.textMid;
      text = 'Checking batches against live stock…';
    } else if (_lineErrors.isNotEmpty) {
      icon = Icons.error_outline;
      color = OutletColors.danger;
      text = '${_lineErrors.length} line(s) need attention before ordering.';
    } else if (_verified) {
      icon = Icons.verified_outlined;
      color = OutletColors.success;
      text = 'Every line verified against live outlet stock.';
    } else {
      icon = Icons.info_outline;
      color = OutletColors.textMid;
      text = 'Stock and batches are re-checked when you confirm the order.';
    }

    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ),
        if (!_validating && !_submitting)
          TextButton(
            onPressed: _validateLines,
            style: TextButton.styleFrom(
              foregroundColor: OutletColors.grad1,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('Re-check',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  /// The always-visible statement of WHICH lot this line consumes, with the tap
  /// target to change it. A line can never be committed without the user having
  /// seen the batch it comes from.
  Widget _batchStrip(OutletCartLine line, String? error) {
    final bad = error != null || !line.hasBatch;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: OutletColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: bad
              ? OutletColors.danger.withValues(alpha: 0.4)
              : OutletColors.border,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 15, color: OutletColors.grad1),
          const SizedBox(width: 7),
          Expanded(
            child: line.hasBatch
                ? Row(
                    children: [
                      Flexible(
                        child: Text(
                          [
                            line.batch.isEmpty
                                ? 'Unnumbered lot'
                                : 'Batch ${line.batch}',
                            formatExpiry(line.expiry),
                            if (line.batchAvailable > 0)
                              '${line.batchAvailable} in lot',
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: expiryTierOf(line.expiry).color),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ExpiryTierBadge(expiry: line.expiry, dense: true),
                    ],
                  )
                : const Text('No batch selected',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: OutletColors.danger)),
          ),
          TextButton(
            onPressed: _submitting ? null : () => _changeBatch(line),
            style: TextButton.styleFrom(
              foregroundColor: OutletColors.grad1,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(line.hasBatch ? 'Change' : 'Select',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// The vendor block. Empty → a tap-to-select card; chosen → the vendor's
  /// registered details (read-only) with a "Change" action. Replaces the old
  /// free-text customer name/phone: an outlet order is always for a verified
  /// vendor whose profile supplies the phone + delivery address.
  Widget _vendorCard() {
    final v = _vendor;
    if (v == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickVendor,
          borderRadius: BorderRadius.circular(14),
          child: _card(
            child: Row(
              children: const [
                Icon(Icons.storefront_outlined, color: OutletColors.grad1),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Select a verified vendor',
                      style: OutletTextStyles.prodName),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: OutletColors.textMuted),
              ],
            ),
          ),
        ),
      );
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: OutletColors.badgeGreenBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: OutletColors.grad1, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.displayName, style: OutletTextStyles.prodName),
                    if (v.contactPerson.isNotEmpty &&
                        v.contactPerson != v.displayName) ...[
                      const SizedBox(height: 2),
                      Text(v.contactPerson, style: OutletTextStyles.prodSub),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: _pickVendor,
                child: const Text('Change',
                    style: TextStyle(
                        color: OutletColors.grad1,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Divider(height: 18, color: OutletColors.border),
          _vendorLine(Icons.phone_outlined, v.phone.isEmpty ? '—' : v.phone),
          if (v.city.isNotEmpty || v.pincode.isNotEmpty) ...[
            const SizedBox(height: 8),
            _vendorLine(
              Icons.location_city_outlined,
              [v.city, v.pincode].where((p) => p.isNotEmpty).join(' · '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vendorLine(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 17, color: OutletColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: OutletTextStyles.prodSub)),
        ],
      );

  Future<void> _pickVendor() async {
    final picked = await showModalBottomSheet<OutletVendor>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OutletColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _OutletVendorPickerSheet(),
    );
    if (picked != null && mounted) setState(() => _vendor = picked);
  }

  /// Read-only delivery-address preview shown when DELIVERY is chosen. The
  /// address always comes from the selected vendor's registered profile — staff
  /// never type it (option A).
  Widget _deliveryAddressPreview() {
    final v = _vendor;
    final IconData icon;
    final Color color;
    final String text;
    if (v == null) {
      icon = Icons.info_outline;
      color = OutletColors.textMuted;
      text = 'Select a vendor to load the delivery address.';
    } else if (!v.hasAddress) {
      icon = Icons.warning_amber_rounded;
      color = OutletColors.danger;
      text = 'This vendor has no registered address for delivery.';
    } else {
      icon = Icons.location_on_outlined;
      color = OutletColors.grad1;
      text = v.fullAddress;
    }
    final hasAddr = v?.hasAddress ?? false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OutletColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OutletColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery address (from vendor)',
                    style: OutletTextStyles.statLabel),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasAddr ? OutletColors.textDark : color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fulfilmentCard() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _typeSeg(OutletOrderType.counter, Icons.storefront_rounded),
              const SizedBox(width: 10),
              _typeSeg(OutletOrderType.delivery, Icons.local_shipping_outlined),
            ],
          ),
          // Address ONLY for delivery (locked rule #2) — read-only, taken from
          // the selected vendor's registered profile (option A).
          if (_type.needsAddress) ...[
            const SizedBox(height: 14),
            _deliveryAddressPreview(),
          ],
        ],
      ),
    );
  }

  Widget _typeSeg(OutletOrderType type, IconData icon) {
    final active = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active ? OutletColors.headerGradient : null,
            color: active ? null : OutletColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: active ? null : Border.all(color: OutletColors.border),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20, color: active ? Colors.white : OutletColors.textMid),
              const SizedBox(height: 4),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : OutletColors.textMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentCard() {
    return _card(
      child: Column(
        children: [
          _payOption(OutletPaymentMethod.qr, Icons.qr_code_2_rounded,
              'Show a Razorpay QR at the counter'),
          const Divider(height: 18, color: OutletColors.border),
          _payOption(OutletPaymentMethod.paymentLink, Icons.link_rounded,
              'Send a Razorpay payment link'),
        ],
      ),
    );
  }

  Widget _payOption(OutletPaymentMethod method, IconData icon, String sub) {
    final active = _payment == method;
    return InkWell(
      onTap: () => setState(() => _payment = method),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon,
                color: active ? OutletColors.success : OutletColors.textMid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label, style: OutletTextStyles.prodName),
                  const SizedBox(height: 2),
                  Text(sub, style: OutletTextStyles.prodSub),
                ],
              ),
            ),
            Icon(
              active
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: active ? OutletColors.success : OutletColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _submitButton() {
    // Blocked while a check is running, while any line is unresolved, and while
    // any line has no lot pinned — an outlet sale must always name its batch.
    final enabled = !_cart.isEmpty &&
        !_submitting &&
        !_validating &&
        _lineErrors.isEmpty &&
        _cart.allLinesHaveBatch;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _submit : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: OutletColors.headerGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Create order · ₹${_cart.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

}

// =============================================================================
// Product picker sheet — searchable OWN-outlet stock (district stock is never
// listed here; locked rule #1). Out-of-stock rows aren't selectable. Pops with
// the chosen item, which the caller adds to the cart.
// =============================================================================

class _OutletProductPickerSheet extends StatefulWidget {
  const _OutletProductPickerSheet();

  @override
  State<_OutletProductPickerSheet> createState() =>
      _OutletProductPickerSheetState();
}

class _OutletProductPickerSheetState extends State<_OutletProductPickerSheet> {
  final _repo = OutletRepository();
  late final Future<List<OutletStockItem>> _future = _repo.fetchStock();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Modal sheets get no keyboard handling from the framework (unlike Dialog,
    // ModalBottomSheetRoute never reads viewInsets), and this one is a FIXED
    // 75% of the FULL screen. Focusing the search box therefore puts the
    // keyboard straight over the bottom of the results — you type, and the
    // matches you're looking for are behind the keys. Measuring the 75%
    // against the space actually left, and lifting by the same inset, keeps
    // the whole list visible. The inset is 0 with no keyboard up, so this is
    // a no-op on both platforms otherwise.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(bottom: keyboardInset),
        height: (MediaQuery.of(context).size.height - keyboardInset) * 0.75,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                color: OutletColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Add product',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search medicine…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: OutletColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<OutletStockItem>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: OutletColors.success));
                  }
                  final q = _query.trim().toLowerCase();
                  // Own-outlet stock only (rule #1); newest search applied.
                  final list = (snap.data ?? const [])
                      .where((s) => s.isOwnOutlet)
                      .where((s) =>
                          q.isEmpty || s.name.toLowerCase().contains(q))
                      .toList();
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No matching products',
                          style: OutletTextStyles.prodSub),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: OutletColors.border),
                    itemBuilder: (context, i) => _row(list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(OutletStockItem s) {
    final inCart = OutletCart.instance.quantityOf(s.id);
    final selectable = s.inStock;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: selectable,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: OutletColors.badgeGreenBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.medication_outlined,
            color: OutletColors.grad1, size: 20),
      ),
      title: Text(s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selectable ? OutletColors.textDark : OutletColors.textMuted)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (s.packSize.isNotEmpty) s.packSize,
              '₹${s.price.toStringAsFixed(0)}',
              s.inStock ? '${s.qtyAvailable} in stock' : 'Out of stock',
            ].join(' · '),
            style: OutletTextStyles.prodSub,
          ),
          // The lot that will be issued first (outlet's own FEFO front).
          if (s.batch.isNotEmpty || s.expiry != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      [
                        if (s.batch.isNotEmpty) 'Batch ${s.batch}',
                        formatExpiry(s.expiry),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: expiryTierOf(s.expiry).color),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ExpiryTierBadge(expiry: s.expiry, dense: true),
                ],
              ),
            ),
        ],
      ),
      isThreeLine: s.batch.isNotEmpty || s.expiry != null,
      trailing: inCart > 0
          ? Text('$inCart in cart',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OutletColors.success))
          : (selectable
              ? const Icon(Icons.add_circle_outline, color: OutletColors.grad1)
              : null),
      onTap: selectable ? () => Navigator.of(context).pop(s) : null,
    );
  }
}

// =============================================================================
// Vendor picker sheet — searchable list of admin-approved vendors. Replaces the
// old walk-in name field: an outlet order is always placed for a verified
// vendor. Pops with the chosen vendor, whose registered phone + address the
// order then uses.
// =============================================================================

class _OutletVendorPickerSheet extends StatefulWidget {
  const _OutletVendorPickerSheet();

  @override
  State<_OutletVendorPickerSheet> createState() =>
      _OutletVendorPickerSheetState();
}

class _OutletVendorPickerSheetState extends State<_OutletVendorPickerSheet> {
  final _repo = OutletRepository();
  late final Future<List<OutletVendor>> _future = _repo.fetchVerifiedVendors();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Modal sheets get no keyboard handling from the framework (unlike Dialog,
    // ModalBottomSheetRoute never reads viewInsets), and this one is a FIXED
    // 75% of the FULL screen. Focusing the search box therefore puts the
    // keyboard straight over the bottom of the results — you type, and the
    // matches you're looking for are behind the keys. Measuring the 75%
    // against the space actually left, and lifting by the same inset, keeps
    // the whole list visible. The inset is 0 with no keyboard up, so this is
    // a no-op on both platforms otherwise.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(bottom: keyboardInset),
        height: (MediaQuery.of(context).size.height - keyboardInset) * 0.75,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                color: OutletColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Select verified vendor',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search vendor…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: OutletColors.bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<OutletVendor>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: OutletColors.success));
                  }
                  final q = _query.trim().toLowerCase();
                  final list = (snap.data ?? const [])
                      .where((v) =>
                          q.isEmpty ||
                          v.displayName.toLowerCase().contains(q) ||
                          v.contactPerson.toLowerCase().contains(q) ||
                          v.phone.contains(q) ||
                          v.city.toLowerCase().contains(q))
                      .toList();
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No matching vendors',
                          style: OutletTextStyles.prodSub),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: OutletColors.border),
                    itemBuilder: (context, i) => _row(list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(OutletVendor v) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: OutletColors.badgeGreenBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.storefront_rounded,
            color: OutletColors.grad1, size: 20),
      ),
      title: Text(v.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: OutletColors.textDark)),
      subtitle: Text(
        [
          if (v.phone.isNotEmpty) v.phone,
          if (v.city.isNotEmpty) v.city,
          if (v.pincode.isNotEmpty) v.pincode,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: OutletTextStyles.prodSub,
      ),
      trailing: const Icon(Icons.add_circle_outline, color: OutletColors.grad1),
      onTap: () => Navigator.of(context).pop(v),
    );
  }
}
