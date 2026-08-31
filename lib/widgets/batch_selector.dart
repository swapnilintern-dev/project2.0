// =============================================================================
// VS Arogya — Shared batch selector (FEFO)
//
// ONE picker, used everywhere a medicine's stock is committed:
//   • Marketing → Manual Order      (catalog batches)
//   • Marketing → Stock Assignment  (catalog batches)
//   • Outlet    → Billing           (that outlet's own batches)
//
// The batches are ALWAYS supplied by the backend, already sorted FEFO
// (First-Expiry-First-Out: nearest expiry first, then smallest lot, then oldest
// entry). This file never sorts, filters or invents inventory — it displays what
// the server returned and hands the user's choice back for the server to
// re-validate. Expired and empty lots are excluded server-side, so they simply
// never reach this picker.
//
// Behaviour required of every batch-aware screen:
//   • the nearest-expiry batch is pre-selected (Auto FEFO),
//   • the user may override it with any other valid batch,
//   • the running allocation must exactly match the requested quantity,
//   • no batch can give more than it holds, and none can be picked twice.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'expiry_alert.dart';

// -----------------------------------------------------------------------------
// Role-agnostic models
// -----------------------------------------------------------------------------

/// One batch the user may draw from, as returned by the backend. Identical in
/// shape for catalog batches (`productBatch`) and outlet batches
/// (`outletStockBatch`), which is what lets both roles share this picker.
class BatchOption {
  const BatchOption({
    required this.id,
    required this.batchNumber,
    required this.available,
    this.expiry,
    this.manufacturingDate,
    this.mrp = 0,
    this.sellingPrice = 0,
    this.supplier = '',
    this.isExpiringSoon = false,
  });

  /// The batch document's `_id` — what the backend pins an override to.
  final String id;
  final String batchNumber;

  /// Units still on hand in THIS lot (the cap for any allocation from it).
  final int available;

  final DateTime? expiry;
  final DateTime? manufacturingDate;

  /// The lot's own pricing, when it carries any (batches may be bought at
  /// different rates). Zero means "use the product's price".
  final double mrp;
  final double sellingPrice;

  final String supplier;

  /// The server's own ≤90-day flag, kept alongside the locally derived tier.
  final bool isExpiringSoon;

  /// Reads the shape both `/product/:id/available-batches` and
  /// `/outlet/product/:id/available-batches` return.
  factory BatchOption.fromJson(Map<String, dynamic> j) {
    double toDouble(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int toInt(Object? v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? toDate(Object? v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty || s == 'N/A') return null;
      return DateTime.tryParse(s);
    }

    return BatchOption(
      id: (j['_id'] ?? j['batch'] ?? '').toString(),
      batchNumber: (j['batch_number'] ?? '').toString(),
      available: toInt(j['available_quantity']),
      expiry: toDate(j['expiry_date']),
      manufacturingDate: toDate(j['manufacturing_date']),
      mrp: toDouble(j['purchase_price']),
      sellingPrice: toDouble(j['selling_price']),
      supplier: (j['supplier'] ?? '').toString(),
      isExpiringSoon: j['isExpiringSoon'] == true,
    );
  }

  ExpiryTier get tier => expiryTierOf(expiry);
}

/// A quantity pinned to a specific batch. This is exactly the `allocations`
/// entry every batch-aware endpoint accepts and returns.
class BatchAllocation {
  const BatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    this.expiry,
  });

  final String batchId;
  final String batchNumber;
  final int quantity;
  final DateTime? expiry;

  factory BatchAllocation.fromJson(Map<String, dynamic> j) {
    int toInt(Object? v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return BatchAllocation(
      batchId: (j['batch'] ?? j['_id'] ?? '').toString(),
      batchNumber: (j['batch_number'] ?? '').toString(),
      quantity: toInt(j['quantity']),
      expiry: j['expiry_date'] == null
          ? null
          : DateTime.tryParse(j['expiry_date'].toString()),
    );
  }

  /// The override payload the backend expects. Both identifiers are sent so the
  /// server can still resolve the lot if its id changed (e.g. a restore
  /// recreated it) — it matches on id first, then number.
  Map<String, dynamic> toJson() => {
        'batch': batchId,
        'batch_number': batchNumber,
        'quantity': quantity,
      };
}

/// Fills [quantity] across [batches] in the order the backend returned them —
/// i.e. FEFO. Used to pre-select the nearest-expiry lot(s) when the picker opens
/// and as the "Auto FEFO" reset. Purely a local preview of what the server would
/// do; the server still decides at commit time.
List<BatchAllocation> autoFefo(List<BatchOption> batches, int quantity) {
  final out = <BatchAllocation>[];
  var remaining = quantity;
  for (final b in batches) {
    if (remaining <= 0) break;
    final take = remaining < b.available ? remaining : b.available;
    if (take <= 0) continue;
    out.add(BatchAllocation(
      batchId: b.id,
      batchNumber: b.batchNumber,
      quantity: take,
      expiry: b.expiry,
    ));
    remaining -= take;
  }
  return out;
}

// -----------------------------------------------------------------------------
// The picker
// -----------------------------------------------------------------------------

/// Opens the batch picker for one line and returns the chosen allocation, or
/// null if the user backed out (leaving the previous choice intact).
///
/// [batches] must already be the backend's FEFO-ordered, sellable list.
/// [initial] seeds the editor with the current allocation so the user adjusts
/// from where the line is, rather than starting over.
Future<List<BatchAllocation>?> showBatchSelector({
  required BuildContext context,
  required String productName,
  required int quantity,
  required List<BatchOption> batches,
  List<BatchAllocation> initial = const [],
  int lowStockThreshold = 0,
}) {
  return showModalBottomSheet<List<BatchAllocation>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BatchSelectorSheet(
      productName: productName,
      quantity: quantity,
      batches: batches,
      initial: initial,
      lowStockThreshold: lowStockThreshold,
    ),
  );
}

class _BatchSelectorSheet extends StatefulWidget {
  const _BatchSelectorSheet({
    required this.productName,
    required this.quantity,
    required this.batches,
    required this.initial,
    required this.lowStockThreshold,
  });

  final String productName;
  final int quantity;
  final List<BatchOption> batches;
  final List<BatchAllocation> initial;
  final int lowStockThreshold;

  @override
  State<_BatchSelectorSheet> createState() => _BatchSelectorSheetState();
}

class _BatchSelectorSheetState extends State<_BatchSelectorSheet> {
  /// Units taken from each batch, keyed by batch id. Absent/0 = not selected.
  final Map<String, int> _qty = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initial.isEmpty) {
      // Nothing pinned yet → start from the FEFO answer, which is what the
      // backend would do anyway. The nearest expiry is therefore pre-selected.
      _seed(autoFefo(widget.batches, widget.quantity));
    } else {
      _seed(widget.initial);
    }
  }

  void _seed(List<BatchAllocation> allocations) {
    _qty.clear();
    for (final a in allocations) {
      // Ignore anything that is no longer offered (emptied/expired since).
      final match = widget.batches.where((b) => b.id == a.batchId);
      if (match.isEmpty) continue;
      final cap = match.first.available;
      _qty[a.batchId] = a.quantity > cap ? cap : a.quantity;
    }
  }

  int get _allocated => _qty.values.fold(0, (s, v) => s + v);
  int get _remaining => widget.quantity - _allocated;
  bool get _isBalanced => _remaining == 0;

  /// Batches matching the search box, in the backend's FEFO order (never
  /// re-sorted here — the server's order IS the policy).
  List<BatchOption> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.batches;
    return widget.batches
        .where((b) =>
            b.batchNumber.toLowerCase().contains(q) ||
            b.supplier.toLowerCase().contains(q))
        .toList();
  }

  void _setQty(BatchOption b, int value) {
    setState(() {
      final capped = value.clamp(0, b.available);
      if (capped == 0) {
        _qty.remove(b.id);
      } else {
        _qty[b.id] = capped;
      }
    });
  }

  /// Gives this batch as much of the still-unallocated quantity as it can hold.
  void _fillFrom(BatchOption b) {
    final want = (_qty[b.id] ?? 0) + _remaining;
    _setQty(b, want);
  }

  void _resetToFefo() {
    setState(() => _seed(autoFefo(widget.batches, widget.quantity)));
  }

  void _submit() {
    final out = <BatchAllocation>[];
    // Emit in FEFO order so the confirmation reads the same way as the list.
    for (final b in widget.batches) {
      final q = _qty[b.id] ?? 0;
      if (q <= 0) continue;
      out.add(BatchAllocation(
        batchId: b.id,
        batchNumber: b.batchNumber,
        quantity: q,
        expiry: b.expiry,
      ));
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    // Modal sheets get no keyboard handling from the framework — unlike Dialog,
    // ModalBottomSheetRoute never reads viewInsets. So when the batch search
    // above is focused, the keyboard covers the footer's Confirm button and the
    // sheet has no way to move. Lifting by the inset and measuring the 85% cap
    // against the space that's actually left keeps the footer reachable. With
    // no keyboard up the inset is 0, so this is a no-op on both platforms.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = (MediaQuery.of(context).size.height - keyboardInset) * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            _header(),
            if (widget.batches.length > 4) _searchField(),
            Flexible(
              child: widget.batches.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: _visible.length,
                      itemBuilder: (_, i) => _batchTile(_visible[i], i),
                    ),
            ),
            _footer(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Select Batch',
                    style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkText)),
              ),
              TextButton.icon(
                onPressed: widget.batches.isEmpty ? null : _resetToFefo,
                icon: const Icon(Icons.bolt_outlined, size: 16),
                label: const Text('Auto FEFO',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.darkGreen,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          Text(widget.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText)),
          const SizedBox(height: 2),
          const Text(
            'Nearest expiry first (FEFO). The top batch is selected for you — '
            'change it only when the business needs another lot.',
            style: TextStyle(fontSize: 11.5, color: AppColors.greyText),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search batch number, supplier…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _batchTile(BatchOption b, int index) {
    final taken = _qty[b.id] ?? 0;
    final selected = taken > 0;
    // The first row of the unfiltered list is the batch FEFO would use.
    final isFefoFront = widget.batches.isNotEmpty && widget.batches.first.id == b.id;
    final isLow =
        widget.lowStockThreshold > 0 && b.available <= widget.lowStockThreshold;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(b.batchNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
              ),
              if (isFefoFront) ...[
                _tag('FEFO', AppColors.darkGreen),
                const SizedBox(width: 4),
              ],
              ExpiryTierBadge(expiry: b.expiry, dense: true),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _fact(Icons.event_outlined, formatExpiry(b.expiry),
                  color: b.tier.color),
              _fact(Icons.timelapse_outlined, expiryCountdown(b.expiry)),
              _fact(Icons.inventory_outlined, '${b.available} available',
                  color: isLow ? const Color(0xFFE8710A) : null),
              if (b.manufacturingDate != null)
                _fact(Icons.precision_manufacturing_outlined,
                    'Mfg ${formatExpiry(b.manufacturingDate).replaceFirst('Exp ', '')}'),
              if (b.mrp > 0)
                _fact(Icons.local_offer_outlined,
                    'MRP ₹${b.mrp.toStringAsFixed(2)}'),
              if (b.sellingPrice > 0)
                _fact(Icons.sell_outlined,
                    'Rate ₹${b.sellingPrice.toStringAsFixed(2)}'),
              if (b.supplier.isNotEmpty)
                _fact(Icons.local_shipping_outlined, b.supplier),
              if (isLow) _tag('Low Stock', const Color(0xFFE8710A)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  selected ? 'Taking $taken from this batch' : 'Not selected',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          selected ? AppColors.darkGreen : AppColors.greyText),
                ),
              ),
              if (_remaining > 0)
                TextButton(
                  onPressed: () => _fillFrom(b),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Fill',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              _stepper(b, taken),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper(BatchOption b, int taken) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove,
              taken <= 0 ? null : () => _setQty(b, taken - 1)),
          SizedBox(
            width: 34,
            child: Text('$taken',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
          _stepBtn(
            Icons.add,
            // Never over-take from a lot, and never exceed the line's quantity.
            (taken >= b.available || _remaining <= 0)
                ? null
                : () => _setQty(b, taken + 1),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon,
              size: 16,
              color: onTap == null ? AppColors.border : AppColors.darkGreen),
        ),
      );

  Widget _fact(IconData icon, String label, {Color? color}) {
    final c = color ?? AppColors.greyText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 38, color: AppColors.greyText),
          SizedBox(height: 10),
          Text('No sellable batch',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            'Every batch of this medicine is either empty or past its expiry '
            'date, so none can be issued. Add a new batch to restock it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.greyText),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final over = _remaining < 0;
    final message = _isBalanced
        ? 'All ${widget.quantity} units allocated'
        : over
            ? '${-_remaining} unit(s) over the requested quantity'
            : '$_remaining of ${widget.quantity} unit(s) still unallocated';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _isBalanced
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 16,
                color: _isBalanced ? AppColors.darkGreen : AppColors.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(message,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _isBalanced
                            ? AppColors.darkGreen
                            : AppColors.error)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.greyText,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  // The line must be exactly filled — the backend rejects
                  // anything else, so the button enforces it up front.
                  onPressed: _isBalanced ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Use these batches',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Inline summary — the "which batch is being used" line every screen shows
// -----------------------------------------------------------------------------

/// Compact, always-visible statement of the batches a line will consume, with a
/// tap target to change them. This is what guarantees the user can never commit
/// stock without seeing which lot it comes from.
class BatchSummary extends StatelessWidget {
  const BatchSummary({
    super.key,
    required this.allocations,
    this.onChange,
    this.loading = false,
    this.error,
    this.unallocated = 0,
  });

  final List<BatchAllocation> allocations;
  final VoidCallback? onChange;
  final bool loading;
  final String? error;

  /// Units the backend could not place on any batch (0 when fully allocated).
  final int unallocated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: error != null || unallocated > 0
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 15, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(child: _body()),
          if (onChange != null)
            TextButton(
              onPressed: loading ? null : onChange,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(allocations.isEmpty ? 'Select' : 'Change',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Checking batches…',
            style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(error!,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.error)),
      );
    }
    if (allocations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('No batch selected',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.error)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in allocations)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Flexible(
                  child: Text('${a.batchNumber} × ${a.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText)),
                ),
                const SizedBox(width: 6),
                Text(formatExpiry(a.expiry),
                    style: TextStyle(
                        fontSize: 11, color: expiryTierOf(a.expiry).color)),
                const SizedBox(width: 4),
                ExpiryTierBadge(expiry: a.expiry, dense: true),
              ],
            ),
          ),
        if (unallocated > 0)
          Text('$unallocated unit(s) unallocated',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error)),
      ],
    );
  }
}
