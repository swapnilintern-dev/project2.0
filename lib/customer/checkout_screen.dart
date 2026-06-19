// =============================================================================
// MediCaPlus — Checkout Screen
//
// Address selection (with "Change"), payment-method selection, an order
// summary, and Place Order. On success it creates an Order, records it in the
// OrdersController, clears the cart and routes to the Order Details screen.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import 'customer_api.dart';
import 'customer_controllers.dart';
import 'customer_mock_data.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'order_details_screen.dart';
import 'addresses_screen.dart';

/// Razorpay publishable Key ID. Replace with VS Arogya's real key before going
/// live (test keys start with `rzp_test_`, live keys with `rzp_live_`).
// TODO(razorpay): move this to a secure source and pair it with a backend that
// creates the Razorpay order and verifies the payment signature.
const String _razorpayKeyId = 'rzp_test_XXXXXXXXXXXXXX';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CustomerApi _api = CustomerApi();

  Address _address = AddressController.instance.defaultAddress ??
      MockData.addresses.first;
  PaymentMethod _payment = PaymentMethod.razorpay;
  bool _placing = false;

  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _changeAddress() async {
    final selected = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
          builder: (_) => const AddressesScreen(selectMode: true)),
    );
    if (selected != null) setState(() => _address = selected);
  }

  /// Place Order button. COD records the order immediately; Razorpay opens the
  /// payment gateway and only records the order from the success callback.
  Future<void> _placeOrder() async {
    final cart = CartController.instance;
    if (cart.isEmpty) return;
    setState(() => _placing = true);

    if (_payment == PaymentMethod.razorpay) {
      _openRazorpayGateway(cart.total);
      return; // flow continues in _onPaymentSuccess / _onPaymentError
    }

    // Cash on Delivery — no gateway, fulfil straight away.
    await _finalizeOrder();
  }

  /// Opens the Razorpay checkout sheet for [amount] (in rupees).
  ///
  /// For a fully verifiable flow your backend should create a Razorpay order
  /// and return its `order_id`; pass it below so the payment can be captured
  /// and the signature verified server-side. Without it the sheet still opens
  /// in test mode using the key + amount.
  void _openRazorpayGateway(double amount) {
    final options = <String, dynamic>{
      'key': _razorpayKeyId,
      'amount': (amount * 100).round(), // Razorpay expects paise (integer)
      'currency': 'INR',
      'name': 'VS Arogya',
      'description': 'MediCaPlus order payment',
      'prefill': <String, dynamic>{
        'contact': _address.phone,
      },
      'theme': <String, dynamic>{'color': '#1E8E5A'},
      // TODO(backend): 'order_id': <id from your server-created Razorpay order>,
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showAppSnack(context, 'Could not open Razorpay: $e');
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    // TODO(backend): verify response.signature / paymentId / orderId on your
    // server before fulfilling. We proceed here so the demo flow completes.
    _finalizeOrder();
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _placing = false);
    showAppSnack(context, 'Payment failed or cancelled. Please try again.');
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    showAppSnack(context, 'Opening ${response.walletName ?? 'wallet'}…');
  }

  /// Creates the order, records it, clears the cart and opens Order Details.
  /// Shared by the COD path and the Razorpay success callback.
  Future<void> _finalizeOrder() async {
    final cart = CartController.instance;
    if (cart.isEmpty) {
      if (mounted) setState(() => _placing = false);
      return;
    }

    final order = Order(
      id: 'MCP-${DateTime.now().millisecondsSinceEpoch % 100000}',
      placedAt: DateTime.now(),
      status: OrderStatus.placed,
      items: cart.items.map(OrderItem.fromCartItem).toList(),
      address: _address,
      paymentMethod: _payment,
      subtotal: cart.subtotal,
      deliveryFee: cart.deliveryFee,
      gst: cart.gst,
      discount: cart.discount,
    );

    final placed = await _api.placeOrder(order);
    if (!mounted) return;

    OrdersController.instance.addOrder(placed);
    cart.clear();
    setState(() => _placing = false);

    // Replace checkout + cart with a fresh order-details view.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: placed.id, justPlaced: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: CartController.instance,
        builder: (context, _) {
          final cart = CartController.instance;
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              _sectionTitle('Delivery Address', action: 'Change', onAction: _changeAddress),
              const SizedBox(height: 10),
              _addressCard(),
              const SizedBox(height: 20),
              _sectionTitle('Payment Method'),
              const SizedBox(height: 10),
              for (final m in PaymentMethod.values) _paymentTile(m),
              const SizedBox(height: 20),
              _sectionTitle('Order Summary'),
              const SizedBox(height: 10),
              _summaryCard(cart),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _sectionTitle(String title, {String? action, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(action,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _addressCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_address.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_address.phone,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkGreen)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${_address.fullName}\n${_address.formatted}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(PaymentMethod m) {
    final selected = _payment == m;
    return GestureDetector(
      onTap: () => setState(() => _payment = m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Icon(m.icon, color: AppColors.darkGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(m.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.greyText)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.greyText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(CartController cart) {
    Widget row(String l, String v, {bool bold = false, bool free = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color: bold ? AppColors.darkGreen : AppColors.greyText)),
              Text(v,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: free
                          ? AppColors.primary
                          : bold
                              ? AppColors.darkGreen
                              : AppColors.darkText)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          row('${cart.itemCount} items · ${cart.distinctCount} products',
              formatRupees(cart.subtotal, decimals: true)),
          if (cart.discount > 0)
            row('Discount', '- ${formatRupees(cart.discount, decimals: true)}',
                free: true),
          row('Delivery',
              cart.deliveryFee == 0 ? 'FREE' : formatRupees(cart.deliveryFee),
              free: cart.deliveryFee == 0),
          row('GST (12%)', formatRupees(cart.gst, decimals: true)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.border, height: 1),
          ),
          row('Total Payable', formatRupees(cart.total, decimals: true),
              bold: true),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: CartController.instance,
        builder: (context, _) {
          final cart = CartController.instance;
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: PrimaryButton(
              label: 'Place Order · ${formatRupees(cart.total)}',
              icon: Icons.lock_outline,
              loading: _placing,
              onPressed: cart.isEmpty ? null : _placeOrder,
            ),
          );
        },
      ),
    );
  }
}
