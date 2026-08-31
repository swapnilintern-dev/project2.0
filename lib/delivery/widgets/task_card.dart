import 'package:flutter/material.dart';

import '../../customer/customer_widgets.dart' show formatRupees;
import '../../vendor_registration_screen.dart' show AppColors;
import '../../theme/app_theme.dart' show AppPalette;
import '../delivery_models.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onAction,
    this.busy = false,
  });

  final DeliveryTask task;

  /// Advances the task (Pick Up for Shipped, Start Delivery for Out for
  /// Delivery). Null disables the button.
  final VoidCallback? onAction;

  /// True while a backend call for this task is in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isActive = task.status == DeliveryTaskStatus.active;
    final actionLabel = task.status.actionLabel;
    final tagColor = switch (task.status) {
      DeliveryTaskStatus.active => AppColors.primary,
      DeliveryTaskStatus.next => AppPalette.info,
      DeliveryTaskStatus.queued => AppColors.greyText,
      DeliveryTaskStatus.completed => AppColors.darkGreen,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.darkGreen : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? AppColors.darkGreen : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${task.id}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : AppColors.darkText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: isActive ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.status.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : tagColor,
                  ),
                ),
              ),
              const Spacer(),
              if (!isActive)
                Text(
                  'Scheduled after current task',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.greyText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.pharmacyName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : AppColors.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            task.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppColors.greyText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Distance/ETA aren't tracked by the backend — show item + COD.
              _meta(Icons.inventory_2_outlined, '${task.itemCount} items',
                  isActive),
              const SizedBox(width: 14),
              _meta(Icons.payments_outlined,
                  'COD ${formatRupees(task.codAmount)}', isActive),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isActive ? Colors.white : AppColors.primary,
                  foregroundColor:
                      isActive ? AppColors.darkGreen : Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isActive ? Colors.white70 : AppColors.greyText,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white70 : AppColors.greyText,
            ),
          ),
        ),
      ],
    );
  }
}
