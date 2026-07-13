import 'package:flutter/material.dart';
import '../outlet_theme.dart';

// TODO: replace dummy timeline + district counts with OutletOrderController
// once wired. orderId should come via route arguments.

class OutletOrderTrackingScreen extends StatelessWidget {
  final String orderId;

  const OutletOrderTrackingScreen({super.key, this.orderId = 'OL-2291'});

  @override
  Widget build(BuildContext context) {
    // ---- dummy data (to be replaced by controller) ----
    final steps = [
      {'title': 'Order placed at outlet', 'time': 'Today, 10:12 AM', 'done': true},
      {'title': 'Stock deducted from outlet', 'time': 'Today, 10:12 AM', 'done': true},
      {'title': 'Payment verified', 'time': 'Today, 10:14 AM', 'done': true},
      {'title': 'Handed to customer', 'time': 'Pending', 'done': false},
    ];
    const ranchiOutletOrders = 8;
    const otherOutletsOrders = 3;
    // -----------------------------------------------------

    return Scaffold(
      backgroundColor: OutletColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutletHeader(
                title: 'Track order #$orderId',
                subtitle: 'Ranchi district · Outlet order',
                leading: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Back', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.more_vert, color: Colors.white),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: OutletColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OutletColors.border),
                        boxShadow: OutletColors.cardShadow,
                      ),
                      child: Column(
                        children: List.generate(steps.length, (i) {
                          final step = steps[i];
                          final isLast = i == steps.length - 1;
                          final done = step['done'] as bool;
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      margin: const EdgeInsets.only(top: 3),
                                      decoration: BoxDecoration(
                                        color: done ? OutletColors.success : OutletColors.border,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          margin: const EdgeInsets.symmetric(vertical: 2),
                                          color: OutletColors.border,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: isLast ? 0 : 26),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step['title'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: done ? OutletColors.textDark : OutletColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(step['time'] as String, style: OutletTextStyles.prodSub),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('District orders today', style: OutletTextStyles.sectionTitle),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _summaryCard('$ranchiOutletOrders', 'Ranchi outlet')),
                        const SizedBox(width: 10),
                        Expanded(child: _summaryCard('$otherOutletsOrders', 'Other outlets, district')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const OutletBottomNav(currentIndex: 2),
    );
  }

  Widget _summaryCard(String num, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OutletColors.border),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num, style: OutletTextStyles.statNum),
          const SizedBox(height: 2),
          Text(label, style: OutletTextStyles.statLabel),
        ],
      ),
    );
  }
}
