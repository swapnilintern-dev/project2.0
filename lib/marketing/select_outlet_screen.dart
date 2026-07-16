// =============================================================================
// MediCaPlus — Marketing Head · Select Outlet (Outlet Order flow)
//
// Entry screen for the marketing-head outlet-ordering flow described in the
// spec: enter a pincode → pick an outlet in that pincode → (later) select
// product → quantity → done.
//
// STEP 7 (this pass): this is an UPDATE-STOCK flow for our own outlets, not a
// customer order — so there is NO price / money anywhere. The head enters a
// pincode, picks an outlet, searches a medicine, types a QUANTITY, adds it, and
// taps "Done" to UPDATE that outlet's stock (by outlet + pincode). UI-only —
// mock sources + in-memory store (MarketingStockAssignmentMock); no backend
// wiring yet.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'marketing_outlet_mock.dart';

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

  /// The mock product catalog (loaded once).
  final List<MarketingOrderProduct> _products = MarketingProductMock.all();

  /// Medicine search box controller + current query (lower-cased on read).
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  /// Chosen quantity per product id. Absent / 0 = not in the order.
  final Map<String, int> _qty = {};

  /// Per-product quantity input controllers for the search-result boxes.
  /// Created lazily and reused; all disposed in [dispose].
  final Map<String, TextEditingController> _qtyControllers = {};

  /// Search-result matches for the current query (empty when the query is
  /// blank — there is no always-on list; results only show after typing).
  List<MarketingOrderProduct> get _searchResults {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _products
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  /// Products currently in the order (qty > 0), in catalog order.
  List<MarketingOrderProduct> get _orderedProducts =>
      _products.where((p) => (_qty[p.id] ?? 0) > 0).toList();

  /// The quantity controller for [productId], seeded with "1" on first use.
  TextEditingController _qtyControllerFor(String productId) =>
      _qtyControllers.putIfAbsent(
        productId,
        () => TextEditingController(text: '1'),
      );

  int get _totalItems => _qty.values.fold(0, (sum, q) => sum + q);

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
  void _addProduct(MarketingOrderProduct product) {
    final raw = _qtyControllerFor(product.id).text.trim();
    final qty = int.tryParse(raw) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _qty[product.id] = qty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Text('${product.name} × $qty added'),
      ),
    );
  }

  void _removeProduct(String productId) {
    setState(() => _qty.remove(productId));
  }

  /// Clears the whole working order (quantities + search) and resets the qty
  /// input boxes back to "1".
  void _resetOrder() {
    _qty.clear();
    _search = '';
    _searchController.clear();
    for (final c in _qtyControllers.values) {
      c.text = '1';
    }
  }

  void _done() {
    final outlet = _selectedOutlet!;
    final items = [
      for (final p in _products)
        if ((_qty[p.id] ?? 0) > 0)
          MarketingStockAssignmentItem(
            productId: p.id,
            name: p.name,
            qty: _qty[p.id]!,
          ),
    ];

    // Record the stock update against the outlet (mock store — this is the seam
    // a future backend call will replace: "update this outlet's stock").
    MarketingStockAssignmentMock.assign(
      outletId: outlet.id,
      pincode: outlet.pin,
      items: items,
    );

    final lines = items.map((i) => '${i.name} × ${i.qty}').join('\n');

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stock updated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock updated for ${outlet.name} (${outlet.pin})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(lines),
            const SizedBox(height: 8),
            Text('Total quantity: $_totalItems',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('(UI preview — recorded locally; not sent to backend yet.)',
                style: TextStyle(fontSize: 12, color: AppColors.greyText)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              // Reset the order so the head can assign to another outlet.
              setState(_resetOrder);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _findOutlets() {
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
      _searchedPin = pin;
      _outlets = MarketingOutletMock.outletsForPincode(pin);
      _selectedOutlet = null;
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
      body: ListView(
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
              onPressed: _findOutlets,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Find outlets',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Outlet dropdown (mock-fed) — shown after a search.
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
  // Select product → quantity → done (mock catalog).
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
          Text('Update stock · ${_selectedOutlet!.name}',
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
          const SizedBox(height: 2),
          const Text('Search a medicine, type quantity and add',
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
            const Text('Stock to update',
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
  Widget _resultBox(MarketingOrderProduct product) {
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
          if (product.packSize.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(product.packSize,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyText)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _qtyField(product),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _addProduct(product),
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
                child: Text(inOrder > 0 ? 'Update' : 'Add',
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
  Widget _qtyField(MarketingOrderProduct product) {
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

  /// A row in the "In this order" list — name × qty with a remove button.
  Widget _orderedRow(MarketingOrderProduct product) {
    final qty = _qty[product.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
            onPressed: _done,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Done · Update stock',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
