import 'package:flutter/material.dart';
import '../outlet_theme.dart';

// TODO: replace dummy item list + submit logic with OutletOrderController
// once wired. On "Create order": POST manual order -> triggers stock
// deduction on backend for this outlet.

class OutletManualOrderScreen extends StatefulWidget {
  const OutletManualOrderScreen({super.key});

  @override
  State<OutletManualOrderScreen> createState() => _OutletManualOrderScreenState();
}

class _OutletManualOrderScreenState extends State<OutletManualOrderScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _paymentMode = 'Cash';

  // ---- dummy data (to be replaced by controller) ----
  final List<Map<String, dynamic>> _cartItems = [
    {'name': 'Paracetamol 500mg', 'sub': '₹28 / strip · Available', 'qty': 2},
    {'name': 'Vitamin C Tablets', 'sub': '₹95 / bottle · Available', 'qty': 1},
  ];
  // -----------------------------------------------------

  int get _totalAmount => 151; // TODO: compute from _cartItems

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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
                title: 'New walk-in order',
                subtitle: 'For customers ordering at outlet counter',
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
                trailing: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Customer name'),
                    _textField(controller: _nameController, hint: 'Enter customer name'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Phone number'),
                              _textField(
                                controller: _phoneController,
                                hint: '10-digit mobile',
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Payment mode'),
                              _dropdown(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const _FieldLabel('Add items from outlet stock'),
                    Container(
                      decoration: BoxDecoration(
                        color: OutletColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OutletColors.border),
                        boxShadow: OutletColors.cardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: List.generate(_cartItems.length, (i) {
                          final item = _cartItems[i];
                          final isLast = i == _cartItems.length - 1;
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
                                OutletBadge(
                                  label: 'Qty ${item['qty']}',
                                  bg: OutletColors.badgeGreenBg,
                                  fg: OutletColors.success,
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // TODO: open stock picker sheet, push into _cartItems
                      },
                      icon: const Icon(Icons.add, size: 16, color: OutletColors.success),
                      label: const Text(
                        'Add another item',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: OutletColors.success),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: OutletColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OutletColors.border),
                        boxShadow: OutletColors.cardShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Order total', style: OutletTextStyles.prodName),
                          Text(
                            '₹$_totalAmount',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: OutletColors.success),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: OutletOrderController.createManualOrder(...)
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OutletColors.grad2,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Create order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: save as draft
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OutletColors.textDark,
                          side: const BorderSide(color: OutletColors.border, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save as draft', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13, color: OutletColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: OutletColors.textMuted),
        filled: true,
        fillColor: OutletColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: OutletColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: OutletColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: OutletColors.success),
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: OutletColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _paymentMode,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: OutletColors.textDark),
          items: const [
            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
            DropdownMenuItem(value: 'QR', child: Text('QR code')),
            DropdownMenuItem(value: 'Link', child: Text('Payment link')),
          ],
          onChanged: (val) => setState(() => _paymentMode = val ?? 'Cash'),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: OutletColors.textMid),
      ),
    );
  }
}
