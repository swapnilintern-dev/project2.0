import 'package:flutter/material.dart';
import '../outlet_theme.dart';

// TODO: replace dummy data below with OutletDashboardController (Riverpod)
// once controllers/models are wired from the `server` folder.

class OutletDashboardScreen extends StatelessWidget {
  const OutletDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ---- dummy data (to be replaced by controller) ----
    const staffName = 'Ravi';
    const outletName = 'Ranchi Outlet';
    const district = 'Ranchi';
    const stockCount = 142;
    const ordersToday = 8;
    final recentOrders = [
      {'id': 'OL-2291', 'customer': 'Amit Kumar', 'amount': '₹860', 'status': 'Placed'},
      {'id': 'OL-2288', 'customer': 'Sunita Devi', 'amount': '₹1,240', 'status': 'Pending pay'},
      {'id': 'OL-2280', 'customer': 'Walk-in', 'amount': '₹430', 'status': 'Delivered'},
    ];
    // -----------------------------------------------------

    return Scaffold(
      backgroundColor: OutletColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutletHeader(
                title: 'Namaste, $staffName',
                subtitle: '$outletName · District: $district',
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Outlet staff',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                trailing: _iconCircle(Icons.notifications_none_rounded),
              ),
              OutletCardOverlay(
                child: Row(
                  children: [
                    Expanded(child: _statTile('$stockCount', 'Items in outlet stock')),
                    Expanded(child: _statTile('$ordersToday', 'Orders today')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    const Text('Quick actions', style: OutletTextStyles.sectionTitle),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _actionButton(Icons.inventory_2_outlined, 'View stock', () {
                          Navigator.pushNamed(context, '/outlet/stock');
                        }),
                        _actionButton(Icons.receipt_long_outlined, 'New manual order', () {
                          Navigator.pushNamed(context, '/outlet/manual-order');
                        }),
                        _actionButton(Icons.local_shipping_outlined, 'Track orders', () {
                          Navigator.pushNamed(context, '/outlet/order-tracking');
                        }),
                        _actionButton(Icons.location_on_outlined, 'District stock', () {
                          Navigator.pushNamed(context, '/outlet/stock');
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent walk-in orders', style: OutletTextStyles.sectionTitle),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/outlet/order-tracking'),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: const Text(
                            'View all',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: OutletColors.success),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: OutletColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OutletColors.border),
                        boxShadow: OutletColors.cardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: List.generate(recentOrders.length, (i) {
                          final o = recentOrders[i];
                          final isLast = i == recentOrders.length - 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : const Border(bottom: BorderSide(color: OutletColors.border)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Order #${o['id']}', style: OutletTextStyles.prodName),
                                    const SizedBox(height: 2),
                                    Text('${o['customer']} · ${o['amount']}', style: OutletTextStyles.prodSub),
                                  ],
                                ),
                                _statusBadge(o['status']!),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const OutletBottomNav(currentIndex: 0),
    );
  }

  static Widget _iconCircle(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  static Widget _statTile(String num, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(num, style: OutletTextStyles.statNum),
        const SizedBox(height: 2),
        Text(label, style: OutletTextStyles.statLabel),
      ],
    );
  }

  static Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: OutletColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OutletColors.border),
          boxShadow: OutletColors.cardShadow,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: OutletColors.badgeGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: OutletColors.success),
            ),
            const SizedBox(height: 8),
            Text(label, style: OutletTextStyles.prodName, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  static Widget _statusBadge(String status) {
    switch (status) {
      case 'Placed':
        return const OutletBadge(label: 'Placed', bg: OutletColors.badgeGreenBg, fg: OutletColors.success);
      case 'Delivered':
        return const OutletBadge(label: 'Delivered', bg: OutletColors.badgeGreenBg, fg: OutletColors.success);
      case 'Pending pay':
        return const OutletBadge(label: 'Pending pay', bg: OutletColors.badgeAmberBg, fg: OutletColors.amber);
      default:
        return const OutletBadge(label: 'Out of stock', bg: OutletColors.badgeRedBg, fg: OutletColors.danger);
    }
  }
}
