// =============================================================================
// MediCaPlus — Admin · Account Deletion Requests
//
// The admin reviews deletion requests raised by Vendors / Delivery Partners and
// approves or rejects each. Approving also removes the matching user from the
// admin directory (AdminUsersController) — and, with a backend, would delete
// the account server-side. Reached from the Users screen.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../admin/admin_common.dart';
import '../admin/admin_users_controller.dart';
import 'account_deletion_controller.dart';

class AdminDeletionRequestsScreen extends StatelessWidget {
  const AdminDeletionRequestsScreen({super.key});

  AccountDeletionController get _controller =>
      AccountDeletionController.instance;

  Color _statusColor(DeletionStatus s) => switch (s) {
        DeletionStatus.pending => AdminColors.orange,
        DeletionStatus.approved => AdminColors.green,
        DeletionStatus.rejected => AdminColors.red,
      };

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Deletion Requests',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.darkText)),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final requests = _controller.requests;
          if (requests.isEmpty) {
            return const AdminEmpty(
              label: 'No deletion requests',
              icon: Icons.delete_sweep_outlined,
            );
          }
          final pending = _controller.pendingCount;
          return ListView(
            physics: adminScroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                '$pending pending · ${requests.length} total',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greyText),
              ),
              const SizedBox(height: 12),
              for (final req in requests) _requestCard(context, req),
            ],
          );
        },
      ),
    );
  }

  Widget _requestCard(BuildContext context, AccountDeletionRequest req) {
    final statusColor = _statusColor(req.status);
    final isPending = req.status == DeletionStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: adminCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminAvatar(
                label: initialsOf(req.userName),
                size: 44,
                color: req.role == DeletionRole.vendor
                    ? AdminColors.blue
                    : AdminColors.purple,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText)),
                    const SizedBox(height: 2),
                    Text('${req.role.label} · ${_timeAgo(req.requestedAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.greyText)),
                  ],
                ),
              ),
              StatusBadge(
                  label: req.status.label, color: statusColor, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reason',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.greyText)),
                const SizedBox(height: 4),
                Text(req.reason,
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.darkText,
                        height: 1.4)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Request #${req.id}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.greyText)),
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AdminButton(
                    label: 'Reject',
                    icon: Icons.close,
                    outlined: true,
                    color: AdminColors.red,
                    height: 44,
                    onPressed: () => _reject(context, req),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminButton(
                    label: 'Approve & Delete',
                    icon: Icons.check,
                    color: AdminColors.red,
                    height: 44,
                    onPressed: () => _approve(context, req),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approve(
      BuildContext context, AccountDeletionRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & delete account?'),
        content: Text(
          '${req.userName}’s account will be deleted. This may not be '
          'reversible.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve & Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // TODO(backend): DELETE the user server-side, then mark the request approved.
    AccountDeletionController.instance.approve(req.id);
    AdminUsersController.instance.removeByName(req.userName);
    if (context.mounted) {
      adminSnack(context, '${req.userName} deleted', color: AdminColors.red);
    }
  }

  void _reject(BuildContext context, AccountDeletionRequest req) {
    AccountDeletionController.instance.reject(req.id);
    adminSnack(context, 'Request from ${req.userName} rejected');
  }
}
