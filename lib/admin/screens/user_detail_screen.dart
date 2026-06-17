// =============================================================================
// MediCaPlus — Admin · User Details (pushed from User Management)
//
// One adaptive screen for every kind of platform user. The header accent,
// title, headline stats, "Information" rows and activity timeline all come
// from the selected [PlatformUser], so a Customer, Delivery Agent and Staff
// member each render their own relevant detail set without separate screens.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_models.dart';

class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.user});

  final PlatformUser user;

  @override
  Widget build(BuildContext context) {
    final accent = user.kind.color;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(user.kind.detailTitle,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.darkText)),
        actions: [
          IconButton(
            tooltip: 'More',
            onPressed: () => _moreSheet(context, accent),
            icon: const Icon(Icons.more_vert, color: AppColors.darkText),
          ),
        ],
      ),
      body: ListView(
        physics: adminScroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _header(accent),
          const SizedBox(height: 16),
          _contactBar(context, accent),
          if (user.stats.isNotEmpty) ...[
            const SizedBox(height: 20),
            _statsRow(),
          ],
          if (user.info.isNotEmpty) ...[
            const SizedBox(height: 22),
            const AdminGroupLabel('Information'),
            _infoCard(),
          ],
          if (user.timeline.isNotEmpty) ...[
            const SizedBox(height: 20),
            AdminSectionTitle(user.timelineTitle),
            const SizedBox(height: 12),
            ...user.timeline.map(_TimelineRow.new),
          ],
        ],
      ),
    );
  }

  // ---- Header --------------------------------------------------------------

  Widget _header(Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: adminCard(),
      child: Column(
        children: [
          Row(
            children: [
              AdminAvatar(label: initialsOf(user.name), size: 60, color: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _kindChip(accent),
                        if (user.tag != null)
                          StatusBadge(
                              label: user.tag!.label,
                              color: user.tag!.color,
                              dense: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.greyText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(user.location,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.greyText)),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.greyText),
              const SizedBox(width: 6),
              Text('Joined ${user.joinedOn}',
                  style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kindChip(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(user.kind.icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(user.kind.label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }

  // ---- Contact actions -----------------------------------------------------

  Widget _contactBar(BuildContext context, Color accent) {
    return Row(
      children: [
        Expanded(
          child: _ContactButton(
            icon: Icons.call_outlined,
            label: 'Call',
            accent: accent,
            onTap: () => adminSnack(context, 'Calling ${user.phone}'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContactButton(
            icon: Icons.mail_outline,
            label: 'Email',
            accent: accent,
            onTap: () => adminSnack(context, user.email),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContactButton(
            icon: Icons.chat_bubble_outline,
            label: 'Message',
            accent: accent,
            onTap: () => adminSnack(context, 'Messaging ${user.name}'),
          ),
        ),
      ],
    );
  }

  // ---- Stats ---------------------------------------------------------------

  Widget _statsRow() {
    return Row(
      children: [
        for (int i = 0; i < user.stats.length; i++) ...[
          Expanded(
            child: MiniStat(
              value: user.stats[i].value,
              label: user.stats[i].label,
              color: user.stats[i].color ?? AppColors.darkText,
            ),
          ),
          if (i != user.stats.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  // ---- Information ---------------------------------------------------------

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: adminCard(),
      child: Column(
        children: [
          for (int i = 0; i < user.info.length; i++) ...[
            AdminInfoRow(label: user.info[i].label, value: user.info[i].value),
            if (i != user.info.length - 1)
              const Divider(height: 14, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  // ---- Overflow actions ----------------------------------------------------

  void _moreSheet(BuildContext context, Color accent) {
    final suspended = user.tag == UserTag.flagged ||
        user.tag == UserTag.suspended;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _SheetItem(
              icon: Icons.edit_outlined,
              label: 'Edit ${user.kind.label}',
              onTap: () {
                Navigator.pop(sheetCtx);
                adminSnack(context, 'Edit ${user.name}');
              },
            ),
            _SheetItem(
              icon: Icons.lock_reset,
              label: 'Reset Login',
              onTap: () {
                Navigator.pop(sheetCtx);
                adminSnack(context, 'Login reset for ${user.name}');
              },
            ),
            _SheetItem(
              icon: suspended ? Icons.lock_open_outlined : Icons.block,
              label: suspended ? 'Reactivate Account' : 'Suspend Account',
              danger: !suspended,
              onTap: () {
                Navigator.pop(sheetCtx);
                adminSnack(
                  context,
                  suspended
                      ? '${user.name} reactivated'
                      : '${user.name} suspended',
                  color: suspended ? AppColors.darkGreen : AdminColors.red,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.entry);
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: adminCard(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(entry.icon, size: 20, color: entry.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text(entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(entry.time,
              style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AdminColors.red : AppColors.darkText;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w600, color: color)),
      onTap: onTap,
    );
  }
}
