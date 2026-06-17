// =============================================================================
// MediCaPlus — Admin · Vendor Review (pushed from Vendors)
//
// Full KYC review for one vendor: header with status, the verification document
// checklist (verified vs. needs-review), business details, and sticky
// Reject / Approve actions. Popping returns the chosen VendorStatus so the
// list updates in place.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_models.dart';

class VendorReviewScreen extends StatelessWidget {
  const VendorReviewScreen({super.key, required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Vendor Review',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.darkText)),
      ),
      body: ListView(
        physics: adminScroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _header(),
          const SizedBox(height: 22),
          const AdminGroupLabel('Verification Documents'),
          Container(
            decoration: adminCard(),
            child: Column(
              children: [
                for (int i = 0; i < vendor.docs.length; i++) ...[
                  _DocRow(
                    doc: vendor.docs[i],
                    onTap: () => adminSnack(context, 'Preview ${vendor.docs[i].name}'),
                  ),
                  if (i != vendor.docs.length - 1)
                    const Divider(height: 1, indent: 56, color: AppColors.border),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AdminGroupLabel('Business Details'),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            decoration: adminCard(),
            child: Column(
              children: [
                AdminInfoRow(label: 'Legal Name', value: vendor.legalName),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'GSTIN', value: vendor.gstin),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'City', value: vendor.city),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'Applied On', value: vendor.appliedOn),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AdminButton(
                  label: 'Reject',
                  icon: Icons.close,
                  color: AdminColors.red,
                  outlined: true,
                  onPressed: () {
                    adminSnack(context, '${vendor.name} rejected',
                        color: AdminColors.red);
                    Navigator.of(context).pop(VendorStatus.suspended);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AdminButton(
                  label: 'Approve Vendor',
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    adminSnack(context, '${vendor.name} approved');
                    Navigator.of(context).pop(VendorStatus.active);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: adminCard(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storefront, color: AppColors.darkGreen, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendor.name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
                const SizedBox(height: 3),
                Text('Applied ${vendor.appliedOn} · ${vendor.city}',
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
                const SizedBox(height: 8),
                StatusBadge(
                  label: vendor.status == VendorStatus.active
                      ? 'Approved'
                      : '${vendor.status.label} Approval',
                  color: vendor.status.color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});
  final VendorDoc doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verified = doc.verified;
    final color = verified ? AdminColors.green : AdminColors.orange;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.description_outlined,
                  size: 17, color: AppColors.darkGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.name,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText)),
                  const SizedBox(height: 1),
                  const Text('Tap to preview',
                      style: TextStyle(fontSize: 11, color: AppColors.greyText)),
                ],
              ),
            ),
            StatusBadge(
              label: verified ? 'Verified' : 'Review',
              color: color,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
