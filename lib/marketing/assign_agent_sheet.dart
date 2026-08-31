// =============================================================================
// MediCaPlus — Marketing Head · Assign Delivery Agent sheet
//
// Shown when the marketing team moves a Shipped order to "Out for Delivery":
// it lists the REAL delivery partners from the backend (role == "delivery",
// via MarketingAgentsController) and returns the one the user taps. No dummy
// data — a spinner while loading, a retry on failure, and an empty state when
// there are no delivery agents registered yet.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'marketing_controllers.dart';
import 'marketing_models.dart';

/// Opens the picker and returns the chosen [DeliveryAgent], or null if
/// dismissed. Refreshes the agent list from the backend each time it opens.
Future<DeliveryAgent?> showAssignAgentSheet(
  BuildContext context,
  MarketingOrder order,
) {
  // Fetch the latest agents whenever the sheet opens.
  MarketingAgentsController.instance.refresh();
  return showModalBottomSheet<DeliveryAgent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => _AssignAgentSheet(order: order),
  );
}

class _AssignAgentSheet extends StatelessWidget {
  const _AssignAgentSheet({required this.order});

  final MarketingOrder order;

  @override
  Widget build(BuildContext context) {
    final ctrl = MarketingAgentsController.instance;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.delivery_dining_outlined,
                    color: AppColors.darkGreen),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Assign Delivery Agent',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.greyText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text('Order #${order.id} · ${order.buyer}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.greyText)),
            const SizedBox(height: 12),
            // 55% of screen height keeps the sheet comfortable on small phones.
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: ListenableBuilder(
                listenable: ctrl,
                builder: (context, _) => _body(context, ctrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, MarketingAgentsController ctrl) {
    if (ctrl.isLoading && ctrl.agents.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (ctrl.error != null && ctrl.agents.isEmpty) {
      return _centered(
        icon: Icons.wifi_off_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.refresh,
      );
    }
    if (ctrl.agents.isEmpty) {
      return _centered(
        icon: Icons.person_off_outlined,
        title: 'No delivery agents registered yet',
        actionLabel: 'Refresh',
        onAction: ctrl.refresh,
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: ctrl.agents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _AgentTile(
        agent: ctrl.agents[i],
        onTap: () => Navigator.of(context).pop(ctrl.agents[i]),
      ),
    );
  }

  Widget _centered({
    required IconData icon,
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.greyText),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.greyText, fontSize: 13.5)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(actionLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkGreen,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent, required this.onTap});

  final DeliveryAgent agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (agent.city.isNotEmpty) agent.city,
      if (agent.phone.isNotEmpty) agent.phone,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.lightGreenBg,
              child: Text(agent.initials,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.darkGreen)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.greyText)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}
