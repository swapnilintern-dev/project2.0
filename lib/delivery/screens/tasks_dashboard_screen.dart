import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../../theme/app_theme.dart' show AppPalette;
import '../../services/live_refresh.dart';
import '../../customer/customer_widgets.dart' show showAppSnack;
import '../delivery_models.dart';
import '../screens/delivery_verification_screen.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_card.dart';

class TasksDashboardScreen extends StatefulWidget {
  const TasksDashboardScreen({super.key});

  @override
  State<TasksDashboardScreen> createState() => _TasksDashboardScreenState();
}

class _TasksDashboardScreenState extends State<TasksDashboardScreen>
    with LiveRefreshMixin {
  /// Id of the task whose Pick Up call is in flight (so only its button spins).
  String? _busyId;

  DeliveryController get _ctrl => DeliveryController.instance;

  @override
  void initState() {
    super.initState();
    // Keep the dispatch queue live so orders the marketing/admin team ship
    // surface here on their own.
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _ctrl.refresh();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _onAction(DeliveryTask task) {
    if (task.status == DeliveryTaskStatus.active) {
      // Out for Delivery -> open the confirm-delivery screen.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliveryVerificationScreen(taskId: task.id),
        ),
      );
      return;
    }
    // Shipped -> pick up (Out for Delivery).
    _pickUp(task);
  }

  Future<void> _pickUp(DeliveryTask task) async {
    setState(() => _busyId = task.id);
    final error = await _ctrl.pickUp(task.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    showAppSnack(
      context,
      error ?? 'Order #${_shortId(task.id)} picked up — out for delivery',
      success: error == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        final rider = _ctrl.rider;
        final tasks = _ctrl.tasks;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _ctrl.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _header(rider)),
              SliverToBoxAdapter(child: _statsRow(_ctrl)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dispatch Queue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_ctrl.isLoaded && tasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (tasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'No orders ready for delivery right now.',
                              style: TextStyle(color: AppColors.greyText),
                            ),
                          ),
                        )
                      else
                        for (final task in tasks)
                          TaskCard(
                            task: task,
                            busy: _busyId == task.id,
                            onAction: () => _onAction(task),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(RiderProfile rider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: const BoxDecoration(
        gradient: AppPalette.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                rider.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()},',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    rider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(DeliveryController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          DeliveryStatCard(
            value: '${ctrl.activeTasks.length + ctrl.pickupTasks.length}',
            label: 'Open Tasks',
            icon: Icons.assignment_outlined,
          ),
          const SizedBox(width: 10),
          DeliveryStatCard(
            value: '${ctrl.deliveredThisSession}',
            label: 'Delivered',
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }
}

/// Short, readable order reference from a Mongo _id (last 6 chars, upper-case).
String _shortId(String id) {
  if (id.length <= 6) return id.toUpperCase();
  return id.substring(id.length - 6).toUpperCase();
}
