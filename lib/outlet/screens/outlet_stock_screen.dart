import 'package:flutter/material.dart';
import '../outlet_theme.dart';

// TODO: replace dummy data + toggle logic with OutletStockController (Riverpod)
// once connected to server/ layer. availableOnOutlet toggle should call
// a PATCH endpoint on the stock item.

class OutletStockScreen extends StatefulWidget {
  const OutletStockScreen({super.key});

  @override
  State<OutletStockScreen> createState() => _OutletStockScreenState();
}

class _OutletStockScreenState extends State<OutletStockScreen> {
  int _selectedFilter = 0;
  final _filters = const ['All', 'Available on outlet', 'Low stock', 'Out of stock'];

  // ---- dummy data (to be replaced by controller) ----
  final List<Map<String, dynamic>> _stockItems = [
    {'name': 'Paracetamol 500mg', 'sub': 'Qty: 320 strips · Batch PB2291', 'available': true, 'status': 'ok'},
    {'name': 'Azithromycin 250mg', 'sub': 'Qty: 14 strips · Batch AZ0087', 'available': false, 'status': 'low'},
    {'name': 'ORS Sachet', 'sub': 'Qty: 0 · Reorder from HQ', 'available': false, 'status': 'out'},
    {'name': 'Insulin Pen (Human)', 'sub': 'Qty: 22 units · Cold chain', 'available': true, 'status': 'ok'},
  ];
  // -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutletColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutletHeader(
                title: 'Stock — Ranchi Outlet',
                subtitle: 'District-wise view · Live sync from HQ',
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
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: OutletColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OutletColors.border),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search, size: 18, color: OutletColors.textMuted),
                          SizedBox(width: 8),
                          Text(
                            'Search medicine, brand, batch...',
                            style: TextStyle(fontSize: 12.5, color: OutletColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final active = i == _selectedFilter;
                          return ChoiceChip(
                            label: Text(_filters[i]),
                            selected: active,
                            onSelected: (_) => setState(() => _selectedFilter = i),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : OutletColors.textMid,
                            ),
                            selectedColor: OutletColors.grad2,
                            backgroundColor: OutletColors.white,
                            side: BorderSide(color: active ? Colors.transparent : OutletColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: OutletColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OutletColors.border),
                        boxShadow: OutletColors.cardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: List.generate(_stockItems.length, (i) {
                          final item = _stockItems[i];
                          final isLast = i == _stockItems.length - 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: isLast ? null : const Border(bottom: BorderSide(color: OutletColors.border)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] as String, style: OutletTextStyles.prodName),
                                      const SizedBox(height: 2),
                                      Text(item['sub'] as String, style: OutletTextStyles.prodSub),
                                    ],
                                  ),
                                ),
                                if (item['status'] == 'out')
                                  const OutletBadge(label: 'Out of stock', bg: OutletColors.badgeRedBg, fg: OutletColors.danger)
                                else
                                  Row(
                                    children: [
                                      const Text(
                                        'On outlet',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: OutletColors.textMuted),
                                      ),
                                      const SizedBox(width: 6),
                                      Transform.scale(
                                        scale: 0.75,
                                        child: Switch(
                                          value: item['available'] as bool,
                                          activeColor: OutletColors.success,
                                          onChanged: (val) {
                                            setState(() => _stockItems[i]['available'] = val);
                                            // TODO: call OutletStockController.toggleAvailability(itemId, val)
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Stock summary', style: OutletTextStyles.sectionTitle),
                        Text('Backend view', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: OutletColors.success)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.7,
                      children: const [
                        _SummaryCard(num: '4,120', label: 'Total company stock'),
                        _SummaryCard(num: '1,860', label: 'Headquarter stock'),
                        _SummaryCard(num: '142', label: "This outlet's stock"),
                        _SummaryCard(num: '2,118', label: 'Other districts'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const OutletBottomNav(currentIndex: 1),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String num;
  final String label;

  const _SummaryCard({required this.num, required this.label});

  @override
  Widget build(BuildContext context) {
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(num, style: OutletTextStyles.statNum),
          const SizedBox(height: 2),
          Text(label, style: OutletTextStyles.statLabel),
        ],
      ),
    );
  }
}
