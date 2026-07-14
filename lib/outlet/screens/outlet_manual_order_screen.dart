// =============================================================================
// VS Arogya — Outlet Staff · Create Manual Order
//
// Staff reviews the cart, captures the walk-in customer, picks fulfilment and
// payment, then creates the order. Locked rules honoured here:
//   #2 COUNTER vs DELIVERY — the address form appears ONLY for DELIVERY.
//   #3 QR / payment link only — no cash, no COD anywhere.
//   idempotency — the request carries OutletCart.idempotencyKey (generated once
//   per cart); the submit button is also disabled while in flight, so a
//   double-tap can never create two orders.
//
// On success the order is created in AWAITING_PAYMENT and (Step 7) the Payment
// screen opens. For now it confirms creation and returns to the shell.
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_cart.dart';
import '../outlet_enums.dart';
import '../outlet_models.dart';
import '../outlet_repository.dart';
import '../outlet_theme.dart';
import 'outlet_payment_screen.dart';

class OutletManualOrderScreen extends StatefulWidget {
  const OutletManualOrderScreen({super.key});

  @override
  State<OutletManualOrderScreen> createState() =>
      _OutletManualOrderScreenState();
}

class _OutletManualOrderScreenState extends State<OutletManualOrderScreen> {
  final _repo = OutletRepository();
  final _cart = OutletCart.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  OutletOrderType _type = OutletOrderType.counter;
  OutletPaymentMethod _payment = OutletPaymentMethod.qr;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against double-tap
    if (_cart.isEmpty) {
      _toast('Add at least one item to the cart.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Snapshot everything BEFORE the await so clearing the cart afterwards
    // can't affect the request that's already been built.
    final request = CreateOrderRequest(
      type: _type,
      paymentMethod: _payment,
      lines: _cart.lines,
      customer: OutletCustomerInfo(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _type.needsAddress ? _addressCtrl.text.trim() : null,
      ),
      idempotencyKey: _cart.idempotencyKey,
    );

    setState(() => _submitting = true);
    try {
      final order = await _repo.createOrder(request);
      if (!mounted) return;
      _cart.clear();
      // Order is AWAITING_PAYMENT → go collect payment (QR / link / on-device
      // Razorpay) with live server polling. Replaces this screen so Back from
      // payment returns to the shell, not to a stale order form.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OutletPaymentScreen(order: order)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Could not create the order. Please try again.');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutletColors.bg,
      appBar: AppBar(
        backgroundColor: OutletColors.grad1,
        foregroundColor: Colors.white,
        title: const Text('New manual order'),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _cart,
        builder: (context, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _sectionTitle('Cart', '${_cart.itemCount} item(s)'),
                const SizedBox(height: 8),
                if (_cart.isEmpty) _emptyCart() else _cartCard(),
                const SizedBox(height: 10),
                _addProductButton(),
                const SizedBox(height: 18),
                _sectionTitle('Customer', ''),
                const SizedBox(height: 8),
                _customerCard(),
                const SizedBox(height: 18),
                _sectionTitle('Fulfilment', ''),
                const SizedBox(height: 8),
                _fulfilmentCard(),
                const SizedBox(height: 18),
                _sectionTitle('Payment', 'QR / link only'),
                const SizedBox(height: 8),
                _paymentCard(),
                const SizedBox(height: 22),
                _submitButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Sections --------------------------------------------------------------

  Widget _sectionTitle(String title, String trailing) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: OutletTextStyles.sectionTitle),
          if (trailing.isNotEmpty)
            Text(trailing, style: OutletTextStyles.prodSub),
        ],
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OutletColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: OutletColors.cardShadow,
        ),
        child: child,
      );

  Widget _emptyCart() => _card(
        child: Row(
          children: const [
            Icon(Icons.remove_shopping_cart_outlined,
                color: OutletColors.textMuted),
            SizedBox(width: 10),
            Expanded(
              child: Text('Cart is empty. Add products below or from the '
                  'Stock tab.', style: OutletTextStyles.prodSub),
            ),
          ],
        ),
      );

  /// Full-width "Add product" button that opens the searchable own-outlet
  /// product picker — matches the marketing manual-order flow so staff can add
  /// items without leaving this screen.
  Widget _addProductButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addProduct,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add product',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: OutletColors.grad1,
          side: const BorderSide(color: OutletColors.grad2),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<OutletStockItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OutletColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _OutletProductPickerSheet(),
    );
    if (picked != null && mounted) _cart.add(picked);
  }

  Widget _cartCard() {
    return _card(
      child: Column(
        children: [
          for (final line in _cart.lines) ...[
            _cartLineRow(line),
            if (line != _cart.lines.last)
              const Divider(height: 18, color: OutletColors.border),
          ],
          const Divider(height: 22, color: OutletColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: OutletTextStyles.prodName),
              Text('₹${_cart.total.toStringAsFixed(2)}',
                  style: OutletTextStyles.statNum),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cartLineRow(OutletCartLine line) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: OutletTextStyles.prodName),
              const SizedBox(height: 2),
              Text('₹${line.price.toStringAsFixed(0)} · ₹${line.lineTotal.toStringAsFixed(0)}',
                  style: OutletTextStyles.prodSub),
            ],
          ),
        ),
        _stepper(line),
        IconButton(
          onPressed: () => _cart.remove(line.productId),
          icon: const Icon(Icons.delete_outline, size: 20),
          color: OutletColors.danger,
          tooltip: 'Remove',
        ),
      ],
    );
  }

  Widget _stepper(OutletCartLine line) {
    Widget btn(IconData icon, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: OutletColors.badgeGreenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: OutletColors.grad1),
          ),
        );
    return Row(
      children: [
        btn(Icons.remove, () => _cart.decrement(line.productId)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${line.qty}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        btn(Icons.add, () => _cart.increment(line.productId)),
      ],
    );
  }

  Widget _customerCard() {
    return _card(
      child: Column(
        children: [
          _field(
            controller: _nameCtrl,
            label: 'Customer name',
            icon: Icons.person_outline,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _phoneCtrl,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Phone is required';
              if (t.length < 10) return 'Enter a valid phone number';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _fulfilmentCard() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _typeSeg(OutletOrderType.counter, Icons.storefront_rounded),
              const SizedBox(width: 10),
              _typeSeg(OutletOrderType.delivery, Icons.local_shipping_outlined),
            ],
          ),
          // Address ONLY for delivery (locked rule #2).
          if (_type.needsAddress) ...[
            const SizedBox(height: 14),
            _field(
              controller: _addressCtrl,
              label: 'Delivery address',
              icon: Icons.location_on_outlined,
              maxLines: 2,
              validator: (v) {
                if (!_type.needsAddress) return null;
                return (v == null || v.trim().isEmpty)
                    ? 'Address is required for delivery'
                    : null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeSeg(OutletOrderType type, IconData icon) {
    final active = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active ? OutletColors.headerGradient : null,
            color: active ? null : OutletColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: active ? null : Border.all(color: OutletColors.border),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20, color: active ? Colors.white : OutletColors.textMid),
              const SizedBox(height: 4),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : OutletColors.textMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentCard() {
    return _card(
      child: Column(
        children: [
          _payOption(OutletPaymentMethod.qr, Icons.qr_code_2_rounded,
              'Show a Razorpay QR at the counter'),
          const Divider(height: 18, color: OutletColors.border),
          _payOption(OutletPaymentMethod.paymentLink, Icons.link_rounded,
              'Send a Razorpay payment link'),
        ],
      ),
    );
  }

  Widget _payOption(OutletPaymentMethod method, IconData icon, String sub) {
    final active = _payment == method;
    return InkWell(
      onTap: () => setState(() => _payment = method),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon,
                color: active ? OutletColors.success : OutletColors.textMid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label, style: OutletTextStyles.prodName),
                  const SizedBox(height: 2),
                  Text(sub, style: OutletTextStyles.prodSub),
                ],
              ),
            ),
            Icon(
              active
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: active ? OutletColors.success : OutletColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _submitButton() {
    final enabled = !_cart.isEmpty && !_submitting;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _submit : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: OutletColors.headerGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Create order · ₹${_cart.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: OutletColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: OutletColors.textMid, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: OutletColors.textMuted),
        filled: true,
        fillColor: OutletColors.bg,
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OutletColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OutletColors.success),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OutletColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OutletColors.danger),
        ),
      ),
    );
  }
}

// =============================================================================
// Product picker sheet — searchable OWN-outlet stock (district stock is never
// listed here; locked rule #1). Out-of-stock rows aren't selectable. Pops with
// the chosen item, which the caller adds to the cart.
// =============================================================================

class _OutletProductPickerSheet extends StatefulWidget {
  const _OutletProductPickerSheet();

  @override
  State<_OutletProductPickerSheet> createState() =>
      _OutletProductPickerSheetState();
}

class _OutletProductPickerSheetState extends State<_OutletProductPickerSheet> {
  final _repo = OutletRepository();
  late final Future<List<OutletStockItem>> _future = _repo.fetchStock();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                color: OutletColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Add product',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search medicine…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: OutletColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<OutletStockItem>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: OutletColors.success));
                  }
                  final q = _query.trim().toLowerCase();
                  // Own-outlet stock only (rule #1); newest search applied.
                  final list = (snap.data ?? const [])
                      .where((s) => s.isOwnOutlet)
                      .where((s) =>
                          q.isEmpty || s.name.toLowerCase().contains(q))
                      .toList();
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No matching products',
                          style: OutletTextStyles.prodSub),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: OutletColors.border),
                    itemBuilder: (context, i) => _row(list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(OutletStockItem s) {
    final inCart = OutletCart.instance.quantityOf(s.id);
    final selectable = s.inStock;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: selectable,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: OutletColors.badgeGreenBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.medication_outlined,
            color: OutletColors.grad1, size: 20),
      ),
      title: Text(s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selectable ? OutletColors.textDark : OutletColors.textMuted)),
      subtitle: Text(
        [
          if (s.packSize.isNotEmpty) s.packSize,
          '₹${s.price.toStringAsFixed(0)}',
          s.inStock ? '${s.qtyAvailable} in stock' : 'Out of stock',
        ].join(' · '),
        style: OutletTextStyles.prodSub,
      ),
      trailing: inCart > 0
          ? Text('$inCart in cart',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OutletColors.success))
          : (selectable
              ? const Icon(Icons.add_circle_outline, color: OutletColors.grad1)
              : null),
      onTap: selectable ? () => Navigator.of(context).pop(s) : null,
    );
  }
}
