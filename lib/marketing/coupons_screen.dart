// =============================================================================
// MediCaPlus — Marketing Head · Coupons tab
//
// Coupon list with code, description, Active/Expired status, redemption count
// and an on/off toggle (expired coupons are greyed out). The "+ Create" button
// opens the Create Campaign screen. Uses the purple marketing accent.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart' show EmptyState;
import 'marketing_controllers.dart';
import 'marketing_models.dart';
import 'create_campaign_screen.dart';

class MarketingCouponsScreen extends StatelessWidget {
  const MarketingCouponsScreen({super.key});

  MarketingCouponsController get _controller =>
      MarketingCouponsController.instance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _header(context),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final coupons = _controller.coupons;
                if (coupons.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'No coupons yet',
                    message: 'Create a campaign to launch your first coupon.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: coupons.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CouponCard(
                    coupon: coupons[i],
                    onToggle: () => _controller.toggleActive(coupons[i].code),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Promotions',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                SizedBox(height: 2),
                Text('Coupons',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.darkGreen,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.onToggle});

  final MarketingCoupon coupon;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final dimmed = coupon.expired;
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 84,
              decoration: BoxDecoration(
                color: dimmed ? AppColors.greyText : AppColors.primary,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16)),
              ),
              child: const Icon(Icons.confirmation_number_outlined,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(coupon.code,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.5,
                                color: AppColors.darkText)),
                        const SizedBox(width: 8),
                        _statusPill(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(coupon.description,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.greyText)),
                    const SizedBox(height: 4),
                    Text('${_formatCount(coupon.redemptions)} redemptions',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreen)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Switch(
                value: coupon.active && !coupon.expired,
                onChanged: coupon.expired ? null : (_) => onToggle(),
                activeThumbColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill() {
    final active = coupon.active && !coupon.expired;
    final color = active ? AppColors.primary : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(coupon.expired ? 'Expired' : (active ? 'Active' : 'Paused'),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  String _formatCount(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
