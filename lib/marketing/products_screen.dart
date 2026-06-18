// =============================================================================
// MediCaPlus — Marketing Head · Products tab (Medicine Inventory)
//
// The medicine inventory: a search bar, status filter chips (All / Active /
// Inactive), horizontally-scrolling category chips, a "shown / inactive" recap
// and rich medicine cards with Edit + Activate/Deactivate actions and an
// inactive-reason banner. An "Add Medicine" FAB opens the Add Medicine form.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart' show formatRupees, EmptyState;
import 'marketing_controllers.dart';
import 'marketing_models.dart';
import 'add_product_screen.dart';

enum _ListingFilter { all, active, inactive }

class MarketingProductsScreen extends StatefulWidget {
  const MarketingProductsScreen({super.key});

  @override
  State<MarketingProductsScreen> createState() =>
      _MarketingProductsScreenState();
}

class _MarketingProductsScreenState extends State<MarketingProductsScreen> {
  String _query = '';
  _ListingFilter _filter = _ListingFilter.all;
  String _category = 'All Categories';

  MarketingProductsController get _controller =>
      MarketingProductsController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            _filterChips(),
            _categoryChips(),
            _recapRow(),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final products = _visible();
                  if (products.isEmpty) {
                    return EmptyState(
                      icon: Icons.medication_outlined,
                      title: 'No medicines',
                      message: _query.isEmpty
                          ? 'Add your first medicine to the inventory.'
                          : 'No medicines match "$_query".',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _MedicineCard(
                      product: products[i],
                      onToggle: () => _controller.toggleActive(products[i].id),
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddMedicineScreen(existing: products[i]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InventoryProduct> _visible() {
    var list = _controller.products;
    if (_filter == _ListingFilter.active) {
      list = list.where((p) => p.active).toList();
    } else if (_filter == _ListingFilter.inactive) {
      list = list.where((p) => !p.active).toList();
    }
    if (_category != 'All Categories') {
      list = list.where((p) => p.category == _category).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q) ||
              p.code.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  // ---------------------------------------------------------------------------

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Medicine Inventory',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search medicines…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _countChip('All', _controller.total, _ListingFilter.all),
              const SizedBox(width: 8),
              _countChip('Active', _controller.activeCount, _ListingFilter.active),
              const SizedBox(width: 8),
              _countChip(
                  'Inactive', _controller.inactiveCount, _ListingFilter.inactive),
            ],
          ),
        );
      },
    );
  }

  Widget _countChip(String label, int count, _ListingFilter filter) {
    final selected = _filter == filter;
    return InkWell(
      onTap: () => setState(() => _filter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.darkGreen : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.greyText)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.darkGreen)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips() {
    final categories = ['All Categories', ...kMedicineCategories];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categories[i];
          final selected = _category == c;
          return InkWell(
            onTap: () => setState(() => _category = c),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.darkGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? AppColors.darkGreen : AppColors.border),
              ),
              child: Text(c,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.greyText)),
            ),
          );
        },
      ),
    );
  }

  Widget _recapRow() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final shown = _visible().length;
        return Container(
          width: double.infinity,
          color: AppColors.lightGreenBg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$shown shown',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreen)),
              Row(
                children: [
                  const Icon(Icons.visibility_off_outlined,
                      size: 14, color: AppColors.greyText),
                  const SizedBox(width: 4),
                  Text('${_controller.inactiveCount} inactive',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.greyText)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.product,
    required this.onToggle,
    required this.onEdit,
  });

  final InventoryProduct product;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final status = product.stockStatus;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(product.icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.darkText)),
                    const SizedBox(height: 2),
                    Text(product.brand.isEmpty ? '—' : product.brand,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.greyText)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatRupees(product.price, decimals: true),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.darkGreen)),
                  const SizedBox(height: 4),
                  _statusPill(status.label, status.color),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(product.category, AppColors.darkGreen,
                  AppColors.lightGreenBg),
              const SizedBox(width: 8),
              if (product.active)
                _chip('Active', AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.12))
              else
                _chip('Inactive', AppColors.error,
                    AppColors.error.withValues(alpha: 0.10)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 15, color: AppColors.greyText),
              const SizedBox(width: 6),
              Text('Stock: ${product.stock} units',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.greyText)),
            ],
          ),
          if (!product.active && (product.inactiveReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 15, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Reason: ${product.inactiveReason}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: product.active
                    ? OutlinedButton.icon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.visibility_off_outlined,
                            size: 17),
                        label: const Text('Deactivate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
}
