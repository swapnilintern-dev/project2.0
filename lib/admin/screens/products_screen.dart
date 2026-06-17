// =============================================================================
// MediCaPlus — Admin · Products (pushed from Overview)
//
// The master catalogue. A SKU stat strip (total / active / low / out), search,
// and product rows with price, a colour-coded stock label and an availability
// toggle. "Add" opens the Add New Product form.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'add_product_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  // TODO: GET /api/admin/products
  final List<AdminProduct> _products = kProducts;
  String _query = '';

  List<AdminProduct> get _filtered {
    if (_query.isEmpty) return _products;
    final q = _query.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q))
        .toList();
  }

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
          children: const [
            Text('Products',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            Text('312 SKUs listed',
                style: TextStyle(fontSize: 12, color: AppColors.greyText)),
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
                final created = await adminPush<bool>(
                    context, const AddProductScreen());
                if (created == true && context.mounted) {
                  adminSnack(context, 'Product added to catalogue');
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
                        value: '$kSkusTotal',
                        label: 'Total',
                        color: AppColors.darkText)),
                const SizedBox(width: 10),
                Expanded(
                    child: MiniStat(
                        value: '$kSkusActive',
                        label: 'Active',
                        color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(
                    child: MiniStat(
                        value: '$kSkusLow',
                        label: 'Low',
                        color: AdminColors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: MiniStat(
                        value: '$kSkusOut',
                        label: 'Out',
                        color: AdminColors.red)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const AdminEmpty(label: 'No products found')
                : ListView.builder(
                    physics: adminScroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _ProductRow(
                      product: list[i],
                      onToggle: (v) => setState(() => list[i].active = v),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onToggle});
  final AdminProduct product;
  final ValueChanged<bool> onToggle;

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
                Text(product.sku,
                    style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
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
          Switch.adaptive(
            value: product.active,
            activeThumbColor: AppColors.primary,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
