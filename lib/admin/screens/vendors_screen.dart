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

  // All vendors are fetched live from the backend — no dummy/seed data.
  final List<Vendor> _vendors = [];
  int _tab = 0;
  String _query = '';
  bool _loading = false;

  static const _tabs = ['All', 'Active', 'Pending', 'Review', 'Suspended'];

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  /// Loads the full vendor directory from the backend (GET /all-vendors).
  Future<void> _loadVendors() async {
    setState(() => _loading = true);
    final all = await _api.getAllVendors();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (all != null) {
        _vendors
          ..clear()
          ..addAll(all);
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
    if (result == VendorStatus.active) {
      await _approve(v);
    } else if (result == VendorStatus.suspended) {
      await _reject(v);
    }
  }

  /// Rejects a vendor, then re-syncs the list from the backend so the card
  /// reflects the TRUE server state.
  Future<void> _reject(Vendor v) async {
    await _api.rejectVendor(v.id);
    await _reconcile(
      v.id,
      VendorStatus.suspended,
      okMsg: '${v.name} rejected',
      failMsg: 'Reject failed — try again',
    );
  }

  /// Approves a vendor (backend emails their credentials), then re-syncs.
  Future<void> _approve(Vendor v) async {
    await _api.approveVendor(v.id);
    await _reconcile(
      v.id,
      VendorStatus.active,
      okMsg: '${v.name} approved — credentials emailed',
      failMsg: 'Approval failed — try again',
    );
  }

  /// Re-fetches the vendor directory from the backend and reports whether
  /// vendor [id] reached [expected]. Using the refreshed server list as the
  /// source of truth makes the UI correct even when an endpoint returns a
  /// non-2xx while still having persisted the change (e.g. reject succeeds
  /// server-side but its confirmation email fails). Never leaves stale data.
  Future<void> _reconcile(
    String id,
    VendorStatus expected, {
    required String okMsg,
    required String failMsg,
  }) async {
    await _loadVendors();
    if (!mounted) return;
    Vendor? updated;
    for (final x in _vendors) {
      if (x.id == id) {
        updated = x;
        break;
      }
    }
    if (updated != null && updated.status == expected) {
      adminSnack(context, okMsg);
    } else {
      adminSnack(context, failMsg, color: AdminColors.red);
    }
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
                          onPressed: _loadVendors,
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
                        onApprove: () => _approve(list[i]),
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
    required this.onApprove,
  });

  final Vendor vendor;
  final VoidCallback onOpen;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    // Show Reject unless already suspended; show Approve unless already active.
    final canReject = vendor.status != VendorStatus.suspended;
    final canApprove = vendor.status != VendorStatus.active;
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
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
            child: Row(
              children: [
                if (canReject)
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
                if (canReject && canApprove) const SizedBox(width: 10),
                if (canApprove)
                  Expanded(
                    child: AdminButton(
                      label: 'Approve',
                      icon: Icons.check_circle_outline,
                      height: 42,
                      onPressed: onApprove,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _meta(Vendor v) {
    if (v.orders == 0) return '${v.city} · New application';
    return '${v.city} · ${groupInt(v.orders)} orders · ★ ${v.rating.toStringAsFixed(1)}';
  }
}
