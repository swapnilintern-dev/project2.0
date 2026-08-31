// =============================================================================
// MediCaPlus — Admin · Dispute Resolution (pushed from Orders)
//
// Single-dispute view: a red alert banner with the reason, the buyer & vendor
// parties, the conversation thread (buyer left / vendor right), attached
// evidence thumbnails, and sticky Refund Buyer / Resolve actions.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_models.dart';

class DisputeScreen extends StatelessWidget {
  const DisputeScreen({super.key, required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispute #${dispute.id}',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            Text('Order #${dispute.orderId}',
                style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
          ],
        ),
      ),
      body: ListView(
        physics: adminScroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _alert(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _party('Buyer', dispute.buyer, Icons.shopping_bag_outlined,
                    AdminColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _party('Vendor', dispute.vendor, Icons.storefront_outlined,
                    AppColors.darkGreen),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const AdminSectionTitle('Conversation'),
          const SizedBox(height: 12),
          ...dispute.messages.map((m) => _Bubble(message: m)),
          const SizedBox(height: 16),
          const AdminSectionTitle('Evidence'),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < dispute.evidenceCount; i++) ...[
                _Evidence(index: i + 1),
                if (i != dispute.evidenceCount - 1) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AdminButton(
                  label: 'Refund Buyer',
                  icon: Icons.currency_rupee,
                  color: AdminColors.red,
                  outlined: true,
                  onPressed: () {
                    adminSnack(context, 'Refund of ${money(dispute.amount)} issued',
                        color: AdminColors.red);
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminButton(
                  label: 'Resolve',
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    adminSnack(context, 'Dispute #${dispute.id} resolved');
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alert() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AdminColors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dispute.reason,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.red)),
                const SizedBox(height: 2),
                Text(dispute.detail,
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
          const StatusBadge(label: 'Open', color: AdminColors.red, filled: true),
        ],
      ),
    );
  }

  Widget _party(String role, String name, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: adminCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(role.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final DisputeMessage message;

  @override
  Widget build(BuildContext context) {
    final vendor = message.fromVendor;
    final bg = vendor ? AppColors.lightGreenBg : AppColors.white;
    final align = vendor ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(message.author,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.greyText)),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.74),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(vendor ? 14 : 4),
                bottomRight: Radius.circular(vendor ? 4 : 14),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(message.text,
                style: const TextStyle(
                    fontSize: 13, height: 1.35, color: AppColors.darkText)),
          ),
        ],
      ),
    );
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.4,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.lightGreenBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_outlined,
                  color: AppColors.darkGreen, size: 26),
              const SizedBox(height: 6),
              Text('Evidence $index',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreen)),
            ],
          ),
        ),
      ),
    );
  }
}
