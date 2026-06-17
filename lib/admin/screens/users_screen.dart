// =============================================================================
// MediCaPlus — Admin · User Management (tab 3)
//
// Directory of everyone on the platform, split by kind via segment tabs
// (Customers / Agents / Staff). A headline stat strip (customers / vendors /
// agents), a search field, and tagged user rows (Premium, New, Flagged…).
// Agents tab links through to the Delivery Management console.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'delivery_management_screen.dart';
import 'user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  // TODO: GET /api/admin/users
  final List<PlatformUser> _users = kUsers;
  int _tab = 0;
  String _query = '';

  static const _tabs = ['Customers', 'Agents', 'Staff'];
  static const _kinds = [UserKind.customer, UserKind.agent, UserKind.staff];

  List<PlatformUser> get _filtered {
    var list = _users.where((u) => u.kind == _kinds[_tab]);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((u) => u.name.toLowerCase().contains(q));
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
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
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
                padding: EdgeInsets.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AdminSearchField(
                hint: 'Search users…',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                      child: MiniStat(
                          value: '12.4k',
                          label: 'Customers',
                          color: AdminColors.blue)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: MiniStat(
                          value: groupInt(kVendorCount),
                          label: 'Vendors',
                          color: AppColors.darkGreen)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: MiniStat(
                          value: '$kAgentCount',
                          label: 'Agents',
                          color: AdminColors.purple)),
                ],
              ),
            ),
            if (_tab == 1)
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
            Expanded(
              child: list.isEmpty
                  ? const AdminEmpty(label: 'No users found')
                  : ListView.builder(
                      physics: adminScroll,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _UserRow(
                        user: list[i],
                        onTap: () => adminPush(
                            context, UserDetailScreen(user: list[i])),
                      ),
                    ),
            ),
          ],
        ),
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
            AdminAvatar(label: initialsOf(user.name), size: 46, color: avatarColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText)),
                  const SizedBox(height: 2),
                  Text(user.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.greyText)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (user.tag != null)
              StatusBadge(label: user.tag!.label, color: user.tag!.color, dense: true),
          ],
        ),
      ),
    );
  }
}
