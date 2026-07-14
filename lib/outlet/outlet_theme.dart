import 'package:flutter/material.dart';

// TODO: Replace this whole file with references to your existing
// lib/theme/ constants (AppColors / AppTextStyles) once you wire it up.
// Kept separate here only so outlet UI can be previewed standalone.

class OutletColors {
  OutletColors._();

  static const Color grad1 = Color(0xFF0B5C4A);
  static const Color grad2 = Color(0xFF159E76);
  static const Color grad3 = Color(0xFF3FBE94);

  static const Color bg = Color(0xFFF3F8F6);
  static const Color white = Colors.white;
  static const Color textDark = Color(0xFF0F2E27);
  static const Color textMid = Color(0xFF4B6660);
  static const Color textMuted = Color(0xFF8A9C97);
  static const Color border = Color(0xFFE1EDE9);
  static const Color accent = Color(0xFFFF6B35);
  static const Color success = Color(0xFF1D9E75);
  static const Color amber = Color(0xFFE8A93B);
  static const Color danger = Color(0xFFA32D2D);

  static const Color badgeGreenBg = Color(0xFFE1F5EE);
  static const Color badgeAmberBg = Color(0xFFFAEEDA);
  static const Color badgeRedBg = Color(0xFFFCEBEB);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [grad1, grad2, grad3],
  );

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: grad1.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
}

class OutletTextStyles {
  OutletTextStyles._();

  static const TextStyle greet = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle subGreet = TextStyle(
    fontSize: 12.5,
    color: Colors.white70,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: OutletColors.textDark,
  );

  static const TextStyle statNum = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: OutletColors.textDark,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 11,
    color: OutletColors.textMuted,
  );

  static const TextStyle prodName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: OutletColors.textDark,
  );

  static const TextStyle prodSub = TextStyle(
    fontSize: 11,
    color: OutletColors.textMuted,
  );
}

// Reusable rounded badge used across outlet screens.
class OutletBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const OutletBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// Shared curved gradient header used on every outlet screen.
class OutletHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  const OutletHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
      decoration: const BoxDecoration(
        gradient: OutletColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              leading ?? const SizedBox(),
              trailing ?? const SizedBox(),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: OutletTextStyles.greet),
          const SizedBox(height: 2),
          Text(subtitle, style: OutletTextStyles.subGreet),
        ],
      ),
    );
  }
}

// Shared bottom nav for the outlet shell. Index-based: the shell owns the tab
// state (IndexedStack) and passes [onTap] to switch — matching how the app's
// other role shells navigate (no named routes).
class OutletBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const OutletBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    {'icon': Icons.home_outlined, 'label': 'Home'},
    {'icon': Icons.inventory_2_outlined, 'label': 'Stock'},
    {'icon': Icons.receipt_long_outlined, 'label': 'Orders'},
    {'icon': Icons.person_outline, 'label': 'Profile'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: OutletColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final active = i == currentIndex;
          final item = _items[i];
          return InkWell(
            onTap: () => onTap(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 20,
                  color: active ? OutletColors.success : OutletColors.textMuted,
                ),
                const SizedBox(height: 3),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: active ? OutletColors.success : OutletColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// White overlay card that sits on top of the header (negative margin look).

class OutletCardOverlay extends StatelessWidget {
  final Widget child;

  const OutletCardOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -26),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: OutletColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: OutletColors.cardShadow,
        ),
        child: child,
      ),
    );
  }
}
