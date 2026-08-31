// =============================================================================
// MediCaPlus — Reusable Customer Widgets
//
// The shared component library for the customer experience: buttons, product
// cards, quantity steppers, section headers, empty / loading / error states.
// All colours come from AppColors so the app keeps one palette. Sizes are
// relative (no hard-coded screen dimensions) so they scale across phones,
// large-text settings and tablets.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_widgets.dart';
import 'customer_models.dart';

/// The "Low Stock" warning colour — amber, sitting between the in-stock green
/// and the out-of-stock red. Deliberately the SAME value the staff-side batch
/// picker uses (widgets/batch_selector.dart) so a low-stock warning looks
/// identical whichever role is looking at it.
const Color kLowStockAmber = Color(0xFFE8710A);

/// Formats a rupee amount as e.g. ₹1,234 or ₹1,234.50.
String formatRupees(double value, {bool decimals = false}) {
  final fixed = decimals ? value.toStringAsFixed(2) : value.round().toString();
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i != 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  final grouped = buffer.toString();
  return parts.length > 1 ? '₹$grouped.${parts[1]}' : '₹$grouped';
}

/// Full-width primary button with a built-in loading spinner. Honours minimum
/// 48px tap-target height for accessibility.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    // The label carries a formatted price, so its width grows
                    // with the order total and the platform text scale.
                    // Flexible + ellipsis keeps it inside the button instead of
                    // painting past its edge.
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary outlined button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkGreen,
        minimumSize: const Size(0, 48),
        // Material's default 24px side padding leaves too little room when the
        // button shares a row with a wider primary action, which is where the
        // icon + label used to spill past the border.
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: const BorderSide(color: AppColors.primary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// A compact "− qty +" stepper used on product cards, the detail page and cart.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.compact = false,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;

  /// Highest quantity "+" will go to — the available stock. Null means no
  /// ceiling (stock unknown), which is the behaviour every existing caller
  /// that omits it keeps.
  final int? max;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 28 : 36;
    final double font = compact ? 14 : 16;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(compact ? 8 : 24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepIcon(
            icon: Icons.remove,
            size: size,
            enabled: quantity > min,
            onTap: () => onChanged(quantity - 1),
            tooltip: 'Decrease quantity',
          ),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 24 : 36),
            alignment: Alignment.center,
            child: Text('$quantity',
                style: TextStyle(
                    fontSize: font,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
          ),
          _stepIcon(
            icon: Icons.add,
            size: size,
            // Greys out on the last available unit. `quantity < max` (rather
            // than <=) also keeps it disabled when the line already sits ABOVE
            // the stock, which happens when stock falls while the item waits
            // in the cart — "-" stays live so the vendor can correct it.
            enabled: max == null || quantity < max!,
            onTap: () => onChanged(quantity + 1),
            tooltip: 'Increase quantity',
          ),
        ],
      ),
    );
  }

  Widget _stepIcon({
    required IconData icon,
    required double size,
    required bool enabled,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: size * 0.6,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon,
              size: size * 0.5,
              color: enabled ? AppColors.darkGreen : AppColors.greyText),
        ),
      ),
    );
  }
}

/// Price + struck-through MRP + discount pill, reused everywhere.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.price,
    this.mrp,
    this.large = false,
  });

  final double price;
  final double? mrp;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final discount =
        (mrp != null && mrp! > price) ? (((mrp! - price) / mrp!) * 100).round() : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(formatRupees(price),
            style: TextStyle(
                fontSize: large ? 26 : 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen)),
        if (discount > 0) ...[
          const SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(bottom: large ? 4 : 1),
            child: Text(formatRupees(mrp!),
                style: TextStyle(
                    fontSize: large ? 14 : 11,
                    color: AppColors.greyText,
                    decoration: TextDecoration.lineThrough)),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: EdgeInsets.only(bottom: large ? 5 : 1),
            child: Text('$discount% OFF',
                style: TextStyle(
                    fontSize: large ? 13 : 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ),
        ],
      ],
    );
  }
}

/// Small coloured pill badge (BEST SELLER / NEW / LOW STOCK ...).
class TagBadge extends StatelessWidget {
  const TagBadge({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

/// The square product tile placeholder image (icon on a soft-green panel).
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.size = 90,
    this.iconSize = 36,
    this.radius = 12,
  });

  final Product product;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: size,
        width: size == double.infinity ? double.infinity : size,
        color: AppColors.lightGreenBg,
        child: AppNetworkImage(
          url: url,
          fit: BoxFit.cover,
          fallback: Center(
              child: Icon(product.icon,
                  size: iconSize, color: AppColors.primary)),
        ),
      ),
    );
  }
}

/// Section header with an optional "See all" trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            child: Text(actionLabel!,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ],
    );
  }
}

/// Generic empty state with an icon, message and optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                  color: AppColors.lightGreenBg, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.greyText, height: 1.4)),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              SecondaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmering skeleton block for loading states.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = 0.3 + (_controller.value * 0.5);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A snackbar helper that respects the app theme.
void showAppSnack(BuildContext context, String message, {bool success = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? AppColors.darkGreen : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
}
