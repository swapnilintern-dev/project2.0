// =============================================================================
// MediCaPlus — Admin (Platform Operator) · Shared theme & widgets
//
// Everything visual that more than one admin screen needs lives here so the
// whole role stays on one palette and one set of building blocks:
//   • AdminColors        — accent colours layered on top of shared AppColors
//   • formatters         — compact / grouped rupee helpers, initials
//   • adminCard / snack  — the canonical white card + floating snackbar
//   • building blocks     — gradient header, KPI cards, stat tiles, status
//                          badges, search field, pill segment tabs, ring gauge,
//                          animated counter, info rows, empty state.
//
// Screens compose these; they never re-implement them. All data is static
// dummy data — swap the `// TODO: GET …` points for real calls later.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;

// -----------------------------------------------------------------------------
// PALETTE — status / category accents not present in AppColors
// -----------------------------------------------------------------------------

class AdminColors {
  AdminColors._();

  static const Color green = AppColors.primary; // active / success / in-stock
  static const Color darkGreen = AppColors.darkGreen; // delivered / headline
  static const Color blue = Color(0xFF3B82F6); // info / processing
  static const Color purple = Color(0xFF8B5CF6); // staff / premium
  static const Color orange = Color(0xFFF59E0B); // pending / low / warning
  static const Color red = AppColors.error; // disputed / suspended / out
  static const Color amber = Color(0xFFD97706); // flagged
}

// -----------------------------------------------------------------------------
// FORMATTERS
// -----------------------------------------------------------------------------

/// Groups an integer with Indian-style separators is overkill here; we keep the
/// familiar thousands grouping, e.g. 14208 -> "14,208".
String groupInt(num value) {
  final s = value.round().toString();
  final neg = s.startsWith('-');
  final digits = neg ? s.substring(1) : s;
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}$buf';
}

/// "₹14,208" style.
String money(num value) => '₹${groupInt(value)}';

/// Compact rupees for big headline numbers: 28400000 -> "₹2.84Cr".
String moneyCompact(num value) {
  final v = value.abs();
  String body;
  if (v >= 10000000) {
    body = '${(value / 10000000).toStringAsFixed(2)}Cr';
  } else if (v >= 100000) {
    body = '${(value / 100000).toStringAsFixed(2)}L';
  } else if (v >= 1000) {
    body = '${(value / 1000).toStringAsFixed(1)}K';
  } else {
    body = value.round().toString();
  }
  return '₹$body';
}

/// Two-letter initials, e.g. "CarePlus Wholesale" -> "CW".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

// -----------------------------------------------------------------------------
// CARD + SNACK
// -----------------------------------------------------------------------------

BoxDecoration adminCard({Color? color, double radius = 16, Color? borderColor}) {
  return BoxDecoration(
    color: color ?? AppColors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

void adminSnack(BuildContext context, String msg, {Color? color}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? AppColors.darkGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}

const ScrollPhysics adminScroll = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);

// -----------------------------------------------------------------------------
// AVATAR
// -----------------------------------------------------------------------------

class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.label, this.size = 44, this.color});

  final String label;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [base, Color.lerp(base, Colors.black, 0.22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HEADERS
// -----------------------------------------------------------------------------

/// Plain left-aligned screen title used on the list screens.
class AdminScreenHeader extends StatelessWidget {
  const AdminScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 12),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(fontSize: 13, color: AppColors.greyText)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Section label with an optional trailing action (e.g. "View all").
class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText)),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
      ],
    );
  }
}

/// Tiny uppercase group label (settings groups, form sections).
class AdminGroupLabel extends StatelessWidget {
  const AdminGroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: AppColors.greyText)),
    );
  }
}

// -----------------------------------------------------------------------------
// NOTIFICATION BELL
// -----------------------------------------------------------------------------

class AdminBell extends StatelessWidget {
  const AdminBell({super.key, required this.count, this.onTap, this.light = false});

  final int count;
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: 0.18) : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: light ? null : Border.all(color: AppColors.border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_outlined,
                size: 22, color: light ? Colors.white : AppColors.darkText),
            if (count > 0)
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                      color: AdminColors.red, shape: BoxShape.circle),
                  child: Text('$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STATUS BADGE
// -----------------------------------------------------------------------------

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color)),
    );
  }
}

// -----------------------------------------------------------------------------
// CHANGE BADGE (↑12% trend)
// -----------------------------------------------------------------------------

class ChangeBadge extends StatelessWidget {
  const ChangeBadge({super.key, required this.pct, this.onLight = false});

  final double pct;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    final color = onLight
        ? Colors.white
        : (up ? AppColors.darkGreen : AdminColors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: onLight
            ? Colors.white.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: color),
          const SizedBox(width: 2),
          Text('${pct.abs().toStringAsFixed(pct.abs() % 1 == 0 ? 0 : 1)}%',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ANIMATED COUNTER
// -----------------------------------------------------------------------------

class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.target,
    required this.style,
    this.decimals = 0,
    this.grouped = false,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  final double target;
  final TextStyle style;
  final int decimals;
  final bool grouped;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, value, _) {
        final body = decimals > 0
            ? value.toStringAsFixed(decimals)
            : (grouped ? groupInt(value.round()) : value.round().toString());
        return Text('$prefix$body$suffix',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
      },
    );
  }
}

// -----------------------------------------------------------------------------
// KPI CARD (icon · number · label · trend) — Overview grid
// -----------------------------------------------------------------------------

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.changePct,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final double? changePct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: adminCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
                if (changePct != null) ChangeBadge(pct: changePct!),
              ],
            ),
            const SizedBox(height: 14),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal stat used in the "summary strip" above a list
/// (e.g. 312 Total · 298 Active · 7 Low · 7 Out).
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: adminCard(),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SEARCH FIELD (+ optional filter button)
// -----------------------------------------------------------------------------

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onFilter,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: AppColors.darkText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.greyText, size: 20),
              filled: true,
              fillColor: AppColors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
        ),
        if (onFilter != null) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 20),
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SEGMENT PILL TABS (stateless, controlled) — filters a single list
// -----------------------------------------------------------------------------

class AdminSegmentTabs extends StatelessWidget {
  const AdminSegmentTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.accent = AppColors.primary,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: padding,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: active ? accent : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? accent : AppColors.border),
              ),
              child: Text(tabs[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : AppColors.greyText)),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// INFO ROW (icon · label · value) — detail screens
// -----------------------------------------------------------------------------

class AdminInfoRow extends StatelessWidget {
  const AdminInfoRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.greyText),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.greyText)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppColors.darkText)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RING GAUGE — circular percentage with centred label
// -----------------------------------------------------------------------------

class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.percent,
    required this.label,
    required this.color,
    this.size = 92,
  });

  final double percent; // 0..1
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent.clamp(0, 1)),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) {
              return CustomPaint(
                painter: _RingPainter(value, color),
                child: Center(
                  child: Text('${(value * 100).round()}%',
                      style: TextStyle(
                          fontSize: size * 0.22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.14);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

// -----------------------------------------------------------------------------
// HORIZONTAL PROGRESS ROW — category split style
// -----------------------------------------------------------------------------

class LabeledBar extends StatelessWidget {
  const LabeledBar({
    super.key,
    required this.label,
    required this.fraction,
    required this.color,
    this.trailing,
  });

  final String label;
  final double fraction; // 0..1
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText)),
              ),
              Text(trailing ?? '${(fraction * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greyText)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SMALL ICON BUTTON (tinted square)
// -----------------------------------------------------------------------------

class TintIconButton extends StatelessWidget {
  const TintIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 18,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PRIMARY / SECONDARY BUTTONS
// -----------------------------------------------------------------------------

class AdminButton extends StatelessWidget {
  const AdminButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.primary,
    this.outlined = false,
    this.expand = true,
    this.height = 50,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color color;
  final bool outlined;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: height,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              icon: Icon(icon ?? Icons.circle, size: icon == null ? 0 : 18),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              icon: Icon(icon ?? Icons.circle, size: icon == null ? 0 : 18),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

// -----------------------------------------------------------------------------
// EMPTY STATE
// -----------------------------------------------------------------------------

class AdminEmpty extends StatelessWidget {
  const AdminEmpty({super.key, required this.label, this.icon = Icons.inbox_outlined});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: AppColors.greyText.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: AppColors.greyText)),
        ],
      ),
    );
  }
}
