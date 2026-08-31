// =============================================================================
// VS Arogya — Outlet Billing (POS) · Step 2 · Product selection
//
// Picks medicines from the OUTLET's OWN stock only (never marketplace / vendor
// catalogue). Debounced search, live stock cap on every quantity control, and a
// premium row showing image, MRP, selling price, stock, batch and expiry. Reads
// and writes the shared BillingController cart.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../customer/customer_widgets.dart' show EmptyState;
import '../../../services/live_refresh.dart';
import '../../../theme/app_widgets.dart' show Debouncer;
import '../../../widgets/expiry_alert.dart';
import '../../outlet_models.dart';
import '../../outlet_repository.dart';
import '../../outlet_theme.dart';
import '../billing_controller.dart';
import '../billing_widgets.dart';

class BillingProductsStep extends StatefulWidget {
  const BillingProductsStep({super.key, required this.controller});

  final BillingController controller;

  @override
  State<BillingProductsStep> createState() => _BillingProductsStepState();
}

class _BillingProductsStepState extends State<BillingProductsStep>
    with LiveRefreshMixin<BillingProductsStep> {
  final _repo = OutletRepository();
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer();

  List<OutletStockItem> _all = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Keeps quantities AND the FEFO-front batch live while the counter is
    // picking: another till's bill, or a fresh assignment from Marketing,
    // shows up here without anyone pulling to refresh.
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  /// Silent re-fetch on the poll — never flips the list back to a spinner or
  /// clears what is on screen, so the user's scroll position and selection
  /// survive every refresh.
  @override
  Future<void> onLiveRefresh() => _load(silent: _all.isNotEmpty);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final stock = await _repo.fetchStock();
      if (!mounted) return;
      setState(() {
        // Own-outlet, in-stock items are billable.
        _all = stock.where((s) => s.isOwnOutlet).toList();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      // A failed poll keeps the last good list rather than blanking the screen.
      if (silent) return;
      setState(() {
        _loading = false;
        _error = 'Could not load stock. Check your connection and try again.';
      });
    }
  }

  List<OutletStockItem> get _results {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _searchBar(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: OutletColors.success))
              : _error != null
                  ? _errorState()
                  : RefreshIndicator(
                      color: OutletColors.success,
                      onRefresh: _load,
                      child: ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) {
                          final items = _results;
                          if (items.isEmpty) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.5,
                                  child: EmptyState(
                                    icon: Icons.inventory_2_outlined,
                                    title: _query.isEmpty
                                        ? 'No stock yet'
                                        : 'No matches',
                                    message: _query.isEmpty
                                        ? 'This outlet has no medicines in stock.'
                                        : 'No medicine matches "$_query".',
                                  ),
                                ),
                              ],
                            );
                          }
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ProductRow(
                              item: items[i],
                              controller: widget.controller,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) =>
            _debouncer.run(() => setState(() => _query = v.trim())),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search medicines…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: OutletColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: OutletColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: OutletColors.success, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 40, color: OutletColors.textMuted),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: OutletTextStyles.prodSub),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 160,
                child: BillingButton(label: 'Retry', onPressed: _load),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.item, required this.controller});

  final OutletStockItem item;
  final BillingController controller;

  @override
  Widget build(BuildContext context) {
    final qty = controller.qtyOf(item.id);
    final inCart = qty > 0;
    final out = item.qtyAvailable <= 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OutletColors.border),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumb(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: OutletTextStyles.prodName),
                if (item.packSize.isNotEmpty)
                  Text(item.packSize, style: OutletTextStyles.prodSub),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('₹${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: OutletColors.textDark)),
                    if (item.mrp > item.price)
                      Text('₹${item.mrp.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: OutletColors.textMuted,
                              decoration: TextDecoration.lineThrough)),
                    _stockChip(out),
                    // Colour-graded expiry of the lot this outlet sells NEXT.
                    ExpiryTierBadge(expiry: item.expiry, dense: true),
                  ],
                ),
                // WHICH BATCH will be billed — the outlet's own FEFO-front lot,
                // so the counter knows before adding the line. When more than
                // one lot is held, the row says so: the bill may span batches,
                // and the exact split is confirmed on the review step.
                if (item.batch.isNotEmpty || item.expiry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      [
                        if (item.batch.isNotEmpty) 'Batch ${item.batch}',
                        formatExpiry(item.expiry),
                        if (item.batchCount > 1)
                          '+${item.batchCount - 1} more batch'
                              '${item.batchCount > 2 ? 'es' : ''}',
                      ].join('  ·  '),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: expiryTierOf(item.expiry).color),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _trailing(context, inCart, qty, out),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context, bool inCart, int qty, bool out) {
    if (out) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('Out',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OutletColors.danger)),
      );
    }
    if (!inCart) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: BillingButton(
          label: 'Add',
          expand: false,
          onPressed: () => controller.add(item),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: BillingQtyStepper(
        qty: qty,
        atMax: qty >= item.qtyAvailable,
        onDecrement: () => controller.decrement(item.id),
        onIncrement: () => controller.increment(item.id),
        onEdit: () => showQtyEntryDialog(
          context,
          current: qty,
          max: item.qtyAvailable,
          onSet: (v) => controller.setQty(item.id, v),
        ),
      ),
    );
  }

  Widget _thumb() {
    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: OutletColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OutletColors.border),
      ),
      child: item.imageUrl.isEmpty
          ? const Icon(Icons.medication_outlined,
              color: OutletColors.textMuted, size: 24)
          : Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.medication_outlined,
                  color: OutletColors.textMuted, size: 24),
            ),
    );
  }

  Widget _stockChip(bool out) {
    final low = !out && item.qtyAvailable <= 5;
    final (bg, fg, label) = out
        ? (OutletColors.badgeRedBg, OutletColors.danger, 'Out of stock')
        : low
            ? (OutletColors.badgeAmberBg, OutletColors.amber,
                '${item.qtyAvailable} left')
            : (OutletColors.badgeGreenBg, OutletColors.success,
                '${item.qtyAvailable} in stock');
    return OutletBadge(label: label, bg: bg, fg: fg);
  }

}
