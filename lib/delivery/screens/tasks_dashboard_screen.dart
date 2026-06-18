import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../../theme/app_theme.dart' show AppPalette;
import '../delivery_mock_data.dart';
import '../delivery_models.dart';
import '../screens/delivery_verification_screen.dart';
import '../screens/route_screen.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_card.dart';

class TasksDashboardScreen extends StatefulWidget {
  const TasksDashboardScreen({
    super.key,
    required this.onOpenRoute,
  });

  final VoidCallback onOpenRoute;

  @override
  State<TasksDashboardScreen> createState() => _TasksDashboardScreenState();
}

class _TasksDashboardScreenState extends State<TasksDashboardScreen> {
  @override
  void initState() {
    super.initState();
    DeliveryMockData.seed();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _startDelivery(DeliveryTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeliveryVerificationScreen(taskId: task.id),
      ),
    );
  }

  void _openRoute(DeliveryTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouteScreen(taskId: task.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DeliveryController.instance,
      builder: (context, _) {
        final ctrl = DeliveryController.instance;
        final rider = ctrl.rider ?? DeliveryMockData.rider;
        final tasks = ctrl.todayTasks;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _header(rider, ctrl)),
            SliverToBoxAdapter(child: _statsRow(ctrl)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Tasks",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No tasks assigned for today.',
                            style: TextStyle(color: AppColors.greyText),
                          ),
                        ),
                      )
                    else
                      for (final task in tasks)
                        TaskCard(
                          task: task,
                          onNavigate: task.status ==
                                  DeliveryTaskStatus.active
                              ? () {
                                  widget.onOpenRoute();
                                  _openRoute(task);
                                }
                              : () {},
                          onStartDelivery: task.status ==
                                  DeliveryTaskStatus.active
                              ? () => _startDelivery(task)
                              : null,
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(RiderProfile rider, DeliveryController ctrl) {
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
            Column(
              children: [
                Text(
                  ctrl.online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Switch.adaptive(
                  value: ctrl.online,
                  onChanged: ctrl.setOnline,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(DeliveryController ctrl) {
    final rider = ctrl.rider ?? DeliveryMockData.rider;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          DeliveryStatCard(
            value: '${ctrl.todayDeliveryCount}',
            label: 'Deliveries',
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(width: 10),
          DeliveryStatCard(
            value: '₹${ctrl.todayEarnings.round()}',
            label: 'Earned',
            icon: Icons.currency_rupee,
          ),
          const SizedBox(width: 10),
          DeliveryStatCard(
            value: '${rider.rating}',
            label: 'Rating',
            icon: Icons.star,
            accentColor: AppPalette.warning,
          ),
        ],
      ),
    );
  }
}
