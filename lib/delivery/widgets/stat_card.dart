import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;

class DeliveryStatCard extends StatelessWidget {
  const DeliveryStatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accentColor,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.darkGreen;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
