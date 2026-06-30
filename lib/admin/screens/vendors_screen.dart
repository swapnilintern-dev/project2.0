// =============================================================================
// MediCaPlus — Admin · Vendors (tab 1)
//
// Marketplace vendor directory. Status segment tabs (All / Active / Pending /
// Review / Suspended), a search field, and vendor cards. Pending / under-review
// vendors expose Reject + Review actions inline; tapping any card opens the
// full Vendor Review screen. Approve / reject / suspend results flow back here
// and update the list in place.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'vendor_review_screen.dart';

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
  final AdminApi _api = AdminApi();

  // Seeded demo vendors + live pending vendors loaded from the backend.
  final List<Vendor> _vendors = List.of(kVendors);
  int _tab = 0;
  String _query = '';
  bool _loading = false;

  static const _tabs = ['All', 'Active', 'Pending', 'Review', 'Suspended'];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  /// Pulls vendors awaiting approval from the backend and adds them to the top.
  Future<void> _loadPending() async {
    setState(() => _loading = true);
    final pending = await _api.getPendingVendors();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (pending != null) {
        // Drop any previously-loaded backend vendors, then re-add fresh.
        _vendors.removeWhere((v) => v.id.isNotEmpty);
        _vendors.insertAll(0, pending);
      }
    });
  }

  List<Vendor> get _filtered {
    Iterable<Vendor> list = _vendors;
    if (_tab > 0) {
      final status = switch (_tab) {
        1 => VendorStatus.active,
        2 => VendorStatus.pending,
        3 => VendorStatus.review,
        _ => VendorStatus.suspended,
      };
      list = list.where((v) => v.status == status);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((v) =>
          v.name.toLowerCase().contains(q) ||
          v.city.toLowerCase().contains(q));
    }
    return list.toList();
  }

  int get _pendingCount =>
      _vendors.where((v) => v.status == VendorStatus.pending).length;

  Future<void> _openReview(Vendor v) async {
    final result = await adminPush<VendorStatus>(
      context,
      VendorReviewScreen(vendor: v),
    );
    if (result == null || !mounted) return;

    // For a backend-sourced (pending) vendor, persist the decision to the
    // server: approve emails their login credentials; reject marks them
    // rejected and emails them.
    if (v.id.isNotEmpty) {
      if (result == VendorStatus.active) {
        final ok = await _api.approveVendor(v.id);
        if (!mounted) return;
        if (ok) {
          adminSnack(context, '${v.name} approved — credentials emailed');
        } else {
          adminSnack(context, 'Approval failed — try again',
              color: AdminColors.red);
          return; // keep it pending when the server call fails
        }
      } else if (result == VendorStatus.suspended) {
        final ok = await _api.rejectVendor(v.id);
        if (!mounted) return;
        if (ok) {
          adminSnack(context, '${v.name} rejected');
        } else {
          adminSnack(context, 'Reject failed — try again',
              color: AdminColors.red);
          return;
        }
      }
    }
    setState(() => v.status = result);
  }

  /// Inline reject from a vendor card (also persists to the backend).
  Future<void> _reject(Vendor v) async {
    if (v.id.isNotEmpty) {
      final ok = await _api.rejectVendor(v.id);
      if (!mounted) return;
      if (!ok) {
        adminSnack(context, 'Reject failed — try again', color: AdminColors.red);
        return;
      }
      adminSnack(context, '${v.name} rejected');
    }
    setState(() => v.status = VendorStatus.suspended);
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
            AdminScreenHeader(
              title: 'Vendors',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge(
                    label: '$_pendingCount pending',
                    color: AdminColors.orange,
                  ),
                  const SizedBox(width: 6),
                  _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Refresh',
                          onPressed: _loadPending,
                          visualDensity: VisualDensity.compact,
                        ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AdminSearchField(
                hint: 'Search vendors',
                onChanged: (v) => setState(() => _query = v),
                onFilter: () => adminSnack(context, 'Filters'),
              ),
            ),
            AdminSegmentTabs(
              tabs: _tabs,
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const AdminEmpty(label: 'No vendors here')
                  : ListView.builder(
                      physics: adminScroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _VendorCard(
                        vendor: list[i],
                        onOpen: () => _openReview(list[i]),
                        onReject: () => _reject(list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.onOpen,
    required this.onReject,
  });

  final Vendor vendor;
  final VoidCallback onOpen;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final actionable = vendor.status == VendorStatus.pending ||
        vendor.status == VendorStatus.review;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: adminCard(),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.storefront,
                        color: AppColors.darkGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText)),
                        const SizedBox(height: 3),
                        Text(_meta(vendor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.greyText)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                      label: vendor.status.label, color: vendor.status.color),
                ],
              ),
            ),
          ),
          if (actionable) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AdminButton(
                      label: 'Reject',
                      icon: Icons.close,
                      color: AdminColors.red,
                      outlined: true,
                      height: 42,
                      onPressed: onReject,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdminButton(
                      label: 'Review',
                      icon: Icons.fact_check_outlined,
                      height: 42,
                      onPressed: onOpen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _meta(Vendor v) {
    if (v.orders == 0) return '${v.city} · New application';
    return '${v.city} · ${groupInt(v.orders)} orders · ★ ${v.rating.toStringAsFixed(1)}';
  }
}
