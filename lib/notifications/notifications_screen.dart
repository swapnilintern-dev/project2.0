// =============================================================================
// VS Arogya — Notifications
//
// The signed-in account's own notification feed, live from the backend. Shown
// to every role; the rows themselves differ by what the server has sent that
// account (order events for a vendor, approval results, general messages).
//
// Reached from the Profile screen's Notifications row.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'user_inbox_api.dart';
import 'user_inbox_controller.dart';

/// Icon + colour per backend notification type. An unrecognised type (one the
/// server adds later) falls back to a neutral bell rather than breaking.
({IconData icon, Color color}) _styleFor(String type) => switch (type) {
      'ORDER_PLACED' => (icon: Icons.receipt_long_outlined, color: AppColors.primary),
      'ORDER_PROCESSING' => (icon: Icons.inventory_2_outlined, color: AppColors.darkGreen),
      'ORDER_SHIPPED' => (icon: Icons.local_shipping_outlined, color: const Color(0xFF3B82F6)),
      'OUT_FOR_DELIVERY' => (icon: Icons.delivery_dining_outlined, color: const Color(0xFFF59E0B)),
      'ORDER_DELIVERED' => (icon: Icons.check_circle_outline, color: AppColors.primary),
      'ORDER_CANCELLED' => (icon: Icons.cancel_outlined, color: AppColors.error),
      'PAYMENT_SUCCESS' => (icon: Icons.payments_outlined, color: AppColors.primary),
      'PAYMENT_FAILED' => (icon: Icons.money_off_outlined, color: AppColors.error),
      'VENDOR_APPROVED' => (icon: Icons.verified_outlined, color: AppColors.primary),
      'VENDOR_REJECTED' => (icon: Icons.gpp_bad_outlined, color: AppColors.error),
      _ => (icon: Icons.notifications_none, color: AppColors.greyText),
    };

String _timeAgo(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${when.day}/${when.month}/${when.year}';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Null until the server answers — the switch stays hidden rather than
  /// guessing a default and showing the user a state that isn't theirs.
  NotificationSettings? _settings;
  bool _savingPref = false;

  @override
  void initState() {
    super.initState();
    // Fetch after the first frame so the screen paints immediately and the
    // spinner is part of the built tree rather than blocking it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UserInboxController.instance.refresh();
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final s = await const UserInboxApi().fetchSettings();
    if (!mounted) return;
    setState(() => _settings = s);
  }

  Future<void> _togglePush(bool next) async {
    setState(() => _savingPref = true);
    final result = await const UserInboxApi().setNotificationsEnabled(next);
    if (!mounted) return;

    setState(() {
      _savingPref = false;
      // Adopt the SERVER's value, not the one just tapped — if the call failed
      // the switch must snap back rather than showing a preference that was
      // never saved.
      if (result != null && _settings != null) {
        _settings = NotificationSettings(
          enabled: result,
          registeredDevices: _settings!.registeredDevices,
          pushConfigured: _settings!.pushConfigured,
        );
      }
    });

    if (result == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Could not save that. Please try again.')));
    }
  }

  /// Account-level push opt-in.
  Widget _pushToggle() {
    final s = _settings;
    if (s == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Push notifications',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  !s.pushConfigured
                      // Nobody gets push in this case, so don't let the user
                      // think their own switch is what's stopping it.
                      ? 'Push is not set up on the server yet'
                      : s.enabled
                          ? 'Alerts on your device. This list fills either way.'
                          : 'Device alerts off. This list still fills.',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.greyText),
                ),
              ],
            ),
          ),
          if (_savingPref)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            Switch(
              value: s.enabled,
              activeThumbColor: AppColors.primary,
              onChanged: s.pushConfigured ? _togglePush : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = UserInboxController.instance;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: controller.markAllRead,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.darkGreen),
                child: const Text('Mark all read',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.loading && !controller.loadedOnce) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (controller.isEmpty) return _empty();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              // +1 for the preference row pinned above the feed.
              itemCount: controller.items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => i == 0
                  ? _pushToggle()
                  : _tile(controller.items[i - 1]),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() => LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: UserInboxController.instance.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 56, color: AppColors.border),
                    SizedBox(height: 12),
                    Text('No notifications yet',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                      'Order updates and account messages will appear here.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.greyText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _tile(UserNotification n) {
    final style = _styleFor(n.type);
    return InkWell(
      onTap: n.isRead
          ? null
          : () => UserInboxController.instance.markRead(n.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          // Unread rows get the tinted background — the only visual difference,
          // so the list stays calm when everything has been read.
          color: n.isRead ? AppColors.white : AppColors.lighterGreen,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.isRead ? AppColors.border : AppColors.primary,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, size: 19, color: style.color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                n.isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.message,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.greyText, height: 1.35),
                  ),
                  if (n.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(n.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.greyText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
