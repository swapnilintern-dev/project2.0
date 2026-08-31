// =============================================================================
// MediCaPlus — Admin · User Management (tab 3)
//
// Directory split by kind via segment tabs (Vendors / Delivery Agents). A
// headline stat strip (vendors / agents), a search field, and tagged user
// rows. The Delivery Agents tab links through to the Delivery Management
// console.
// =============================================================================

import 'package:flutter/material.dart';

import '../../account_deletion/account_deletion_controller.dart';
import '../../account_deletion/admin_deletion_requests_screen.dart';
import '../../services/live_refresh.dart';
import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import '../admin_users_controller.dart';
import 'delivery_management_screen.dart';
import 'user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with LiveRefreshMixin {
  int _tab = 0;
  String _query = '';

  static const _tabs = ['Vendors', 'Delivery Agents'];
  static const _kinds = [UserKind.customer, UserKind.agent];

  @override
  void initState() {
    super.initState();
    // Fetch the live directory (vendors + delivery agents) from the backend,
    // deferred a frame so the first load never notifies during build. Then keep
    // it live via the poll + app-resume (immediate: false avoids a double load).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdminUsersController.instance.load();
    });
    startLiveRefresh(immediate: false);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => AdminUsersController.instance.load();

  // Reads from the live user store so fetches/deletions reflect immediately.
  List<PlatformUser> _filteredFor(int tab) {
    var list = AdminUsersController.instance.byKind(_kinds[tab]);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((u) {
        final hay =
            '${u.name} ${u.meta} ${u.location} ${u.email}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // One clamped index guards every read below (list, tab highlight, delivery
    // button) from a stale out-of-range tab retained across a hot reload.
    final tab = _tab.clamp(0, _tabs.length - 1);
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AdminScreenHeader(title: 'User Management'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AdminSegmentTabs(
                tabs: _tabs,
                selected: tab,
                onChanged: (i) => setState(() => _tab = i),
                padding: EdgeInsets.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AdminSearchField(
                hint: 'Search vendors and delivery agents...',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ListenableBuilder(
                listenable: AdminUsersController.instance,
                builder: (context, _) {
                  final c = AdminUsersController.instance;
                  return Row(
                    children: [
                      Expanded(
                        child: MiniStat(
                          value: groupInt(c.countOf(UserKind.customer)),
                          label: 'Vendors',
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MiniStat(
                          value: groupInt(c.countOf(UserKind.agent)),
                          label: 'Agents',
                          color: AdminColors.purple,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (tab == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: AdminButton(
                  label: 'Open Delivery Console',
                  icon: Icons.delivery_dining_outlined,
                  height: 44,
                  onPressed: () =>
                      adminPush(context, const DeliveryManagementScreen()),
                ),
              ),
            // Account-deletion requests raised by vendors / delivery partners.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: ListenableBuilder(
                listenable: AccountDeletionController.instance,
                builder: (context, _) {
                  final pending =
                      AccountDeletionController.instance.pendingCount;
                  return AdminButton(
                    label: pending > 0
                        ? 'Deletion Requests · $pending pending'
                        : 'Deletion Requests',
                    icon: Icons.delete_sweep_outlined,
                    outlined: true,
                    color: AdminColors.red,
                    height: 44,
                    onPressed: () => adminPush(
                        context, const AdminDeletionRequestsScreen()),
                  );
                },
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: AdminUsersController.instance,
                builder: (context, _) {
                  final c = AdminUsersController.instance;
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => c.load(force: true),
                    child: _body(context, c, tab),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The list area: a spinner on the first load, a retry card on failure, an
  /// empty state, or the tagged user rows. Every branch is scrollable so the
  /// pull-to-refresh gesture works from any state.
  Widget _body(BuildContext context, AdminUsersController c, int tab) {
    // First load in flight and nothing to show yet.
    if (c.isLoading && !c.isLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Fetch failed and we have no cached data — offer a retry.
    if (c.error != null && !c.isLoaded) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 46, color: AppColors.greyText),
          const SizedBox(height: 12),
          Text(
            c.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.greyText, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 160,
              child: AdminButton(
                label: 'Retry',
                icon: Icons.refresh,
                height: 44,
                onPressed: () => c.load(force: true),
              ),
            ),
          ),
        ],
      );
    }

    final list = _filteredFor(tab);
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          const SizedBox(height: 80),
          AdminEmpty(
            label: _query.isNotEmpty
                ? 'No matches for "$_query"'
                : (tab == 0 ? 'No vendors yet' : 'No delivery agents yet'),
            icon: tab == 0
                ? Icons.storefront_outlined
                : Icons.delivery_dining_outlined,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: list.length,
      itemBuilder: (_, i) => _UserRow(
        user: list[i],
        onTap: () => adminPush(context, UserDetailScreen(user: list[i])),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onTap});
  final PlatformUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarColor = switch (user.kind) {
      UserKind.customer => AdminColors.blue,
      UserKind.agent => AdminColors.purple,
      UserKind.staff => AppColors.darkGreen,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: adminCard(),
        child: Row(
          children: [
            AdminAvatar(
              label: initialsOf(user.name),
              size: 46,
              color: avatarColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (user.tag != null)
              StatusBadge(
                label: user.tag!.label,
                color: user.tag!.color,
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}
