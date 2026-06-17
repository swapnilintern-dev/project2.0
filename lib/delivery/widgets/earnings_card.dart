import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;

class EarningsCard extends StatelessWidget {
  const EarningsCard({
    super.key,
    required this.orderId,
    required this.route,
    required this.earnings,
    required this.timeLabel,
  });

  final String orderId;
  final String route;
  final String earnings;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delivery_dining,
                color: AppColors.darkGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderId',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  route,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            earnings,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}
