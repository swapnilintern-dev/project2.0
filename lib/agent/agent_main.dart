// =============================================================================
// VS Arogya — Area Agent · Dashboard (portal home)
//
// Where a signed-in Area Agent lands. The agent's whole job: see the orders in
// their assigned pincode (filtered by the customer's DELIVERY-address pincode),
// and tap one to view its status + line items. Read-only monitoring — no actions
// on the order. UI-only for now — data comes from AgentOrderMock, scoped to the
// agent's pincode (AgentSession).
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../customer/customer_widgets.dart' show formatRupees;
import '../auth/session.dart' show logout;
import '../services/live_refresh.dart';
import 'agent_api.dart';
import 'agent_session.dart';
import 'agent_mock.dart';
import 'agent_order_detail.dart';
import 'agent_profile_screen.dart';

class AgentMain extends StatefulWidget {
  const AgentMain({super.key});

  @override
  State<AgentMain> createState() => _AgentMainState();
}

class _AgentMainState extends State<AgentMain> with LiveRefreshMixin {
  final _api = AgentApi();

  /// Backs the pull-to-refresh gesture. The feed also auto-syncs via
  /// [LiveRefreshMixin], so orders stay live with no manual refresh.
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  /// Orders currently shown. Loaded live from the backend for a real agent
  /// session; the local demo login uses the mock instead.
  List<AgentOrder> _orders = const [];
  bool _loading = false;
  String? _error;

  /// Poll fast so order updates (from marketing/admin/delivery) surface on the
  /// agent's feed near-instantly, with no manual refresh.
  @override
  Duration get liveRefreshInterval => const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    // First load shows a spinner; then poll silently so the feed stays live
    // (immediate: false avoids a duplicate fetch on open).
    _load();
    startLiveRefresh(immediate: false);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  /// Silent background sync — refetches without flipping [_loading] (which would
  /// swap the whole list for a spinner) and keeps current data on a transient
  /// failure (no error row mid-poll).
  @override
  Future<void> onLiveRefresh() async {
    final session = AgentSession.instance;
    if (!session.isLive) {
      if (!mounted) return;
      setState(() {
        _orders = AgentOrderMock.ordersForPincode(session.pincode);
        _error = null;
      });
      return;
    }
    final (orders, error) =
        await _api.fetchOrders(session.agentId!, token: session.token);
    if (!mounted) return;
    setState(() {
      if (error == null) {
        _orders = orders ?? const [];
        _error = null;
      }
    });
  }

  Future<void> _load() async {
    final session = AgentSession.instance;

    // Demo login (no backend id) — show the mock so the role is fully
    // demonstrable without a live agent account.
    if (!session.isLive) {
      setState(() {
        _orders = AgentOrderMock.ordersForPincode(session.pincode);
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final (orders, error) =
        await _api.fetchOrders(session.agentId!, token: session.token);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (error != null) {
        _error = error;
      } else {
        _orders = orders ?? const [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = AgentSession.instance;
    final pincode = session.pincode;
    final orders = _orders;

    final pending =
        orders.where((o) => o.status == AgentOrderStatus.pending).length;
    // Delivered orders drop off the agent feed (backend excludes them), so a
    // "Delivered" count would always read 0. Show orders in transit instead —
    // Shipped or Out for Delivery — which is what an agent is tracking.
    final inTransit = orders
        .where((o) =>
            o.status == AgentOrderStatus.shipped ||
            o.status == AgentOrderStatus.outForDelivery)
        .length;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _header(context, session.name, pincode),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.receipt_long_outlined,
                      value: '${orders.length}',
                      label: 'Total Orders',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.hourglass_bottom_rounded,
                      value: '$pending',
                      label: 'Pending',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.local_shipping_outlined,
                      value: '$inTransit',
                      label: 'In Transit',
                      color: AppColors.darkGreen,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                pincode.isEmpty ? 'Orders' : 'Orders · $pincode',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorRow(_error!)
            else if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Text('No orders in this pincode right now.',
                    style: TextStyle(color: AppColors.greyText)),
              )
            else
              ...orders.map((o) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _OrderRow(
                      order: o,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AgentOrderDetailScreen(order: o),
                        ),
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _errorRow(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.greyText, size: 36),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.greyText)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String name, String pincode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Area Agent',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (pincode.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('Pincode $pincode',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AgentProfileScreen(),
                ),
              ),
              icon: const Icon(Icons.person_rounded, color: Colors.white),
              tooltip: 'Profile',
            ),
            IconButton(
              onPressed: () => logout(context),
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Logout',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final AgentOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.darkGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.darkText)),
                  const SizedBox(height: 2),
                  Text(
                      '#${order.id} · ${order.itemCount} items · ${order.placedAgo}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.greyText)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatRupees(order.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.darkText)),
                const SizedBox(height: 4),
                _StatusPill(status: order.status),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AgentOrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: status.color)),
    );
  }
}
