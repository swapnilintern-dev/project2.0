// =============================================================================
// MediCaPlus — Product Card
//
// Tappable catalogue card used on Home and the Product Listing screen. It is
// fully flexible: the image area expands to fill whatever height the card is
// given (fixed-height horizontal list OR grid cell), text lines are clamped,
// and the price uses a FittedBox so long prices NEVER overflow horizontally.
// Opens details on tap; the green + button adds to the shared cart.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'customer_controllers.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'product_details_screen.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product, this.width});

  final Product product;
  final double? width;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  double _scale = 1;

  Color _badgeColor(String badge) => switch (badge) {
        'NEW' => const Color(0xFFF59E0B),
        'LOW STOCK' => AppColors.error,
        _ => AppColors.primary,
      };

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: widget.product),
      ),
    );
  }

  Future<void> _addToCart() async {
    setState(() => _scale = 0.85);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _scale = 1);
    CartController.instance.add(widget.product);
    showAppSnack(context, '${widget.product.title} added to cart');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return GestureDetector(
      onTap: _openDetails,
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area flexes to fill the available height -> no overflow.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: AppColors.lightGreenBg,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _image(p),
                      if (p.badge != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: TagBadge(
                              text: p.badge!, color: _badgeColor(p.badge!)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(p.brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.greyText)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Price block takes remaining width and scales down if needed.
                Expanded(child: _priceBlock(p)),
                const SizedBox(width: 6),
                AnimatedScale(
                  scale: _scale,
                  duration: const Duration(milliseconds: 120),
                  child: Semantics(
                    button: true,
                    label: 'Add ${p.title} to cart',
                    child: InkResponse(
                      onTap: _addToCart,
                      radius: 24,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(Product p) {
    final url = p.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Center(child: Icon(p.icon, size: 40, color: AppColors.primary)),
      );
    }
    return Center(child: Icon(p.icon, size: 40, color: AppColors.primary));
  }

  /// Price on its own line; MRP + discount on a second line wrapped in a
  /// FittedBox so it shrinks instead of overflowing on narrow cards.
  Widget _priceBlock(Product p) {
    final discount = p.discountPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatRupees(p.price),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen)),
        if (discount > 0)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatRupees(p.mrp!),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.greyText,
                        decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 5),
                Text('$discount% OFF',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A horizontal list-row variant of the product card (used in search results
/// and the wishlist). Image is fixed; text + price flex to avoid overflow.
class ProductListTile extends StatelessWidget {
  const ProductListTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ProductImage(product: product, size: 64, iconSize: 30, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(product.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.greyText)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: PriceTag(
                              price: product.price, mrp: product.mrp),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Spacer(),
                      _AddButton(product: product),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        CartController.instance.add(product);
        showAppSnack(context, '${product.title} added to cart');
      },
      radius: 22,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary),
        ),
        child: const Text('ADD',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen)),
      ),
    );
  }
}
