// =============================================================================
// VS Arogya — Outlet Staff · Stock
//
// ONE source of stock: the signed-in outlet's OWN inventory, read live from
// GET /vsArogya/outlet-products/:id. There is no district view — an outlet sells
// what it holds, so browsing other outlets' shelves has no place in the ordering
// flow and the option does not exist here at all.
//
// Each row is batch-aware end-to-end:
//   • "+ Add" opens the batch picker (lazy — batches are only fetched when the
//     sheet opens) and the medicine enters the cart pinned to the lot chosen;
//   • the row then shows an EDITABLE quantity — type it, or use − / + — capped
//     live at that lot's available units;
//   • "Change" re-opens the picker to re-pin the line, which re-caps quantity.
//
// Search + category filter run in memory over a single fetch. Stock auto-syncs
// via [LiveRefreshMixin] and re-reads immediately when [OutletStockSignal] fires
// (i.e. right after this app places an order that deducted stock).
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_batch_picker.dart';
import '../outlet_cart.dart';
import '../outlet_models.dart';
import '../outlet_qty_field.dart';
import '../outlet_repository.dart';
import '../outlet_session.dart';
import '../outlet_stock_signal.dart';
import '../outlet_theme.dart';
import '../../services/live_refresh.dart';
import '../../widgets/expiry_alert.dart';
import 'outlet_medicine_details_screen.dart';

class OutletStockScreen extends StatefulWidget {
  const OutletStockScreen({super.key, required this.onAddToCart});

  /// Called once staff have picked BOTH the medicine and the lot it will be
  /// issued from. The batch is part of the contract: an outlet line is never
  /// added to the cart without one.
  final void Function(OutletStockItem item, OutletBatch batch) onAddToCart;

  @override
  State<OutletStockScreen> createState() => _OutletStockScreenState();
}

class _OutletStockScreenState extends State<OutletStockScreen>
    with LiveRefreshMixin {
  final _repo = OutletRepository();

  /// Backs the pull-to-refresh gesture. Stock also auto-syncs via
  /// [LiveRefreshMixin], so quantity changes surface with no manual refresh.
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  late Future<List<OutletStockItem>> _future;

  String _query = '';
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    // First load drives the FutureBuilder spinner; then poll silently so stock
    // stays live (immediate: false avoids a duplicate fetch on open).
    _future = _repo.fetchStock();
    startLiveRefresh(immediate: false);
    // An order placed elsewhere in this app has already deducted stock on the
    // server — re-read at once rather than waiting for the next poll.
    OutletStockSignal.revision.addListener(_onStockSignal);
  }

  @override
  void dispose() {
    OutletStockSignal.revision.removeListener(_onStockSignal);
    stopLiveRefresh();
    super.dispose();
  }

  void _onStockSignal() {
    if (mounted) onLiveRefresh();
  }

  /// Silent background sync — fetches then swaps in an already-resolved future
  /// so the list never flashes the centered loader mid-poll. A failed sync keeps
  /// the last good list rather than blanking the screen.
  @override
  Future<void> onLiveRefresh() async {
    try {
      final stock = await _repo.fetchStock();
      if (mounted) setState(() => _future = Future.value(stock));
    } catch (_) {
      // Keep showing what we have; the visible error state belongs to the
      // first load and to pull-to-refresh, not to a background tick.
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.fetchStock());
    await _future;
  }

  /// Own-outlet rows only. The live endpoint returns nothing else, and this
  /// keeps that guarantee structural rather than incidental.
  List<OutletStockItem> _filter(List<OutletStockItem> all) {
    final q = _query.trim().toLowerCase();
    return all.where((s) {
      if (!s.isOwnOutlet) return false;
      if (_category != 'all' && s.category != _category) return false;
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutletHeader(
          title: 'Stock',
          subtitle: OutletSession.instance.outletLabel,
        ),
        _scopeBanner(),
        _searchField(),
        _categoryChips(),
        Expanded(
          child: RefreshIndicator(
            key: _refreshKey,
            onRefresh: _refresh,
            color: OutletColors.success,
            child: FutureBuilder<List<OutletStockItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child:
                          CircularProgressIndicator(color: OutletColors.success),
                    ),
                  );
                }
                // A failed fetch must NOT fall through to the empty state —
                // "no stock" and "couldn't load stock" mean very different
                // things to someone about to sell from this list.
                if (snap.hasError) return _error(snap.error.toString());
                final rows = _filter(snap.data ?? const []);
                if (rows.isEmpty) return _empty();
                // Rebuild rows when the cart changes so the quantity field and
                // the pinned batch stay in sync with what's been added.
                return ListenableBuilder(
                  listenable: OutletCart.instance,
                  builder: (context, _) => ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _stockRow(rows[i]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Scope banner ----------------------------------------------------------

  /// States plainly what this list is. It replaces the old My-outlet/District
  /// toggle: there is only one scope now, so it is a statement, not a choice.
  Widget _scopeBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: OutletColors.badgeGreenBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OutletColors.border),
        ),
        child: Row(
          children: const [
            Icon(Icons.storefront_rounded, size: 17, color: OutletColors.grad1),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Only outlet stock',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: OutletColors.grad1,
                ),
              ),
            ),
            Text(
              'Live quantities',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OutletColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Search ----------------------------------------------------------------

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 14, color: OutletColors.textDark),
        decoration: InputDecoration(
          hintText: 'Search medicines…',
          hintStyle: const TextStyle(color: OutletColors.textMuted, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: OutletColors.textMuted),
          filled: true,
          fillColor: OutletColors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: OutletColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: OutletColors.success),
          ),
        ),
      ),
    );
  }

  // --- Category chips --------------------------------------------------------

  Widget _categoryChips() {
    const cats = [
      ('all', 'All'),
      ('medicine', 'Medicine'),
      ('vaccines', 'Vaccines'),
      ('injections', 'Injections'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _category = c.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _category == c.$1
                        ? OutletColors.badgeGreenBg
                        : OutletColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _category == c.$1
                          ? OutletColors.success
                          : OutletColors.border,
                    ),
                  ),
                  child: Text(
                    c.$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _category == c.$1
                          ? OutletColors.success
                          : OutletColors.textMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Batch selection -------------------------------------------------------

  /// Opens the lot picker for [s] and, when a lot is chosen, hands both to the
  /// host so the line enters the cart already pinned. Selecting a batch is the
  /// FIRST step of adding — nothing is added if the sheet is dismissed.
  Future<void> _addWithBatch(OutletStockItem s) async {
    final batch = await showOutletBatchPicker(
      context: context,
      productId: s.id,
      productName: s.name,
      repository: _repo,
    );
    if (batch == null || !mounted) return;
    widget.onAddToCart(s, batch);
  }

  /// Re-pins an existing cart line to another lot. The quantity is re-capped by
  /// the cart against the new lot's availability.
  Future<void> _changeBatch(OutletStockItem s, OutletCartLine line) async {
    final batch = await showOutletBatchPicker(
      context: context,
      productId: s.id,
      productName: s.name,
      selectedBatchId: line.batchId,
      repository: _repo,
    );
    if (batch == null || !mounted) return;
    OutletCart.instance.setBatch(s.id, batch);
  }

  // --- Row -------------------------------------------------------------------

  /// Opens the batch-wise detail for a row. The endpoint is scoped to the
  /// signed-in outlet's own inventory, which is exactly what this list is.
  void _openDetails(OutletStockItem s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OutletMedicineDetailsScreen(item: s),
      ),
    );
  }

  Widget _stockRow(OutletStockItem s) {
    final line = OutletCart.instance.lineOf(s.id);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(s.name,
                              style: OutletTextStyles.prodName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 3),
                        // Affordance for the batch-wise detail screen.
                        const Icon(Icons.chevron_right,
                            size: 16, color: OutletColors.textMuted),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (s.packSize.isNotEmpty) s.packSize,
                        '₹${s.price.toStringAsFixed(0)}',
                      ].join(' · '),
                      style: OutletTextStyles.prodSub,
                    ),
                    // BATCH — once the line is in the cart this is the lot the
                    // user PINNED; before that it is the outlet's FEFO-front lot
                    // (what the picker will pre-select), straight from the
                    // server. Never computed here.
                    _batchLine(s, line),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _qtyBadge(s),
                        // Colour-graded expiry alert — Outlet is one of the two
                        // roles allowed to see it (locked to Marketing + Outlet).
                        ExpiryTierBadge(expiry: line?.expiry ?? s.expiry),
                        if ((line?.expiry ?? s.expiry) != null)
                          Text(expiryCountdown(line?.expiry ?? s.expiry),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: expiryTierOf(line?.expiry ?? s.expiry)
                                      .color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // "+ Add" until the medicine is in the cart, then the editable
              // quantity control.
              if (line == null)
                _addButton(s)
              else
                OutletQtyField(
                  qty: line.qty,
                  max: line.maxQty,
                  onSet: (v) => OutletCart.instance.setQty(s.id, v),
                  onRemove: () => OutletCart.instance.remove(s.id),
                ),
            ],
          ),
          if (line != null) _pinnedFooter(s, line),
        ],
      ),
    );

    // Tapping the row opens the batch-wise detail. The Add control, the quantity
    // field and "Change" all keep their own gestures, so neither adding to the
    // cart nor editing a quantity ever navigates by accident.
    return Semantics(
      button: true,
      label: 'View batches for ${s.name}',
      child: InkWell(
        onTap: () => _openDetails(s),
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }

  /// The batch / expiry strip under the product name.
  Widget _batchLine(OutletStockItem s, OutletCartLine? line) {
    final batch = line?.batch ?? s.batch;
    final expiry = line?.expiry ?? s.expiry;
    if (batch.isEmpty && expiry == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        [
          if (batch.isNotEmpty) 'Batch $batch',
          formatExpiry(expiry),
          // Before a lot is pinned, say how many others exist; afterwards the
          // pinned lot's own availability is the number that matters.
          if (line == null && s.batchCount > 1)
            '+${s.batchCount - 1} more batch${s.batchCount > 2 ? 'es' : ''}',
          if (line != null && line.batchAvailable > 0)
            '${line.batchAvailable} in this lot',
        ].join('  ·  '),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: expiryTierOf(expiry).color),
      ),
    );
  }

  /// Footer shown only for a line already in the cart: which lot it is pinned
  /// to, the running line total, and the action to re-pin it.
  Widget _pinnedFooter(OutletStockItem s, OutletCartLine line) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: OutletColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OutletColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 15, color: OutletColors.grad1),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '${line.qty} × ₹${line.price.toStringAsFixed(0)} = '
                '₹${line.lineTotal.toStringAsFixed(0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: OutletColors.textDark),
              ),
            ),
            TextButton(
              onPressed: () => _changeBatch(s, line),
              style: TextButton.styleFrom(
                foregroundColor: OutletColors.grad1,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('Change batch',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBadge(OutletStockItem s) {
    late final Color bg, fg;
    late final String label;
    if (s.qtyAvailable <= 0) {
      bg = OutletColors.badgeRedBg;
      fg = OutletColors.danger;
      label = 'Out of stock';
    } else if (s.qtyAvailable <= 5) {
      bg = OutletColors.badgeAmberBg;
      fg = OutletColors.amber;
      label = 'Low · ${s.qtyAvailable} left';
    } else {
      bg = OutletColors.badgeGreenBg;
      fg = OutletColors.success;
      label = '${s.qtyAvailable} in stock';
    }
    return OutletBadge(label: label, bg: bg, fg: fg);
  }

  Widget _addButton(OutletStockItem s) {
    final enabled = s.inStock;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _addWithBatch(s) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: OutletColors.headerGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Add',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shown when the stock fetch failed — carries the server's own reason and a
  /// retry, so staff can tell "couldn't load" apart from "nothing in stock".
  Widget _error(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 0),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 40, color: OutletColors.textMuted),
              const SizedBox(height: 10),
              Text(
                'Could not load stock',
                textAlign: TextAlign.center,
                style: OutletTextStyles.prodName,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: OutletTextStyles.prodSub,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: OutletColors.success),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 40, color: OutletColors.textMuted),
              const SizedBox(height: 10),
              Text(
                _query.trim().isEmpty && _category == 'all'
                    ? 'No stock in your outlet yet'
                    : 'No matching items in your outlet',
                style: OutletTextStyles.prodSub,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
