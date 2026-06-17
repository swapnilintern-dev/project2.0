// =============================================================================
// MediCaPlus — Product Details Screen
//
// Hero image, title/brand, rating, price, description, quantity selector,
// wishlist toggle, reviews preview and related products. A sticky bottom bar
// adds the chosen quantity to the cart and offers Buy Now (straight to cart).
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'customer_controllers.dart';
import 'customer_mock_data.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _qty = 1;
  bool _adding = false;

  Product get _p => widget.product;

  List<Product> get _related => MockData.products
      .where((p) => p.category == _p.category && p.id != _p.id)
      .take(6)
      .toList();

  Future<void> _addToCart({bool buyNow = false}) async {
    setState(() => _adding = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    CartController.instance.add(_p, quantity: _qty);
    setState(() => _adding = false);
    if (buyNow) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CartScreen()));
    } else {
      showAppSnack(context, '${_qty}x ${_p.title} added to cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.lighterGreen,
      foregroundColor: AppColors.darkText,
      leading: _circleButton(Icons.arrow_back, () => Navigator.pop(context),
          tooltip: 'Back'),
      actions: [
        ListenableBuilder(
          listenable: WishlistController.instance,
          builder: (context, _) {
            final saved = WishlistController.instance.contains(_p.id);
            return _circleButton(
              saved ? Icons.favorite : Icons.favorite_border,
              () {
                WishlistController.instance.toggle(_p.id);
                showAppSnack(context,
                    saved ? 'Removed from saved' : 'Saved to wishlist');
              },
              color: saved ? AppColors.error : AppColors.darkText,
              tooltip: 'Wishlist',
            );
          },
        ),
        _circleButton(Icons.share_outlined,
            () => showAppSnack(context, 'Share link copied'),
            tooltip: 'Share'),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.lighterGreen,
          child: Hero(
            tag: 'product-${_p.id}',
            child: Center(
              child: _p.imageUrl != null && _p.imageUrl!.isNotEmpty
                  ? Image.network(_p.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Icon(_p.icon, size: 120, color: AppColors.primary))
                  : Icon(_p.icon, size: 120, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap,
      {Color? color, String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 1,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: color ?? AppColors.darkText, size: 20),
          tooltip: tooltip,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_p.badge != null) TagBadge(text: _p.badge!),
          if (_p.badge != null) const SizedBox(height: 10),
          Text(_p.title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_p.brand,
              style: const TextStyle(fontSize: 14, color: AppColors.greyText)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 4),
              Text(_p.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('· ${_p.reviewCount} ratings',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.greyText)),
              const Spacer(),
              _stockChip(),
            ],
          ),
          const SizedBox(height: 18),
          PriceTag(price: _p.price, mrp: _p.mrp, large: true),
          const SizedBox(height: 6),
          const Text('Inclusive of all taxes',
              style: TextStyle(fontSize: 12, color: AppColors.greyText)),
          const Divider(height: 32, color: AppColors.border),

          // Quantity selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantity',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              QuantityStepper(
                quantity: _qty,
                onChanged: (q) => setState(() => _qty = q),
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.border),

          const Text('Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_p.description,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.greyText, height: 1.5)),
          if (_p.packInfo.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow('Pack', _p.packInfo),
          ],
          _infoRow('Category', _p.category[0].toUpperCase() + _p.category.substring(1)),

          const SizedBox(height: 24),
          _buildReviews(),

          if (_related.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Related Products'),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _related.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final r = _related[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => ProductDetailsScreen(product: r)),
                    ),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lighterGreen,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          ProductImage(
                              product: r, size: 56, iconSize: 26, radius: 10),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(formatRupees(r.price),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.darkGreen)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stockChip() {
    final ok = _p.inStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (ok ? AppColors.primary : AppColors.error)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        ok ? (_p.stockCount > 0 ? 'In Stock: ${_p.stockCount}' : 'In Stock') : 'Out of Stock',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ok ? AppColors.darkGreen : AppColors.error),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.greyText))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    final reviews = [
      ('Rohan S.', 5, 'Genuine product, fast delivery. Will reorder.'),
      ('Priya M.', 4, 'Good packaging and reasonably priced.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Reviews (${_p.reviewCount})',
          actionLabel: 'View all',
          onAction: () => showAppSnack(context, 'Opening all reviews'),
        ),
        const SizedBox(height: 12),
        for (final r in reviews)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      child: Text(r.$1[0],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text(r.$1,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < r.$2 ? Icons.star : Icons.star_border,
                          size: 14,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(r.$3,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.greyText)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Buy Now',
                icon: Icons.flash_on,
                onPressed: _adding ? null : () => _addToCart(buyNow: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Add to Cart · ${formatRupees(_p.price * _qty)}',
                icon: Icons.shopping_cart_outlined,
                loading: _adding,
                onPressed: _p.inStock ? () => _addToCart() : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
