// =============================================================================
// MediCaPlus — Admin · Products (pushed from Overview)
//
// The master catalogue, fetched LIVE from the backend (GET /all-products —
// the same list the customer shop sells from). A SKU stat strip (total /
// active / low / out) computed from that list, search, and product rows with
// price and a colour-coded stock label. "Add" opens the Add New Product form.
// Pull-to-refresh reloads the list.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../../services/live_refresh.dart';
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'add_product_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen>
    with LiveRefreshMixin {
  final AdminApi _api = AdminApi();

  List<AdminProduct> _products = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Load on open, then keep the master catalogue live (poll + app-resume) so
    // stock/price changes from any role appear on their own.
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _load();

  Future<void> _load() async {
    final fetched = await _api.getAllProducts();
    if (!mounted) return;
    setState(() {
      // Offline-safe: keep the current list when the fetch fails.
      if (fetched != null) _products = fetched;
      _loading = false;
    });
  }

  List<AdminProduct> get _filtered {
    if (_query.isEmpty) return _products;
    final q = _query.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q))
        .toList();
  }

  int get _lowCount =>
      _products.where((p) => p.stock > 0 && p.stock <= 20).length;
  int get _outCount => _products.where((p) => p.stock == 0).length;

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Products',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            Text(
                _loading && _products.isEmpty
                    ? 'Loading catalogue…'
                    : '${_products.length} SKUs listed',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.greyText)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AdminButton(
              label: 'Add',
              icon: Icons.add,
              expand: false,
              height: 40,
              onPressed: () async {
                final created =
                    await adminPush<bool>(context, const AddProductScreen());
                if (created == true && context.mounted) {
                  adminSnack(context, 'Product added to catalogue');
                  _load();
                }
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AdminSearchField(
              hint: 'Search products…',
              onChanged: (v) => setState(() => _query = v),
              onFilter: () => adminSnack(context, 'Filters'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Expanded(
                    child: MiniStat(
                        value: '${_products.length}',
                        label: 'Total',
                        color: AppColors.darkText)),
                const SizedBox(width: 10),
                Expanded(
                    child: MiniStat(
                        value: '${_products.length - _outCount}',
                        label: 'Active',
                        color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(
                    child: MiniStat(
                        value: '$_lowCount',
                        label: 'Low',
                        color: AdminColors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: MiniStat(
                        value: '$_outCount',
                        label: 'Out',
                        color: AdminColors.red)),
              ],
            ),
          ),
          Expanded(
            child: _loading && _products.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 80),
                              AdminEmpty(label: 'No products found'),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: adminScroll),
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _ProductRow(product: list[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final AdminProduct product;

  @override
  Widget build(BuildContext context) {
    final stock = product.stock;
    final (Color color, String label) = stock == 0
        ? (AdminColors.red, 'Out of stock')
        : stock <= 20
            ? (AdminColors.orange, 'Low · $stock')
            : (AdminColors.green, '$stock in stock');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: adminCard(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication, color: AppColors.darkGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text(
                    product.category.isEmpty
                        ? product.sku
                        : '${product.category} · ${product.sku}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.greyText)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(money(product.price),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText)),
                    const SizedBox(width: 10),
                    StatusBadge(label: label, color: color, dense: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
