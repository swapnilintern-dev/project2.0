// =============================================================================
// VS Arogya — Expiry alert widgets (Batch & Expiry tracking)
//
// A red "Expiring Soon" warning shown ONLY in the Marketing and Outlet roles
// when the backend flags a product's batch as expiring within 90 days
// (`isExpiringSoon`, computed live server-side from the current date). No other
// role imports these, so the alert never leaks to Admin / Vendor / Delivery /
// Customer.
//
// Two shapes, same meaning:
//   • [ExpiryAlertBanner] — full-width row for cards and detail screens.
//   • [ExpiryAlertBadge]  — compact pill for tight spots (e.g. the edit screen).
// Both reuse the shared palette so they match the existing theme.
//
// [ExpiryTier] grades a batch's remaining shelf life on a four-step scale and is
// the SINGLE definition of those colours — every batch row, pill and picker in
// Marketing and Outlet reads it, so the same expiry always looks the same
// wherever it appears. The tier is derived from the backend's `expiry_date`
// (never a locally invented value); `isExpiringSoon` remains the server's own
// ≤90-day flag and stays authoritative for the red alert.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;

/// How close a batch is to expiry, on the agreed four-step scale:
///   expired / ≤30 days → red · 31–90 → orange · 91–180 → amber · >180 → green
enum ExpiryTier { expired, critical, warning, caution, safe, unknown }

extension ExpiryTierX on ExpiryTier {
  /// The colour used for this tier's text, icon and pill background tint.
  Color get color => switch (this) {
        ExpiryTier.expired => const Color(0xFFB3261E),
        ExpiryTier.critical => AppColors.error,
        ExpiryTier.warning => const Color(0xFFE8710A),
        ExpiryTier.caution => const Color(0xFFB98900),
        ExpiryTier.safe => AppColors.primary,
        ExpiryTier.unknown => AppColors.greyText,
      };

  /// Short pill text ("Expired", "Critical", "Expiring Soon"…).
  String get label => switch (this) {
        ExpiryTier.expired => 'Expired',
        ExpiryTier.critical => 'Critical',
        ExpiryTier.warning => 'Expiring Soon',
        ExpiryTier.caution => 'Watch',
        ExpiryTier.safe => 'Good',
        ExpiryTier.unknown => 'No expiry',
      };

  /// True for the tiers that must never be sold or assigned.
  bool get blocksSale => this == ExpiryTier.expired;

  /// Whether this tier deserves the user's attention (drives the warning icon).
  bool get isAlarming =>
      this == ExpiryTier.expired ||
      this == ExpiryTier.critical ||
      this == ExpiryTier.warning;
}

/// Grades [expiry] against today. A null date means the lot carries no printed
/// expiry — [ExpiryTier.unknown], which is sellable (the backend treats a null
/// expiry as "never expires" when ordering FEFO).
ExpiryTier expiryTierOf(DateTime? expiry) {
  if (expiry == null) return ExpiryTier.unknown;
  final days = daysToExpiry(expiry)!;
  if (days < 0) return ExpiryTier.expired;
  if (days <= 30) return ExpiryTier.critical;
  if (days <= 90) return ExpiryTier.warning;
  if (days <= 180) return ExpiryTier.caution;
  return ExpiryTier.safe;
}

/// Whole days from today until [expiry] (negative once past). Null when the lot
/// has no expiry date.
int? daysToExpiry(DateTime? expiry) {
  if (expiry == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(expiry.year, expiry.month, expiry.day);
  return target.difference(today).inDays;
}

/// "Exp Mar 2027" / "Expired Jan 2025" — the compact form used on batch rows.
String formatExpiry(DateTime? expiry) {
  if (expiry == null) return 'No expiry';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final label = '${months[expiry.month - 1]} ${expiry.year}';
  return expiryTierOf(expiry) == ExpiryTier.expired
      ? 'Expired $label'
      : 'Exp $label';
}

/// "12 days left" / "Expired 4 days ago" / "1 yr 2 mo left" — the longer form
/// shown inside the batch picker, where the exact runway matters.
String expiryCountdown(DateTime? expiry) {
  final days = daysToExpiry(expiry);
  if (days == null) return 'No printed expiry';
  if (days < 0) {
    final ago = -days;
    return ago == 1 ? 'Expired yesterday' : 'Expired $ago days ago';
  }
  if (days == 0) return 'Expires today';
  if (days == 1) return '1 day left';
  if (days < 60) return '$days days left';
  final months = days ~/ 30;
  if (months < 12) return '$months months left';
  final years = months ~/ 12;
  final rem = months % 12;
  return rem == 0 ? '$years yr left' : '$years yr $rem mo left';
}

/// Colour-coded expiry pill — "Expiring Soon", "Critical", "Expired"…
/// Rendered from [ExpiryTier], so the whole app grades expiry identically.
class ExpiryTierBadge extends StatelessWidget {
  const ExpiryTierBadge({super.key, required this.expiry, this.dense = false});

  final DateTime? expiry;

  /// Tighter padding + smaller text, for use inside dense list rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tier = expiryTierOf(expiry);
    // A lot with no printed expiry needs no pill — the row already says so.
    if (tier == ExpiryTier.unknown) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tier.isAlarming) ...[
            Icon(Icons.warning_amber_rounded,
                size: dense ? 11 : 12, color: tier.color),
            const SizedBox(width: 3),
          ],
          Text(tier.label,
              style: TextStyle(
                  fontSize: dense ? 9.5 : 10.5,
                  fontWeight: FontWeight.w800,
                  color: tier.color)),
        ],
      ),
    );
  }
}

/// Full-width red warning banner: "⚠ Expiring Soon — within next 3 months".
class ExpiryAlertBanner extends StatelessWidget {
  const ExpiryAlertBanner({super.key, this.message = 'Expiring within next 3 months'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

/// Compact red pill: "⚠ Expiring Soon".
class ExpiryAlertBadge extends StatelessWidget {
  const ExpiryAlertBadge({super.key, this.label = 'Expiring Soon'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 12, color: AppColors.error),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error)),
        ],
      ),
    );
  }
}
