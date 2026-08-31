// =============================================================================
// MediCaPlus — Marketing Head · Select Outlet (Outlet Order flow)
//
// Entry screen for the marketing-head outlet-ordering flow described in the
// spec: enter a pincode → pick an outlet in that pincode → (later) select
// product → quantity → done.
//
// This is an UPDATE-STOCK flow for our own outlets, not a customer order — so
// there is NO price / money anywhere. The head enters a pincode, picks an
// outlet, searches a medicine, types a QUANTITY, adds it, and taps "Done" to
// move that stock into the outlet.
//
// Fully live:
//   • outlets   → GET  /vsArogya/outlets?pincode=
//   • medicines → the real catalog (MarketingProductsController)
//   • Done      → POST /vsArogya/outlet-stock, ONE call per medicine
//
// The server ADDS to whatever the outlet already holds and deducts the same
// amount from the global product stock, so quantities here are "how much more
// to send", not "set the outlet's stock to this".
//
// BATCH SELECTION IS MANDATORY. Stock is physical: the head must state exactly
// which lot leaves the warehouse, so "Add" always goes through the FEFO picker
// (sellable batches only, nearest expiry first, pre-selected). The chosen lots
// travel with the assignment; the server consumes those catalog batches and
// records the SAME batch identity on the outlet's stock, so the outlet knows
// precisely which lots — and expiries — it received.
// =============================================================================

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../widgets/batch_selector.dart';
import '../widgets/expiry_alert.dart';
import 'marketing_api.dart';
import 'marketing_controllers.dart';
import 'marketing_models.dart';

class SelectOutletScreen extends StatefulWidget {
  const SelectOutletScreen({super.key});

  @override
  State<SelectOutletScreen> createState() => _SelectOutletScreenState();
}

class _SelectOutletScreenState extends State<SelectOutletScreen> {
  final TextEditingController _pinController = TextEditingController();

  /// The pincode that was last searched (empty until "Find outlets" is tapped
  /// with a valid 6-digit pincode). Drives the searched-state UI below.
  String _searchedPin = '';

  /// Inline validation message shown under the field (empty = no error).
  String _error = '';

  /// Outlets returned for [_searchedPin] (empty when none / not yet searched).
  List<MarketingOutlet> _outlets = const [];

  /// The outlet currently chosen in the dropdown (null until one is picked).
  MarketingOutlet? _selectedOutlet;

  final _api = OutletApi();

  /// True while the pincode lookup is in flight.
  bool _finding = false;

  /// True while "Done" is posting the stock assignment.
  bool _saving = false;

  /// The real catalog — the same products the whole app sells. These ids are
  /// the Mongo _ids POST /outlet-stock expects, so this can NOT come from a
  /// mock: the server would reject a made-up id with "Product not found".
  List<InventoryProduct> get _products =>
      MarketingProductsController.instance.products;

  /// Medicine search box controller + current query (lower-cased on read).
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  /// Chosen quantity per product id. Absent / 0 = not in the order.
  final Map<String, int> _qty = {};

  /// The lots each product will be sent from, keyed by product id. A product is
  /// only ever added to the order together with its batches, so an entry here
  /// exists for every entry in [_qty] — there is no "assigned but unbatched"
  /// state.
  final Map<String, List<BatchAllocation>> _alloc = {};

  /// Batch reads for the picker. The backend decides which lots are sellable
  /// and in what order; this screen only displays and returns the choice.
  final BatchApi _batchApi = BatchApi();

  /// True while a product's batches are being fetched for the picker.
  String? _loadingBatchesFor;

  /// Per-product quantity input controllers for the search-result boxes.
  /// Created lazily and reused; all disposed in [dispose].
  final Map<String, TextEditingController> _qtyControllers = {};

  /// Search-result matches for the current query (empty when the query is
  /// blank — there is no always-on list; results only show after typing).
  List<InventoryProduct> get _searchResults {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _products
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  /// Products currently in the order (qty > 0), in catalog order.
  List<InventoryProduct> get _orderedProducts =>
      _products.where((p) => (_qty[p.id] ?? 0) > 0).toList();

  /// The quantity controller for [productId], seeded with "1" on first use.
  TextEditingController _qtyControllerFor(String productId) =>
      _qtyControllers.putIfAbsent(
        productId,
        () => TextEditingController(text: '1'),
      );

  int get _totalItems => _qty.values.fold(0, (sum, q) => sum + q);

  @override
  void initState() {
    super.initState();
    // The shell warms the catalog at login, but this screen can be reached
    // before that lands (or after a failed refresh) — without products the
    // medicine search would silently find nothing.
    final products = MarketingProductsController.instance;
    if (products.products.isEmpty) {
      products.refresh();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _searchController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Adds (or updates) [product] in the order using the quantity typed in its
  /// box. Invalid / empty quantity is rejected with a hint.
  ///
  /// Batch selection is MANDATORY, so this always opens the FEFO picker and
  /// only records the line once the head has confirmed which lots to send.
  /// Backing out of the picker leaves the order untouched.
  Future<void> _addProduct(InventoryProduct product) async {
    final raw = _qtyControllerFor(product.id).text.trim();
    final qty = int.tryParse(raw) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final picked = await _chooseBatches(product, qty);
    if (picked == null || !mounted) return;

    setState(() {
      _qty[product.id] = qty;
      _alloc[product.id] = picked;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(
          '${product.name} × $qty from '
          '${picked.map((a) => a.batchNumber).join(", ")}',
        ),
      ),
    );
  }

  /// Loads [product]'s sellable batches and opens the shared FEFO picker for
  /// [qty] units. Returns the chosen allocation, or null when the head backed
  /// out / the batches could not be loaded / nothing is sellable.
  Future<List<BatchAllocation>?> _chooseBatches(
    InventoryProduct product,
    int qty, {
    List<BatchAllocation> initial = const [],
  }) async {
    setState(() => _loadingBatchesFor = product.id);
    final (batches, error) = await _batchApi.getAvailableBatches(product.id);
    if (!mounted) return null;
    setState(() => _loadingBatchesFor = null);

    if (batches == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not load batches')),
      );
      return null;
    }

    // Expired and emptied lots are filtered out server-side, so an empty list
    // genuinely means there is nothing that may be sent.
    final sellable = batches.fold(0, (sum, b) => sum + b.available);
    if (batches.isEmpty || sellable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No sellable batch for ${product.name} — every lot is empty or '
            'past its expiry date.',
          ),
        ),
      );
      return null;
    }
    if (sellable < qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $sellable unit(s) of ${product.name} are in sellable '
            'batches — expired lots cannot be assigned.',
          ),
        ),
      );
      return null;
    }

    return showBatchSelector(
      context: context,
      productName: product.name,
      quantity: qty,
      batches: batches,
      initial: initial,
      lowStockThreshold: product.lowThreshold,
    );
  }

  /// Re-opens the picker for a line already in the order, seeded with its
  /// current lots so the head adjusts rather than starts over.
  Future<void> _changeBatches(InventoryProduct product) async {
    final qty = _qty[product.id] ?? 0;
    if (qty <= 0) return;
    final picked = await _chooseBatches(
      product,
      qty,
      initial: _alloc[product.id] ?? const [],
    );
    if (picked == null || !mounted) return;
    setState(() => _alloc[product.id] = picked);
  }

  void _removeProduct(String productId) {
    setState(() {
      _qty.remove(productId);
      _alloc.remove(productId);
    });
  }

  /// Clears the whole working order (quantities + batches + search) and resets
  /// the qty input boxes back to "1".
  void _resetOrder() {
    _qty.clear();
    _alloc.clear();
    _search = '';
    _searchController.clear();
    for (final c in _qtyControllers.values) {
      c.text = '1';
    }
  }

  /// Sends every added medicine to the outlet.
  ///
  /// The server takes ONE product per call, and each call re-reads and writes
  /// the same product document — so these run in SERIES on purpose; firing them
  /// in parallel would race and lose stock deductions.
  ///
  /// A failure part-way through is reported honestly rather than rolled back:
  /// the lines that already succeeded are really assigned, and pretending
  /// otherwise would leave the head assigning them twice.
  Future<void> _done() async {
    final outlet = _selectedOutlet!;
    final items = _orderedProducts;
    if (items.isEmpty) return;

    setState(() => _saving = true);

    final sent = <String>[];
    final failures = <String>[];

    for (final p in items) {
      final qty = _qty[p.id] ?? 0;
      if (qty <= 0) continue;
      final error = await _api.assignStock(
        outletId: outlet.id,
        productId: p.id,
        quantity: qty,
        // The lots the head explicitly chose. The server re-validates them
        // against live availability and consumes exactly these batches.
        allocations: _alloc[p.id] ?? const [],
      );
      if (error == null) {
        sent.add('${p.name} × $qty');
      } else {
        failures.add('${p.name} × $qty — $error');
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    // The catalog stock changed server-side; pull the real numbers back so the
    // "In catalog" figures and the Products tab aren't stale.
    unawaited(MarketingProductsController.instance.refresh());

    final allOk = failures.isEmpty;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(allOk
            ? 'Stock sent'
            : (sent.isEmpty ? 'Nothing was sent' : 'Partly sent')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${outlet.name} (${outlet.pin})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (sent.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Added to this outlet:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              Text(sent.join('\n')),
            ],
            if (failures.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Not sent:',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.error)),
              const SizedBox(height: 4),
              Text(failures.join('\n'),
                  style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
            ],
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

    if (!mounted) return;
    // Clear only what actually went through — anything that failed stays in the
    // list so it can be retried without re-typing.
    setState(() {
      for (final p in items) {
        final line = '${p.name} × ${_qty[p.id] ?? 0}';
        if (sent.contains(line)) {
          _qty.remove(p.id);
          _qtyControllers[p.id]?.text = '1';
        }
      }
      if (_qty.isEmpty) {
        _search = '';
        _searchController.clear();
      }
    });
  }

  Future<void> _findOutlets() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() {
        _error = 'Enter a valid 6-digit pincode';
        _searchedPin = '';
        _outlets = const [];
        _selectedOutlet = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = '';
      _finding = true;
      _selectedOutlet = null;
    });

    final outlets = await _api.getOutlets(pincode: pin);
    if (!mounted) return;

    // null = the call failed. Keep the searched state clear so the screen
    // doesn't claim "no outlets in this pincode" when it simply couldn't ask.
    if (outlets == null) {
      setState(() {
        _finding = false;
        _searchedPin = '';
        _outlets = const [];
        _error = 'Could not load outlets. Check your connection and retry.';
      });
      return;
    }

    setState(() {
      _finding = false;
      _searchedPin = pin;
      // An inactive outlet must not be stocked.
      _outlets = outlets.where((o) => o.isActive).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Select Outlet',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      // Rebuild when the catalog lands / changes, so the medicine search and
      // the "In catalog" figures reflect the real stock.
      body: ListenableBuilder(
        listenable: MarketingProductsController.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _pincodeCard(),
            const SizedBox(height: 16),
            if (_searchedPin.isNotEmpty) _outletsCard(),
            if (_selectedOutlet != null) ...[
              const SizedBox(height: 16),
              _productsCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pincode entry
  // ---------------------------------------------------------------------------

  Widget _pincodeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter pincode',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 2),
          const Text('Outlets in this pincode will be shown below',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => _findOutlets(),
            decoration: InputDecoration(
              hintText: 'e.g. 411001',
              counterText: '',
              prefixIcon: const Icon(Icons.location_on_outlined,
                  color: AppColors.greyText),
              filled: true,
              fillColor: AppColors.pageBg,
              errorText: _error.isEmpty ? null : _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _finding ? null : _findOutlets,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _finding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.search, size: 20),
              label: Text(_finding ? 'Finding…' : 'Find outlets',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Outlet dropdown (live: GET /outlets?pincode=) — shown after a search.
  // ---------------------------------------------------------------------------

  Widget _outletsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outlets in $_searchedPin',
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 12),
          if (_outlets.isEmpty)
            _noOutletsRow()
          else
            _outletDropdown(),
        ],
      ),
    );
  }

  Widget _noOutletsRow() {
    return Row(
      children: [
        const Icon(Icons.search_off_rounded, color: AppColors.greyText),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'No outlets found for this pincode.',
            style: TextStyle(fontSize: 13, color: AppColors.greyText),
          ),
        ),
      ],
    );
  }

  Widget _outletDropdown() {
    return DropdownButtonFormField<MarketingOutlet>(
      initialValue: _selectedOutlet,
      isExpanded: true,
      hint: const Text('Select an outlet'),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.greyText),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.pageBg,
        prefixIcon:
            const Icon(Icons.storefront_outlined, color: AppColors.greyText),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      items: [
        for (final outlet in _outlets)
          DropdownMenuItem<MarketingOutlet>(
            value: outlet,
            child: Text(outlet.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.darkText)),
          ),
      ],
      onChanged: (outlet) => setState(() {
        _selectedOutlet = outlet;
        _resetOrder(); // fresh order per outlet
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Select product → quantity → done (live catalog).
  // ---------------------------------------------------------------------------

  Widget _productsCard() {
    final results = _searchResults;
    final ordered = _orderedProducts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send stock · ${_selectedOutlet!.name}',
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 2),
          const Text(
              'Quantity is how much MORE to send — it adds to what the outlet '
              'already holds and comes out of the catalog stock.',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
          const SizedBox(height: 12),
          _searchField(),
          const SizedBox(height: 12),

          // Search-result boxes (only when the head is searching).
          if (_search.trim().isNotEmpty) ...[
            if (results.isEmpty)
              _noMatchRow()
            else
              for (final p in results) ...[
                _resultBox(p),
                const SizedBox(height: 10),
              ],
          ],

          // The working order (added items).
          if (ordered.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Stock to send',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            for (final p in ordered) _orderedRow(p),
            const SizedBox(height: 12),
            _summaryBar(),
          ] else if (_search.trim().isEmpty)
            _emptyHint(),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: 'Search medicine',
        isDense: true,
        prefixIcon: const Icon(Icons.search, color: AppColors.greyText),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.greyText),
                onPressed: () => setState(() {
                  _search = '';
                  _searchController.clear();
                }),
              ),
        filled: true,
        fillColor: AppColors.pageBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  /// One search-result box: medicine info + a small quantity field + "Add".
  Widget _resultBox(InventoryProduct product) {
    final inOrder = _qty[product.id] ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (product.packInfo.isNotEmpty)
                Text('${product.packInfo}  ·  ',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.greyText)),
              // The catalog stock is the ceiling: the server rejects the
              // assignment with "Insufficient stock available" beyond this.
              Text('In catalog: ${product.stock}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: product.stock <= 0
                          ? AppColors.error
                          : AppColors.greyText)),
            ],
          ),
          // The lot FEFO will offer first, from the product's server-synced
          // mirror (batch_no/exp_date always track the nearest-expiry batch).
          if (product.batchNo.isNotEmpty || product.expiryDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (product.batchNo.isNotEmpty) ...[
                    Flexible(
                      child: Text('Next batch ${product.batchNo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(formatExpiry(product.expiryDate),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: expiryTierOf(product.expiryDate).color)),
                  const SizedBox(width: 4),
                  ExpiryTierBadge(expiry: product.expiryDate, dense: true),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _qtyField(product),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loadingBatchesFor == product.id
                    ? null
                    : () => _addProduct(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // "Choose batch" makes the mandatory step explicit before the
                // picker opens.
                child: Text(
                    _loadingBatchesFor == product.id
                        ? 'Loading…'
                        : (inOrder > 0 ? 'Update' : 'Choose batch'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              if (inOrder > 0)
                Text('In order: $inOrder',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen)),
            ],
          ),
        ],
      ),
    );
  }

  /// Small quantity text field shown inside a result box.
  Widget _qtyField(InventoryProduct product) {
    return SizedBox(
      width: 64,
      child: TextField(
        controller: _qtyControllerFor(product.id),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Qty',
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// A row in the "In this order" list — name × qty, the exact lots being sent,
  /// and a remove button.
  Widget _orderedRow(InventoryProduct product) {
    final qty = _qty[product.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${product.name}  ×  $qty',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.greyText),
                onPressed: () => _removeProduct(product.id),
              ),
            ],
          ),
          // The lots this line will draw from — never hidden, always editable.
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: BatchSummary(
              allocations: _alloc[product.id] ?? const [],
              loading: _loadingBatchesFor == product.id,
              onChange: () => _changeBatches(product),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noMatchRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.greyText),
          SizedBox(width: 10),
          Expanded(
            child: Text('No medicines match your search.',
                style: TextStyle(fontSize: 13, color: AppColors.greyText)),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.greyText),
          SizedBox(width: 10),
          Expanded(
            child: Text('Search a medicine above to add it to the order.',
                style: TextStyle(fontSize: 13, color: AppColors.greyText)),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar() {
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_orderedProducts.length} '
                'medicine${_orderedProducts.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.greyText)),
            Text('Total qty: $_totalItems',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _done,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(_saving ? 'Sending…' : 'Done · Send stock',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
