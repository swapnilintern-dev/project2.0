// =============================================================================
// MediCaPlus — Marketing · Create Manual Order
//
// Vendors sometimes phone their order in. This screen lets the Marketing role
// create that order ON THE VENDOR'S BEHALF:
//
//   pick vendor (searchable, live from /all-vendors)
//     → add products (searchable catalogue with LIVE stock)
//       → set quantities (validated against available stock)
//         → review summary → submit (POST /vsArogya/manual-order).
//
// The created order is flagged source: "MANUAL_BY_MARKETING" (createdBy is set
// server-side from the auth token) and then flows through the SAME lifecycle
// as a vendor-placed order — it appears in this pipeline as Pending AND in the
// vendor's own panel. Submission is idempotent: one clientOrderId is generated
// per screen and reused across retries, and the submit button is disabled
// while a request is in flight, so a mid-submit network drop can never create
// a duplicate order.
//
// BATCHES — every line is batch-aware. Selecting a medicine loads its sellable
// catalog batches live from the backend (FEFO: nearest expiry first) and the
// server allocates the quantity across them, so the user always sees which lot
// is being sold. The nearest-expiry batch is pre-selected; the user may pin a
// different valid one, and the pinned choice travels with the cart line and is
// re-validated by the server at placement. Nothing here computes inventory —
// every allocation comes from /allocate-preview.
// =============================================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart'
    show formatRupees, showAppSnack, PrimaryButton, EmptyState;
import '../widgets/batch_selector.dart';
import '../widgets/expiry_alert.dart';
import 'marketing_api.dart';
import 'marketing_controllers.dart';
import 'marketing_models.dart';

/// One order line being composed: the product, the chosen quantity, and the
/// batches the backend allocated (or the user pinned) for it.
class _ManualLine {
  _ManualLine(this.product, this.quantity);

  InventoryProduct product;
  int quantity;

  /// The product's sellable batches, straight from the backend in FEFO order.
  List<BatchOption> batches = const [];

  /// How the quantity is spread across those batches — always the server's
  /// answer, whether auto-FEFO or a validated override.
  List<BatchAllocation> allocations = const [];

  /// Units the backend could not place on any sellable batch (0 when fine).
  int unallocated = 0;

  /// True while a batch load / allocation preview is in flight for this line.
  bool loading = false;

  /// The last batch-related error the backend returned for this line.
  String? error;

  /// Set once the user pins a batch, so a later quantity change re-sends the
  /// pinned lots instead of silently reverting to plain FEFO.
  bool overridden = false;

  /// A line may only be ordered when the server has fully allocated it.
  bool get isAllocated =>
      error == null && !loading && allocations.isNotEmpty && unallocated == 0;
}

class ManualOrderScreen extends StatefulWidget {
  const ManualOrderScreen({super.key});

  @override
  State<ManualOrderScreen> createState() => _ManualOrderScreenState();
}

class _ManualOrderScreenState extends State<ManualOrderScreen> {
  VendorAccount? _vendor;
  final List<_ManualLine> _lines = [];
  bool _submitting = false;
  String? _error;

  /// IDEMPOTENCY KEY — generated once per screen and reused on every retry,
  /// so if the network drops mid-submit and the user retries, the backend can
  /// recognise the duplicate instead of creating a second order.
  final String _clientOrderId =
      'MO-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9000) + 1000}';

  MarketingProductsController get _products =>
      MarketingProductsController.instance;
  MarketingVendorsController get _vendors =>
      MarketingVendorsController.instance;

  /// Batch reads + allocation previews. The backend is the only authority on
  /// which lots exist and how a quantity spreads across them.
  final BatchApi _batchApi = BatchApi();

  /// Per-line debounce timers so rapid +/- taps collapse into one preview call.
  final Map<String, Timer> _allocDebouncers = {};

  @override
  void initState() {
    super.initState();
    // Fresh vendor directory + LIVE stock, so quantities validate against the
    // server's current numbers, not a stale cache.
    _vendors.refresh();
    _products.refresh();
  }

  @override
  void dispose() {
    for (final t in _allocDebouncers.values) {
      t.cancel();
    }
    _allocDebouncers.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------------------

  /// The product's CURRENT record from the live inventory (stock may have
  /// changed since it was added to the order), falling back to the snapshot.
  InventoryProduct _live(InventoryProduct p) => _products.byId(p.id) ?? p;

  double get _subtotal =>
      _lines.fold(0.0, (sum, l) => sum + _live(l.product).price * l.quantity);

  int get _unitCount => _lines.fold(0, (sum, l) => sum + l.quantity);

  /// Lines whose quantity now exceeds the live stock (e.g. stock changed while
  /// composing the order). Submission is blocked until they're fixed.
  List<_ManualLine> get _overStockLines =>
      _lines.where((l) => l.quantity > _live(l.product).stock).toList();

  /// Lines the backend has not fully allocated to batches yet (still loading,
  /// short on sellable stock, or errored). The order cannot be placed until
  /// every line names the exact lots it will consume.
  List<_ManualLine> get _unallocatedLines =>
      _lines.where((l) => !l.isAllocated).toList();

  bool get _canSubmit =>
      !_submitting &&
      _vendor != null &&
      _lines.isNotEmpty &&
      _overStockLines.isEmpty &&
      _unallocatedLines.isEmpty;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickVendor() async {
    final picked = await showModalBottomSheet<VendorAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _VendorPickerSheet(),
    );
    if (picked != null && mounted) {
      setState(() => _vendor = picked);
    }
  }

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<InventoryProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ProductPickerSheet(
        alreadyAdded: _lines.map((l) => l.product.id).toSet(),
      ),
    );
    if (picked != null && mounted) {
      final line = _ManualLine(picked, 1);
      setState(() => _lines.add(line));
      // Pull this product's sellable batches and let the server allocate the
      // first unit — so the line shows its FEFO batch straight away.
      unawaited(_loadBatches(line));
    }
  }

  void _setQuantity(_ManualLine line, int quantity) {
    final stock = _live(line.product).stock;
    if (quantity <= 0) {
      _allocDebouncers.remove(line.product.id)?.cancel();
      setState(() => _lines.remove(line));
      return;
    }
    if (quantity > stock) {
      showAppSnack(context, 'Only $stock in stock for ${line.product.name}',
          success: false);
      return;
    }
    setState(() {
      line.quantity = quantity;
      if (!line.overridden) {
        // No manual pin — the previous split no longer covers the new
        // quantity, so let the server recompute it from scratch.
        line.allocations = const [];
      } else {
        // A pin that now exceeds the line would be rejected by the server
        // ("allocated more than the requested quantity"), so a reduction below
        // what was pinned drops back to FEFO. A pin that still fits is kept and
        // the server auto-fills the difference.
        final pinned = line.allocations.fold(0, (s, a) => s + a.quantity);
        if (pinned > quantity) {
          line.overridden = false;
          line.allocations = const [];
        }
      }
    });
    _scheduleAllocation(line);
  }

  // ---------------------------------------------------------------------------
  // Batches (backend is the single source of truth)
  // ---------------------------------------------------------------------------

  /// Loads a line's sellable batches (FEFO order) and then allocates its
  /// current quantity across them.
  Future<void> _loadBatches(_ManualLine line) async {
    setState(() {
      line.loading = true;
      line.error = null;
    });

    final (batches, error) = await _batchApi.getAvailableBatches(line.product.id);
    if (!mounted || !_lines.contains(line)) return;

    if (batches == null) {
      setState(() {
        line.loading = false;
        line.error = error;
      });
      return;
    }

    setState(() {
      line.batches = batches;
      line.loading = false;
    });

    if (batches.isEmpty) {
      setState(() {
        line.allocations = const [];
        line.unallocated = line.quantity;
        line.error = 'No sellable batch — every lot is empty or expired.';
      });
      return;
    }
    await _refreshAllocation(line);
  }

  /// Debounced allocation refresh, so holding down "+" issues one call.
  void _scheduleAllocation(_ManualLine line) {
    final key = line.product.id;
    _allocDebouncers[key]?.cancel();
    _allocDebouncers[key] = Timer(
      const Duration(milliseconds: 350),
      () => _refreshAllocation(line),
    );
  }

  /// Asks the backend how this line's quantity spreads across its batches. When
  /// the user has pinned lots those are sent as overrides — the server validates
  /// them and fills any remainder FEFO, then returns the corrected answer.
  Future<void> _refreshAllocation(_ManualLine line) async {
    if (!mounted || !_lines.contains(line)) return;
    setState(() {
      line.loading = true;
      line.error = null;
    });

    final (allocations, remaining, error) = await _batchApi.previewAllocation(
      line.product.id,
      line.quantity,
      overrides: line.overridden ? line.allocations : const [],
    );

    if (!mounted || !_lines.contains(line)) return;
    setState(() {
      line.loading = false;
      if (error != null) {
        line.error = error;
        return;
      }
      line.allocations = allocations;
      line.unallocated = remaining;
      line.error = remaining > 0
          ? 'Only ${line.quantity - remaining} unit(s) available in sellable '
              'batches (expired lots cannot be sold).'
          : null;
    });
  }

  /// Opens the shared FEFO picker so the user can choose a different lot. The
  /// pick is sent straight back to the server for validation, so what is shown
  /// afterwards is always the server's allocation, never a local guess.
  Future<void> _pickBatches(_ManualLine line) async {
    if (line.batches.isEmpty) {
      await _loadBatches(line);
      if (!mounted || line.batches.isEmpty) return;
    }

    final picked = await showBatchSelector(
      context: context,
      productName: line.product.name,
      quantity: line.quantity,
      batches: line.batches,
      initial: line.allocations,
      lowStockThreshold: _live(line.product).lowThreshold,
    );
    if (picked == null || !mounted) return;

    setState(() {
      line.overridden = true;
      line.allocations = picked;
    });
    _allocDebouncers.remove(line.product.id)?.cancel();
    await _refreshAllocation(line);
  }

  Future<void> _submit() async {
    // Last-second validation against the freshest stock we have — the backend
    // remains the final authority (it re-checks atomically at accept time).
    if (_vendor == null) {
      showAppSnack(context, 'Select a vendor first', success: false);
      return;
    }
    if (_lines.isEmpty) {
      showAppSnack(context, 'Add at least one product', success: false);
      return;
    }
    final over = _overStockLines;
    if (over.isNotEmpty) {
      final l = over.first;
      showAppSnack(
        context,
        'Insufficient stock for ${l.product.name}: '
        'available ${_live(l.product).stock}, ordered ${l.quantity}',
        success: false,
      );
      return;
    }
    // Every line must name the exact lots it consumes before the order is
    // placed — the server enforces this too, but failing here is clearer.
    final pending = _unallocatedLines;
    if (pending.isNotEmpty) {
      final l = pending.first;
      showAppSnack(
        context,
        l.error ?? 'Still checking batches for ${l.product.name}…',
        success: false,
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final (_, error) =
        await MarketingOrdersController.instance.createManualOrder(
      vendorId: _vendor!.id,
      items: {for (final l in _lines) l.product.id: l.quantity},
      clientOrderId: _clientOrderId,
      // The exact batches this order draws from. The server re-validates them
      // against live stock and deducts those lots only.
      batches: {for (final l in _lines) l.product.id: l.allocations},
    );
    if (!mounted) return;
    if (error != null) {
      // Keep everything the user entered; the button becomes a safe retry
      // (same clientOrderId → no duplicate even if the first call landed).
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    // The orders list refresh already ran inside createManualOrder; the
    // parent screen shows the confirmation snack.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('Create Manual Order',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: _products,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _stepTitle('1. Vendor (order placed on their behalf)'),
              const SizedBox(height: 8),
              _vendorCard(),
              const SizedBox(height: 18),
              _stepTitle('2. Products'),
              const SizedBox(height: 8),
              _productsCard(),
              const SizedBox(height: 18),
              _stepTitle('3. Review'),
              const SizedBox(height: 8),
              _summaryCard(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorBanner(_error!),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: PrimaryButton(
          label: _submitting
              ? 'Placing order…'
              : (_error != null ? 'Retry — Place Order' : 'Place Order for Vendor'),
          icon: _submitting ? null : Icons.check_circle_outline,
          loading: _submitting,
          onPressed: _canSubmit ? _submit : null,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _stepTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: AppColors.darkText));

  Widget _vendorCard() {
    final v = _vendor;
    return _card(
      child: v == null
          ? InkWell(
              onTap: _pickVendor,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: const [
                    Icon(Icons.storefront_outlined,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Select vendor…',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.greyText)),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.greyText),
                  ],
                ),
              ),
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.lightGreenBg,
                  child: Text(v.initials,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.darkGreen)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.storeName,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (v.contactPerson.isNotEmpty) v.contactPerson,
                          if (v.phone.isNotEmpty) v.phone,
                          if (v.city.isNotEmpty) v.city,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.greyText),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _pickVendor,
                  child: const Text('Change',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
    );
  }

  Widget _productsCard() {
    return _card(
      child: Column(
        children: [
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No products added yet. Add the medicines the vendor asked '
                'for over the phone.',
                style: TextStyle(fontSize: 12.5, color: AppColors.greyText),
              ),
            )
          else
            for (int i = 0; i < _lines.length; i++) ...[
              if (i > 0) const Divider(height: 18, color: AppColors.border),
              _lineRow(_lines[i]),
            ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add product',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(_ManualLine line) {
    final live = _live(line.product);
    final over = line.quantity > live.stock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(live.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(live.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(formatRupees(live.price),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.greyText)),
                      const SizedBox(width: 8),
                      _stockBadge(live),
                    ],
                  ),
                ],
              ),
            ),
            _qtyStepper(line, live),
            IconButton(
              onPressed: () => setState(() => _lines.remove(line)),
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.greyText),
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 50),
            child: Text(
              'Insufficient stock: available ${live.stock}, ordered ${line.quantity}',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error),
            ),
          ),
        // WHICH BATCH IS BEING SOLD — always visible, never a guess. Tapping
        // "Change" opens the FEFO picker with the other valid lots.
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BatchSummary(
            allocations: line.allocations,
            unallocated: line.unallocated,
            loading: line.loading,
            error: line.error,
            onChange: () => _pickBatches(line),
          ),
        ),
      ],
    );
  }

  Widget _qtyStepper(_ManualLine line, InventoryProduct live) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, () => _setQuantity(line, line.quantity - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('${line.quantity}',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
          _stepBtn(
            Icons.add,
            line.quantity >= live.stock
                ? null
                : () => _setQuantity(line, line.quantity + 1),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 16,
              color: onTap == null ? AppColors.border : AppColors.darkGreen),
        ),
      );

  Widget _summaryCard() {
    return _card(
      child: Column(
        children: [
          _summaryRow('Vendor', _vendor?.storeName ?? '—'),
          const SizedBox(height: 8),
          _summaryRow('Products', '${_lines.length}'),
          const SizedBox(height: 8),
          _summaryRow('Units', '$_unitCount'),
          const Divider(height: 20, color: AppColors.border),
          _summaryRow('Subtotal', formatRupees(_subtotal), bold: true),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'GST and any coupon discounts are applied by the server on the '
              'final invoice, exactly like a vendor-placed order.',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 14.5 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? AppColors.darkText : AppColors.greyText)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: FontWeight.w800,
                color: bold ? AppColors.darkGreen : AppColors.darkText)),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}

/// Stock badge matching the inventory colours (In Stock / Low / Out).
Widget _stockBadge(InventoryProduct p) {
  final s = p.stockStatus;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: s.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      s == StockStatus.out ? 'Out of stock' : '${p.stock} in stock',
      style: TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w800, color: s.color),
    ),
  );
}

// =============================================================================
// Vendor picker sheet — searchable, live from the backend, with loading /
// error+retry / empty states. Pops with the chosen VendorAccount.
// =============================================================================

class _VendorPickerSheet extends StatefulWidget {
  const _VendorPickerSheet();

  @override
  State<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends State<_VendorPickerSheet> {
  String _query = '';

  MarketingVendorsController get _vendors =>
      MarketingVendorsController.instance;

  @override
  Widget build(BuildContext context) {
    return _pickerScaffold(
      context: context,
      title: 'Select Vendor',
      hint: 'Search store, contact, phone…',
      onQuery: (v) => setState(() => _query = v),
      child: ListenableBuilder(
        listenable: _vendors,
        builder: (context, _) {
          if (_vendors.isLoading && !_vendors.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_vendors.error != null && !_vendors.isLoaded) {
            return _pickerError(_vendors.error!, _vendors.refresh);
          }
          final q = _query.toLowerCase();
          final list = _vendors.vendors
              .where((v) =>
                  q.isEmpty ||
                  v.storeName.toLowerCase().contains(q) ||
                  v.contactPerson.toLowerCase().contains(q) ||
                  v.phone.contains(q))
              .toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No vendors found',
              message: 'No registered vendor matches your search.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, i) {
              final v = list[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.lightGreenBg,
                  child: Text(v.initials,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.darkGreen)),
                ),
                title: Text(v.storeName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [
                    if (v.contactPerson.isNotEmpty) v.contactPerson,
                    if (v.phone.isNotEmpty) v.phone,
                    if (v.city.isNotEmpty) v.city,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.greyText),
                ),
                onTap: () => Navigator.of(context).pop(v),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// Product picker sheet — searchable catalogue with LIVE stock. Out-of-stock
// and already-added products cannot be selected. Pops with the product.
// =============================================================================

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.alreadyAdded});

  final Set<String> alreadyAdded;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  MarketingProductsController get _products =>
      MarketingProductsController.instance;

  @override
  Widget build(BuildContext context) {
    return _pickerScaffold(
      context: context,
      title: 'Add Product',
      hint: 'Search medicine, brand…',
      onQuery: (v) => setState(() => _query = v),
      child: ListenableBuilder(
        listenable: _products,
        builder: (context, _) {
          if (_products.isLoading && !_products.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final q = _query.toLowerCase();
          // Only active (customer-visible) products can be ordered.
          final list = _products.activeProducts
              .where((p) =>
                  q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.brand.toLowerCase().contains(q))
              .toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.medication_outlined,
              title: 'No products found',
              message: 'No active product matches your search.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, i) {
              final p = list[i];
              final added = widget.alreadyAdded.contains(p.id);
              final selectable = !added && p.stock > 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: selectable,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(p.icon, color: AppColors.primary, size: 20),
                ),
                title: Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selectable
                            ? AppColors.darkText
                            : AppColors.greyText)),
                // The FEFO-front batch, read from the product's server-synced
                // mirror (batch_no/exp_date are always the nearest-expiry lot),
                // so the user knows which stock they are about to sell before
                // even adding the line — no extra request per row.
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(formatRupees(p.price),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.greyText)),
                        const SizedBox(width: 8),
                        _stockBadge(p),
                      ],
                    ),
                    if (p.batchNo.isNotEmpty || p.expiryDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            if (p.batchNo.isNotEmpty) ...[
                              Flexible(
                                child: Text('Batch ${p.batchNo}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkText)),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(formatExpiry(p.expiryDate),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: expiryTierOf(p.expiryDate).color)),
                            const SizedBox(width: 4),
                            ExpiryTierBadge(expiry: p.expiryDate, dense: true),
                          ],
                        ),
                      ),
                  ],
                ),
                isThreeLine: p.batchNo.isNotEmpty || p.expiryDate != null,
                trailing: added
                    ? const Text('Added',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greyText))
                    : null,
                onTap:
                    selectable ? () => Navigator.of(context).pop(p) : null,
              );
            },
          );
        },
      ),
    );
  }
}

// --- shared picker chrome -----------------------------------------------------

Widget _pickerScaffold({
  required BuildContext context,
  required String title,
  required String hint,
  required ValueChanged<String> onQuery,
  required Widget child,
}) {
  // Modal sheets get no keyboard handling from the framework (unlike Dialog,
  // ModalBottomSheetRoute never reads viewInsets), and this chrome is a FIXED
  // 75% of the FULL screen. Focusing the search box puts the keyboard straight
  // over the bottom of the results — you type, and the matches are behind the
  // keys. Measuring the 75% against the space actually left, and lifting by the
  // same inset, keeps the whole list visible. The inset is 0 with no keyboard
  // up, so this is a no-op on both platforms otherwise.
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
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: onQuery,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppColors.pageBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

Widget _pickerError(String message, Future<void> Function() onRetry) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: AppColors.greyText),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.greyText)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkGreen,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    ),
  );
}
