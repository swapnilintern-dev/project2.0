// =============================================================================
// VS Arogya — Outlet Staff · Stock
//
// Two tabs (locked rule #1):
//   • My outlet  — the staff's OWN stock, FULL access (an "Add" control that
//                  Step 6 wires to the cart).
//   • District   — other outlets' stock in the district, READ-ONLY: there is no
//                  add / edit control on these rows at all. Shown so staff can
//                  see where stock exists across the district.
//
// Wired to [OutletRepository] (mock for now). Search + category filter run in
// memory over a single fetch.
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_cart.dart';
import '../outlet_models.dart';
import '../outlet_repository.dart';
import '../outlet_session.dart';
import '../outlet_theme.dart';
import '../../services/live_refresh.dart';

class OutletStockScreen extends StatefulWidget {
  const OutletStockScreen({super.key, required this.onAddToCart});

  /// Called when staff taps "Add" on an OWN-outlet row. District rows never
  /// call this — they render no add control. Wired to the cart in Step 6.
  final ValueChanged<OutletStockItem> onAddToCart;

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

  bool _ownTab = true;
  String _query = '';
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    // First load drives the FutureBuilder spinner; then poll silently so stock
    // stays live (immediate: false avoids a duplicate fetch on open).
    _future = _repo.fetchStock();
    startLiveRefresh(immediate: false);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  /// Silent background sync — fetches then swaps in an already-resolved future
  /// so the list never flashes the centered loader mid-poll.
  @override
  Future<void> onLiveRefresh() async {
    final stock = await _repo.fetchStock();
    if (mounted) setState(() => _future = Future.value(stock));
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.fetchStock());
    await _future;
  }

  List<OutletStockItem> _filter(List<OutletStockItem> all) {
    final q = _query.trim().toLowerCase();
    return all.where((s) {
      if (s.isOwnOutlet != _ownTab) return false;
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
        _tabToggle(),
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
                // Rebuild rows when the cart changes so the qty stepper stays
                // in sync with what's been added.
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

  // --- Tab toggle ------------------------------------------------------------

  Widget _tabToggle() {
    Widget seg(String label, IconData icon, bool own) {
      final active = _ownTab == own;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _ownTab = own),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: active ? OutletColors.headerGradient : null,
              color: active ? null : OutletColors.white,
              borderRadius: BorderRadius.circular(12),
              border: active ? null : Border.all(color: OutletColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 17,
                    color: active ? Colors.white : OutletColors.textMid),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          seg('My outlet', Icons.storefront_rounded, true),
          const SizedBox(width: 10),
          seg('District', Icons.map_outlined, false),
        ],
      ),
    );
  }

  // --- Search ----------------------------------------------------------------

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
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

  // --- Row -------------------------------------------------------------------

  Widget _stockRow(OutletStockItem s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: OutletTextStyles.prodName),
                const SizedBox(height: 2),
                Text(
                  [
                    if (s.packSize.isNotEmpty) s.packSize,
                    '₹${s.price.toStringAsFixed(0)}',
                    if (!s.isOwnOutlet && s.outletName.isNotEmpty) s.outletName,
                  ].join(' · '),
                  style: OutletTextStyles.prodSub,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _qtyBadge(s),
                    // Red "Expiring Soon" alert — Outlet is one of the two roles
                    // allowed to see it (locked to Marketing + Outlet).
                    if (s.isExpiringSoon) _expiryBadge(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ADD control ONLY for own-outlet, in-stock rows. District rows show a
          // read-only marker instead — enforcing locked rule #1 structurally.
          if (s.isOwnOutlet)
            _addOrStepper(s)
          else
            const _ReadOnlyMarker(),
        ],
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

  /// Red "Expiring Soon" pill shown when the batch expires within 90 days.
  Widget _expiryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OutletColors.badgeRedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.warning_amber_rounded, size: 13, color: OutletColors.danger),
          SizedBox(width: 4),
          Text('Expiring Soon',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OutletColors.danger)),
        ],
      ),
    );
  }

  /// Own-outlet trailing control: an "Add" button until the item is in the
  /// cart, then a live quantity stepper ("1 added" with − / +). The + is capped
  /// at the available stock so staff can't reserve more than exists.
  Widget _addOrStepper(OutletStockItem s) {
    final inCart = OutletCart.instance.quantityOf(s.id);
    if (inCart == 0) return _addButton(s);
    return _QtyStepper(
      qty: inCart,
      canIncrement: inCart < s.qtyAvailable,
      onDecrement: () => OutletCart.instance.decrement(s.id),
      onIncrement: () => OutletCart.instance.add(s),
    );
  }

  Widget _addButton(OutletStockItem s) {
    final enabled = s.inStock;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => widget.onAddToCart(s) : null,
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
                _ownTab
                    ? 'No matching items in your outlet'
                    : 'No matching district stock',
                style: OutletTextStyles.prodSub,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Inline quantity stepper shown on an own-outlet row once it's in the cart.
/// Reads "− [qty] +"; the + is disabled at the stock ceiling.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.canIncrement,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int qty;
  final bool canIncrement;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon,
                size: 16,
                color: onTap == null ? OutletColors.border : Colors.white),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        gradient: OutletColors.headerGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$qty',
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          btn(Icons.add, canIncrement ? onIncrement : null),
        ],
      ),
    );
  }
}

/// Read-only marker shown on district rows in place of an add control.
class _ReadOnlyMarker extends StatelessWidget {
  const _ReadOnlyMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OutletColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OutletColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_outline, size: 14, color: OutletColors.textMuted),
          SizedBox(width: 4),
          Text('Read-only',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: OutletColors.textMuted)),
        ],
      ),
    );
  }
}
