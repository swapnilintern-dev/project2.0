// =============================================================================
// MediCaPlus — Product Listing / Search Screen
//
// Loads the catalogue from CustomerApi (mock fallback), with a search field,
// category filter chips, a sort bottom sheet and result count. Used both for
// the Search tab and when tapping a category from Home. Shows skeleton loaders
// while fetching and an empty state when no results match.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_widgets.dart';
import 'customer_api.dart';
import 'customer_mock_data.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'product_card.dart';

enum SortOption { relevance, priceLowHigh, priceHighLow, rating, discount }

extension SortOptionX on SortOption {
  String get label => switch (this) {
        SortOption.relevance => 'Relevance',
        SortOption.priceLowHigh => 'Price: Low to High',
        SortOption.priceHighLow => 'Price: High to Low',
        SortOption.rating => 'Customer Rating',
        SortOption.discount => 'Discount',
      };
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    this.initialCategory,
    this.initialQuery,
    this.embedded = false,
  });

  final String? initialCategory;
  final String? initialQuery;
  final bool embedded;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final CustomerApi _api = CustomerApi();
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();

  List<Product> _all = [];
  bool _loading = true;
  String? _category;
  String _query = '';
  SortOption _sort = SortOption.relevance;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _query = widget.initialQuery ?? '';
    _searchCtrl.text = _query;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _api.getProducts();
    if (!mounted) return;
    setState(() {
      _all = products;
      _loading = false;
    });
  }

  List<Product> get _results {
    var list = _all.where((p) {
      final matchesCategory = _category == null || p.category == _category;
      final matchesQuery = _query.isEmpty ||
          p.title.toLowerCase().contains(_query.toLowerCase()) ||
          p.brand.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    switch (_sort) {
      case SortOption.priceLowHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
      case SortOption.priceHighLow:
        list.sort((a, b) => b.price.compareTo(a.price));
      case SortOption.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case SortOption.discount:
        list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      case SortOption.relevance:
        break;
    }
    return list;
  }

  void _openSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort by',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            for (final option in SortOption.values)
              ListTile(
                title: Text(option.label),
                trailing: _sort == option
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : const Icon(Icons.radio_button_unchecked,
                        color: AppColors.greyText),
                onTap: () {
                  setState(() => _sort = option);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _searchBar(),
        _filterRow(),
        Expanded(child: _grid()),
      ],
    );

    if (widget.embedded) return SafeArea(child: content);
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: Text(_category != null ? _categoryName(_category!) : 'Search',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: content,
    );
  }

  String _categoryName(String id) =>
      MockData.categories.firstWhere((c) => c.id == id,
          orElse: () => MockData.categories.first).name;

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          onChanged: (v) =>
              _searchDebouncer.run(() => setState(() => _query = v)),
          decoration: InputDecoration(
            hintText: 'Search medicines, brands...',
            hintStyle:
                const TextStyle(fontSize: 14, color: AppColors.greyText),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.greyText),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _filterRow() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('All', _category == null, () => setState(() => _category = null)),
                for (final c in MockData.categories)
                  _chip(c.name, _category == c.id,
                      () => setState(() => _category = c.id)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _openSort,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.tune, size: 16, color: AppColors.darkGreen),
                    SizedBox(width: 4),
                    Text('Sort',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreen)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.darkText,
        ),
        side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _grid() {
    if (_loading) return _skeletonGrid();
    final results = _results;
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        message: _query.isEmpty
            ? 'No products in this category yet.'
            : 'No medicines match "$_query". Try a different search.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive column count: more columns on wider screens / tablets.
        final crossAxisCount = constraints.maxWidth > 720
            ? 4
            : constraints.maxWidth > 520
                ? 3
                : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('${results.length} results',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.greyText)),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: results.length,
                itemBuilder: (context, i) =>
                    AppFadeIn(child: ProductCard(product: results[i])),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _skeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, i) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Skeleton(height: 96, radius: 12),
            SizedBox(height: 10),
            Skeleton(height: 12, width: 120),
            SizedBox(height: 6),
            Skeleton(height: 10, width: 80),
            Spacer(),
            Skeleton(height: 14, width: 60),
          ],
        ),
      ),
    );
  }
}
