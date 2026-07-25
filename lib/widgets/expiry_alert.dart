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
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;

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
