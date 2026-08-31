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
import '../../services/live_refresh.dart';
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_main.dart';
import '../admin_models.dart';
import 'vendor_review_screen.dart';

/// Where a vendor was registered from — filters the directory by source.
enum _SourceFilter { all, outlet, admin }

/// How recently the vendor applied — surfaces brand-new registrations.
enum _RecencyFilter { all, today, week }

/// List ordering. Newest-first is the default so freshly-registered vendors
/// (from any role/outlet) always appear at the very top.
enum _SortOrder { newest, oldest, nameAZ }

extension _SourceFilterLabel on _SourceFilter {
  String get label => switch (this) {
        _SourceFilter.all => 'All sources',
        _SourceFilter.outlet => 'Registered by Outlet',
        _SourceFilter.admin => 'Registered by Admin',
      };
}

extension _RecencyFilterLabel on _RecencyFilter {
  String get label => switch (this) {
        _RecencyFilter.all => 'Any time',
        _RecencyFilter.today => 'Today',
        _RecencyFilter.week => 'Last 7 days',
      };
}

extension _SortOrderLabel on _SortOrder {
  String get label => switch (this) {
        _SortOrder.newest => 'Newest first',
        _SortOrder.oldest => 'Oldest first',
        _SortOrder.nameAZ => 'Name (A–Z)',
      };
}

/// The active filter/sort selection for the vendor directory.
class _VendorFilters {
  _VendorFilters({
    this.source = _SourceFilter.all,
    this.recency = _RecencyFilter.all,
    this.sort = _SortOrder.newest,
    this.pincode = '',
  });

  _SourceFilter source;
  _RecencyFilter recency;
  _SortOrder sort;
  String pincode;

  _VendorFilters copy() => _VendorFilters(
        source: source,
        recency: recency,
        sort: sort,
        pincode: pincode,
      );

  /// Count of *narrowing* filters in effect (sort order isn't a narrowing
  /// filter, so it's excluded from the badge count).
  int get activeCount {
    var n = 0;
    if (source != _SourceFilter.all) n++;
    if (recency != _RecencyFilter.all) n++;
    if (pincode.trim().isNotEmpty) n++;
    return n;
  }
}

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen>
    with LiveRefreshMixin {
  final AdminApi _api = AdminApi();

  /// Backs the pull-to-refresh gesture. The directory also auto-syncs via
  /// [LiveRefreshMixin], so new/updated vendors surface with no manual refresh.
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  // All vendors are fetched live from the backend — no dummy/seed data.
  final List<Vendor> _vendors = [];
  int _tab = 0;
  String _query = '';
  final _VendorFilters _filters = _VendorFilters();

  static const _tabs = ['All', 'Active', 'Pending', 'Review', 'Suspended'];

  /// Poll faster than the app-wide default so a vendor registering from ANY
  /// role/outlet surfaces here near-instantly (no manual refresh needed).
  @override
  Duration get liveRefreshInterval => const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    // Load on open, then keep the directory live (poll + app-resume).
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _loadVendors();

  /// Loads the full vendor directory from the backend (GET /all-vendors).
  Future<void> _loadVendors() async {
    final all = await _api.getAllVendors();
    if (!mounted || all == null) return;
    setState(() {
      _vendors
        ..clear()
        ..addAll(all);
    });
  }

  List<Vendor> get _filtered {
    Iterable<Vendor> list = _vendors;

    // Status tab.
    if (_tab > 0) {
      final status = switch (_tab) {
        1 => VendorStatus.active,
        2 => VendorStatus.pending,
        3 => VendorStatus.review,
        _ => VendorStatus.suspended,
      };
      list = list.where((v) => v.status == status);
    }

    // Registration source.
    switch (_filters.source) {
      case _SourceFilter.outlet:
        list = list.where((v) => v.isOutletRegistered);
      case _SourceFilter.admin:
        list = list.where((v) => !v.isOutletRegistered);
      case _SourceFilter.all:
        break;
    }

    // Recency (based on the raw registration timestamp).
    if (_filters.recency != _RecencyFilter.all) {
      final now = DateTime.now();
      final cutoff = _filters.recency == _RecencyFilter.today
          ? DateTime(now.year, now.month, now.day)
          : now.subtract(const Duration(days: 7));
      list = list
          .where((v) => v.createdAt != null && v.createdAt!.isAfter(cutoff));
    }

    // Pincode (contains match).
    final pin = _filters.pincode.trim();
    if (pin.isNotEmpty) {
      list = list.where((v) => v.pincode.contains(pin));
    }

    // Free-text search across the fields an admin is likely to type.
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((v) =>
          v.name.toLowerCase().contains(q) ||
          v.legalName.toLowerCase().contains(q) ||
          v.city.toLowerCase().contains(q) ||
          v.state.toLowerCase().contains(q) ||
          v.pincode.contains(q) ||
          v.mobile.contains(q) ||
          v.email.toLowerCase().contains(q));
    }

    final result = list.toList();
    _sortInPlace(result);
    return result;
  }

  /// Orders the list per the active sort. Newest-first is the default so new
  /// registrations always land at the top; vendors without a timestamp (the
  /// seeded demo rows) sort last.
  void _sortInPlace(List<Vendor> list) {
    int byNewest(Vendor a, Vendor b) {
      final da = a.createdAt, db = b.createdAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    }

    switch (_filters.sort) {
      case _SortOrder.newest:
        list.sort(byNewest);
      case _SortOrder.oldest:
        list.sort((a, b) => -byNewest(a, b));
      case _SortOrder.nameAZ:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  int get _pendingCount =>
      _vendors.where((v) => v.status == VendorStatus.pending).length;

  /// Opens the filter sheet and applies whatever the admin picks.
  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_VendorFilters>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VendorFilterSheet(initial: _filters.copy()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters
        ..source = result.source
        ..recency = result.recency
        ..sort = result.sort
        ..pincode = result.pincode;
    });
  }

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
              trailing: StatusBadge(
                label: '$_pendingCount pending',
                color: AdminColors.orange,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AdminSearchField(
                hint: 'Search name, city, pincode, mobile…',
                onChanged: (v) => setState(() => _query = v),
                onFilter: _openFilters,
                filterCount: _filters.activeCount,
              ),
            ),
            AdminSegmentTabs(
              tabs: _tabs,
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                key: _refreshKey,
                onRefresh: _loadVendors,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: const AdminEmpty(label: 'No vendors here'),
                          ),
                        ],
                      )
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
                        if (vendor.isOutletRegistered) ...[
                          const SizedBox(height: 6),
                          const OutletRegisteredBadge(),
                        ],
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

// -----------------------------------------------------------------------------
// FILTER BOTTOM SHEET
//
// Lets the admin narrow the vendor directory by registration source, recency,
// and pincode, and choose the sort order. Returns the chosen [_VendorFilters]
// via Navigator.pop (null when dismissed without applying).
// -----------------------------------------------------------------------------

class _VendorFilterSheet extends StatefulWidget {
  const _VendorFilterSheet({required this.initial});

  final _VendorFilters initial;

  @override
  State<_VendorFilterSheet> createState() => _VendorFilterSheetState();
}

class _VendorFilterSheetState extends State<_VendorFilterSheet> {
  late _VendorFilters _f = widget.initial;
  late final TextEditingController _pinCtrl =
      TextEditingController(text: widget.initial.pincode);

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _f = _VendorFilters();
      _pinCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 10,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              const Text('Filter vendors',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              const Spacer(),
              TextButton(
                onPressed: _reset,
                child: const Text('Reset',
                    style: TextStyle(
                        color: AdminColors.red, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const _FilterGroupLabel('Registration source'),
          _chips<_SourceFilter>(
            values: _SourceFilter.values,
            selected: _f.source,
            labelOf: (v) => v.label,
            onTap: (v) => setState(() => _f.source = v),
          ),
          const SizedBox(height: 16),
          const _FilterGroupLabel('Registered'),
          _chips<_RecencyFilter>(
            values: _RecencyFilter.values,
            selected: _f.recency,
            labelOf: (v) => v.label,
            onTap: (v) => setState(() => _f.recency = v),
          ),
          const SizedBox(height: 16),
          const _FilterGroupLabel('Sort by'),
          _chips<_SortOrder>(
            values: _SortOrder.values,
            selected: _f.sort,
            labelOf: (v) => v.label,
            onTap: (v) => setState(() => _f.sort = v),
          ),
          const SizedBox(height: 16),
          const _FilterGroupLabel('Pincode'),
          const SizedBox(height: 8),
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            onChanged: (v) => _f.pincode = v,
            style: const TextStyle(fontSize: 14, color: AppColors.darkText),
            decoration: InputDecoration(
              hintText: 'e.g. 583101',
              hintStyle:
                  const TextStyle(color: AppColors.greyText, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.pin_drop_outlined, color: AppColors.greyText, size: 20),
              filled: true,
              fillColor: AppColors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 22),
          AdminButton(
            label: 'Apply filters',
            icon: Icons.check_rounded,
            onPressed: () {
              _f.pincode = _pinCtrl.text.trim();
              Navigator.of(context).pop(_f);
            },
          ),
        ],
      ),
    );
  }

  Widget _chips<E>({
    required List<E> values,
    required E selected,
    required String Function(E) labelOf,
    required void Function(E) onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            _SelectableChip(
              label: labelOf(v),
              selected: v == selected,
              onTap: () => onTap(v),
            ),
        ],
      ),
    );
  }
}

class _FilterGroupLabel extends StatelessWidget {
  const _FilterGroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.greyText,
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.darkText,
          ),
        ),
      ),
    );
  }
}
