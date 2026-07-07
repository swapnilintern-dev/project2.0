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
                    onTap: () => _previewDoc(context, vendor.docs[i]),
                  ),
                  if (i != vendor.docs.length - 1)
                    const Divider(height: 1, indent: 56, color: AppColors.border),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AdminGroupLabel('Contact Details'),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            decoration: adminCard(),
            child: Column(
              children: [
                AdminInfoRow(
                    label: 'Contact Person', value: _v(vendor.legalName)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'Mobile', value: _v(vendor.mobile)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'Email', value: _v(vendor.email)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AdminGroupLabel('Address'),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            decoration: adminCard(),
            child: Column(
              children: [
                AdminInfoRow(label: 'Address', value: _v(vendor.fullAddress)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'City', value: _v(vendor.city)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'State', value: _v(vendor.state)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'Pincode', value: _v(vendor.pincode)),
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
                AdminInfoRow(
                    label: 'Vendor Type', value: _v(vendor.vendorType)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'Shop Type', value: _v(vendor.shopType)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(
                    label: 'Drug License No.', value: _v(vendor.gstin)),
                const Divider(height: 14, color: AppColors.border),
                AdminInfoRow(label: 'Applied On', value: _v(vendor.appliedOn)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _actionButtons(context),
        ],
      ),
    );
  }

  /// Opens the actual uploaded document (Cloudinary image) full-screen with
  /// pinch-to-zoom. Shows a message when the document has no image URL.
  void _previewDoc(BuildContext context, VendorDoc doc) {
    final url = doc.url;
    if (url == null || url.isEmpty) {
      adminSnack(context, '${doc.name} not available', color: AdminColors.red);
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(doc.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                    errorBuilder: (context, error, stack) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Could not load document',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Approve/Reject buttons shown based on the vendor's current status:
  /// Approved -> only Reject, Rejected -> only Approve, Pending -> both.
  Widget _actionButtons(BuildContext context) {
    final canApprove = vendor.status != VendorStatus.active;
    final canReject = vendor.status != VendorStatus.suspended;
    return Row(
      children: [
        if (canReject)
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
        if (canReject && canApprove) const SizedBox(width: 12),
        if (canApprove)
          Expanded(
            flex: canReject ? 2 : 1,
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
    );
  }

  Widget _avatarFallback() => Container(
        width: 54,
        height: 54,
        color: AppColors.lightGreenBg,
        child: const Icon(Icons.storefront, color: AppColors.darkGreen, size: 26),
      );

  /// Shows a dash for empty values so rows never look blank.
  static String _v(String s) => s.trim().isEmpty ? '—' : s;

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: adminCard(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 54,
              height: 54,
              child: (vendor.storePhotoUrl != null &&
                      vendor.storePhotoUrl!.isNotEmpty)
                  ? Image.network(
                      vendor.storePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatarFallback(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
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
