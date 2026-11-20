// =============================================================================
// VS Arogya — Vendor Registration Status
//
// The presentation for the two states that sit between "registered" and
// "shopping with prices":
//   • SUBMITTED / UNDER REVIEW — the admin has not decided yet,
//   • REJECTED                 — the admin declined; the vendor resubmits.
//
// Everything shown here is read from VendorApproval (lib/services/vendor_approval.dart),
// which mirrors the backend's `approvalStatus` field. This screen NEVER changes
// a vendor's status — the admin portal and the backend own that.
//
// "Update & Resubmit" reopens the EXISTING VendorRegistrationScreen; there is
// no second registration flow.
// =============================================================================

import 'package:flutter/material.dart';

import 'services/vendor_approval.dart';
import 'vendor_registration_screen.dart';

class VendorStatusScreen extends StatelessWidget {
  const VendorStatusScreen({super.key});

  /// Opens the registration flow the app already has.
  void _openRegistration(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VendorRegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Registration Status'),
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
      ),
      body: ListenableBuilder(
        listenable: VendorApproval.instance,
        builder: (context, _) {
          final approval = VendorApproval.instance;
          final rejected = approval.status == VendorApprovalStatus.rejected;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(rejected),
                const SizedBox(height: 20),
                if (rejected)
                  _rejectedCard(approval.rejectionReason)
                else
                  _underReviewCard(),
                const SizedBox(height: 24),
                _GradientActionButton(
                  label: rejected
                      ? 'Update & Resubmit'
                      : 'Update Registration Details',
                  icon: rejected ? Icons.refresh : Icons.edit_outlined,
                  onPressed: () => _openRegistration(context),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.greyText,
                  ),
                  child: const Text('Back to shopping'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Header banner ---------------------------------------------------------

  Widget _header(bool rejected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: rejected ? null : AppColors.greenGradient,
        color: rejected ? AppColors.error : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              rejected ? Icons.close_rounded : Icons.hourglass_top_rounded,
              color: AppColors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            rejected ? 'Registration Rejected' : 'Registration Under Review',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rejected
                ? 'Please update your details and submit again'
                : 'Distributor prices unlock once you are verified',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --- Under review ----------------------------------------------------------

  Widget _underReviewCard() {
    return _Card(
      children: const [
        _StatusRow(
          done: true,
          label: 'Information submitted',
        ),
        _StatusRow(
          done: true,
          label: 'Documents submitted',
        ),
        _StatusRow(
          done: false,
          label: 'Admin verification pending',
        ),
        SizedBox(height: 14),
        Divider(height: 1, color: AppColors.border),
        SizedBox(height: 14),
        Text(
          'Your registration is being reviewed. You will be able to see '
          'distributor prices and place orders as soon as it is approved.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.greyText,
          ),
        ),
      ],
    );
  }

  // --- Rejected --------------------------------------------------------------

  Widget _rejectedCard(String? reason) {
    return _Card(
      children: [
        const Text(
          'Reason',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 6),
        // Only the backend's own reason is ever shown — nothing is invented
        // here when it doesn't send one.
        Text(
          (reason != null && reason.trim().isNotEmpty)
              ? reason.trim()
              : 'No reason was provided. Please contact support or update your '
                  'details and submit again.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.greyText,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SMALL LOCAL WIDGETS (styled on the shared AppColors palette)
// =============================================================================

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_checked,
            size: 20,
            color: done ? AppColors.primary : AppColors.greyText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: done ? FontWeight.w600 : FontWeight.w700,
                color: done ? AppColors.darkText : AppColors.greyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.greenGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
