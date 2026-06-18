// =============================================================================
// MediCaPlus — Cart Screen
//
// Lists cart lines with quantity steppers + remove, an apply-coupon field, an
// order summary, and a sticky checkout bar. Listens to CartController so it
// stays in sync with adds from anywhere in the app. Used both as a tab (inside
// the shell, no app bar) and as a pushed route (with a back button).
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import 'customer_controllers.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  /// When embedded as a bottom-nav tab there is no Navigator entry to pop, so
  /// the back button + Scaffold app bar are hidden.
  const CartScreen({super.key, this.embedded = false, this.onContinueShopping});

  final bool embedded;

  /// When embedded, routes "Continue shopping" back to the Home tab.
  final VoidCallback? onContinueShopping;

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: CartController.instance,
      builder: (context, _) {
        final cart = CartController.instance;
        if (cart.isEmpty) {
          return EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Your cart is empty',
            message: 'Browse medicines and add them to your cart to see them here.',
            actionLabel: 'Continue shopping',
            onAction: () {
              if (embedded) {
                onContinueShopping?.call();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          );
        }
        return _CartBody(cart: cart, embedded: embedded);
      },
    );

    if (embedded) {
      return SafeArea(child: body);
    }
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('My Cart',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: body,
    );
  }
}

class _CartBody extends StatelessWidget {
  const _CartBody({required this.cart, required this.embedded});

  final CartController cart;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('My Cart',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${cart.itemCount} items',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreen)),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            physics: const BouncingScrollPhysics(),
            children: [
              for (final item in cart.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CartLine(item: item),
                ),
              const SizedBox(height: 8),
              const _CouponField(),
              const SizedBox(height: 16),
              _OrderSummary(cart: cart),
            ],
          ),
        ),
        _CheckoutBar(cart: cart),
      ],
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        CartController.instance.remove(p.id);
        showAppSnack(context, '${p.title} removed', success: false);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            ProductImage(product: p, size: 64, iconSize: 28, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(p.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.greyText)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(formatRupees(item.lineTotal),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkGreen)),
                      const Spacer(),
                      QuantityStepper(
                        quantity: item.quantity,
                        min: 1,
                        compact: true,
                        onChanged: (q) =>
                            CartController.instance.setQuantity(p.id, q),
                      ),
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

class _CouponField extends StatefulWidget {
  const _CouponField();

  @override
  State<_CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<_CouponField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    FocusScope.of(context).unfocus();
    final error = CartController.instance.applyCoupon(_controller.text);
    if (error != null) {
      showAppSnack(context, error, success: false);
    } else {
      showAppSnack(context, 'Coupon applied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartController.instance,
      builder: (context, _) {
        final applied = CartController.instance.appliedCoupon;
        if (applied != null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${applied.code} applied',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(applied.description,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.greyText)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    CartController.instance.removeCoupon();
                    _controller.clear();
                  },
                  child: const Text('Remove',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              const Icon(Icons.local_offer_outlined,
                  color: AppColors.greyText, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter coupon code (e.g. BULK20)',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.greyText),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              TextButton(
                onPressed: _apply,
                child: const Text('Apply',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart});

  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Order Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          _row('Subtotal', formatRupees(cart.subtotal, decimals: true)),
          if (cart.discount > 0)
            _row('Discount (${cart.appliedCoupon?.code})',
                '- ${formatRupees(cart.discount, decimals: true)}',
                highlight: true),
          _row(
              'Delivery',
              cart.deliveryFee == 0
                  ? 'FREE'
                  : formatRupees(cart.deliveryFee, decimals: true),
              free: cart.deliveryFee == 0),
          _row('GST (12%)', formatRupees(cart.gst, decimals: true)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.border, height: 1),
          ),
          _row('Total', formatRupees(cart.total, decimals: true), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, bool free = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: bold ? AppColors.darkGreen : AppColors.greyText)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold
                      ? AppColors.darkGreen
                      : free || highlight
                          ? AppColors.primary
                          : AppColors.darkText)),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart});

  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Total',
                    style: TextStyle(fontSize: 12, color: AppColors.greyText)),
                Text(formatRupees(cart.total),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGreen)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryButton(
                label: 'Proceed to Checkout',
                icon: Icons.arrow_forward,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
