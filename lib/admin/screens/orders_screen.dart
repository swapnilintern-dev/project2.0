// =============================================================================
// MediCaPlus — Admin · All Orders (tab 2)
//
// Marketplace-wide order monitor, fully backed by the backend:
//   GET /vsArogya/all-orders            -> the order list (newest first)
//   PUT /vsArogya/confirm-order/:id      Pending          -> Confirm Order
//   PUT /vsArogya/shipped-order/:id      Confirm Order    -> Shipped
//   PUT /vsArogya/outof-delivery/:id     Shipped          -> Out for Delivery
//   PUT /vsArogya/delivered-prder/:id    Out for Delivery -> Delivered
//
// Status segment tabs, search across id / buyer, order cards with a contextual
// "advance status" action, and a tap-through detail sheet (items + address).
// No dummy data — the list is empty until the backend responds.
// =============================================================================

import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../../services/live_refresh.dart';
import '../../marketing/invoice_screen.dart' show StaffInvoiceScreen;
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_models.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with LiveRefreshMixin {
  final AdminApi _api = AdminApi();

  // All orders are fetched live from the backend — no dummy/seed data.
  final List<AdminOrder> _orders = [];
  int _tab = 0;
  String _query = '';
  bool _loading = false;

  static const _tabs = [
    'All',
    'Pending',
    'Confirmed',
    'Shipped',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    // Load on open, then keep the marketplace order monitor live (poll +
    // app-resume) so new orders + status changes surface on their own.
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _loadOrders();

  /// Loads every marketplace order from the backend (GET /all-orders).
  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final all = await _api.getAllOrders();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (all != null) {
        _orders
          ..clear()
          ..addAll(all);
      }
    });
  }

  AdminOrderStatus? _statusForTab(int tab) => switch (tab) {
        1 => AdminOrderStatus.pending,
        2 => AdminOrderStatus.confirmed,
        3 => AdminOrderStatus.shipped,
        4 => AdminOrderStatus.outForDelivery,
        5 => AdminOrderStatus.delivered,
        6 => AdminOrderStatus.cancelled,
        _ => null,
      };

  List<AdminOrder> get _filtered {
    Iterable<AdminOrder> list = _orders;
    final status = _statusForTab(_tab);
    if (status != null) {
      list = list.where((o) => o.status == status);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((o) =>
          o.id.toLowerCase().contains(q) ||
          o.buyer.toLowerCase().contains(q));
    }
    return list.toList();
  }

  /// Advances an order to the next backend status (Confirm → Ship → Out →
  /// Delivered). Optimistically updates the card on success.
  Future<void> _advance(AdminOrder o) async {
    final next = o.status.next;
    if (next == null) return;
    final ok = await _api.advanceOrder(o.id, next);
    if (!mounted) return;
    if (ok) {
      setState(() => o.status = next);
      adminSnack(context, 'Order ${_shortId(o.id)} → ${next.label}');
    } else {
      adminSnack(context, 'Update failed — try again', color: AdminColors.red);
    }
  }

  /// Cancels an order (admin superset access) after confirmation. Allowed only
  /// BEFORE delivery; the backend restores any stock deducted at accept time.
  Future<void> _cancel(AdminOrder o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Order #${_shortId(o.id)} for ${o.buyer} will be cancelled. Any '
          'stock reserved for it will be added back to inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AdminColors.red),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final err = await _api.cancelOrder(o.id);
    if (!mounted) return;
    if (err == null) {
      setState(() => o.status = AdminOrderStatus.cancelled);
      adminSnack(context, 'Order ${_shortId(o.id)} cancelled — stock restored');
    } else {
      adminSnack(context, err, color: AdminColors.red);
    }
  }

  void _openDetail(AdminOrder o) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _OrderDetailSheet(
        order: o,
        onAdvance: o.status.next == null
            ? null
            : () {
                Navigator.of(context).pop();
                _advance(o);
              },
        // Cancellation is hidden once the order is Delivered (or already
        // Cancelled) — never after delivery.
        onCancel: (o.status == AdminOrderStatus.delivered ||
                o.status == AdminOrderStatus.cancelled)
            ? null
            : () {
                Navigator.of(context).pop();
                _cancel(o);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final total = _orders.length;
    final pending =
        _orders.where((o) => o.status == AdminOrderStatus.pending).length;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AdminScreenHeader(
              title: 'All Orders',
              subtitle: '$total total · $pending pending',
              trailing: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AdminSearchField(
                hint: 'Order ID or buyer…',
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
              child: RefreshIndicator(
                onRefresh: _loadOrders,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: AdminEmpty(
                              label: _loading
                                  ? 'Loading orders…'
                                  : 'No orders here',
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _OrderCard(
                          order: list[i],
                          onTap: () => _openDetail(list[i]),
                          onAdvance: () => _advance(list[i]),
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

/// Short, readable order reference from a Mongo _id (last 6 chars, upper-case).
String _shortId(String id) {
  if (id.length <= 6) return id.toUpperCase();
  return id.substring(id.length - 6).toUpperCase();
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = d.toLocal();
  return '${local.day} ${months[local.month - 1]}, '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onAdvance,
  });

  final AdminOrder order;
  final VoidCallback onTap;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final advanceLabel = order.status.advanceLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: adminCard(),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('#${_shortId(order.id)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText)),
                      const Spacer(),
                      StatusBadge(
                          label: order.status.label,
                          color: order.status.color),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 15, color: AppColors.greyText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(order.buyer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText)),
                      ),
                      if (order.placedAt != null)
                        Text(_fmtDate(order.placedAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.greyText)),
                    ],
                  ),
                  const Divider(height: 22, color: AppColors.border),
                  Row(
                    children: [
                      Text('${order.itemCount} items',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.greyText)),
                      if (order.paymentMethod.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: order.paymentMethod,
                          color: AdminColors.blue,
                          dense: true,
                        ),
                      ],
                      const Spacer(),
                      Text(money(order.amount),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (advanceLabel != null) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: AdminButton(
                label: advanceLabel,
                icon: Icons.arrow_forward,
                height: 42,
                onPressed: onAdvance,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({required this.order, this.onAdvance, this.onCancel});

  final AdminOrder order;
  final VoidCallback? onAdvance;

  /// Cancel action (null when the order can no longer be cancelled — i.e.
  /// Delivered / Cancelled).
  final VoidCallback? onCancel;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  final AdminApi _api = AdminApi();

  // Server-confirmed total (GET /single-order/:id). Null while loading or if
  // the call fails — we fall back to the amount already in the list.
  double? _serverAmount;
  bool _verifying = true;

  AdminOrder get order => widget.order;
  VoidCallback? get onAdvance => widget.onAdvance;
  VoidCallback? get onCancel => widget.onCancel;

  /// The invoice exists only once the order has been ACCEPTED — Pending /
  /// Cancelled orders show no invoice action at all.
  bool get _invoiceAvailable => switch (order.status) {
        AdminOrderStatus.confirmed ||
        AdminOrderStatus.shipped ||
        AdminOrderStatus.outForDelivery ||
        AdminOrderStatus.delivered =>
          true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    _verifyTotal();
  }

  Future<void> _verifyTotal() async {
    final amount = await _api.getSingleOrderAmount(order.id);
    if (!mounted) return;
    setState(() {
      _serverAmount = amount;
      _verifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Order #${_shortId(order.id)}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText)),
                ),
                StatusBadge(label: order.status.label, color: order.status.color),
              ],
            ),
            const SizedBox(height: 4),
            if (order.placedAt != null)
              Text('Placed ${_fmtDate(order.placedAt)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.greyText)),
            const SizedBox(height: 16),
            _detailRow(Icons.storefront_outlined, 'Buyer', order.buyer),
            if (order.phone.isNotEmpty)
              _detailRow(Icons.phone_outlined, 'Phone', order.phone),
            if (order.address.isNotEmpty)
              _detailRow(Icons.location_on_outlined, 'Address', order.address),
            if (order.paymentMethod.isNotEmpty)
              _detailRow(Icons.payments_outlined, 'Payment',
                  order.paymentMethod),
            const Divider(height: 26, color: AppColors.border),
            const Text('Items',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            // The list can be long — cap the height and let it scroll.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.32,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: order.lines.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final l = order.lines[i];
                  return Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${l.quantity}×',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGreen)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkText)),
                            if (l.brand.isNotEmpty)
                              Text(l.brand,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.greyText)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(money(l.price * l.quantity),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText)),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 26, color: AppColors.border),
            Row(
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greyText)),
                if (_verifying) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                ] else if (_serverAmount != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_outlined,
                      size: 15, color: AdminColors.green),
                ],
                const Spacer(),
                Text(money(_serverAmount ?? order.amount),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
              ],
            ),
            if (_invoiceAvailable) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StaffInvoiceScreen(
                        orderId: order.id,
                        buyer: order.buyer,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('View Invoice',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (onAdvance != null) ...[
              const SizedBox(height: 12),
              AdminButton(
                label: order.status.advanceLabel ?? 'Advance',
                icon: Icons.arrow_forward,
                onPressed: onAdvance!,
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onCancel!,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel Order',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminColors.red,
                    side: const BorderSide(color: AdminColors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.greyText),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.greyText)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
          ),
        ],
      ),
    );
  }
}
