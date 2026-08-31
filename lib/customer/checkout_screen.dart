// =============================================================================
// MediCaPlus — Checkout Screen
//
// Address selection (with "Change"), payment-method selection, an order
// summary, and Place Order. On success it creates an Order, records it in the
// OrdersController, clears the cart and routes to the Order Details screen.
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import 'catalog.dart';
import 'customer_api.dart';
import 'customer_controllers.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'order_details_screen.dart';
import 'addresses_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CustomerApi _api = CustomerApi();

  // The chosen delivery address. Null until the user has one — no fake fallback.
  Address? _address = AddressController.instance.defaultAddress;
  PaymentMethod _payment = PaymentMethod.razorpay;
  bool _placing = false;

  /// The backend order id awaiting online payment. Kept so a failed/cancelled
  /// payment can be retried against the SAME order instead of placing a new one.
  String? _pendingOrderId;

  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    // Load the saved address book from the account, then supplement it with
    // real past-order addresses (OrdersController.refresh feeds
    // AddressController.syncFromOrders). Either arriving fills the default.
    AddressController.instance.hydrate().then((_) {
      if (!mounted) return;
      setState(() => _address ??= AddressController.instance.defaultAddress);
    });
    if (!OrdersController.instance.isLoaded) {
      OrdersController.instance.refresh().then((_) {
        if (!mounted) return;
        setState(() => _address ??= AddressController.instance.defaultAddress);
      });
    }
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

  /// Place Order button. COD records the order immediately; Razorpay places the
  /// order, creates a server-side Razorpay order and opens the gateway — the
  /// order is only marked paid after the server verifies the signature.
  Future<void> _placeOrder() async {
    final cart = CartController.instance;
    // Nothing to place unless there's a cart, OR a pending online order to retry.
    if (cart.isEmpty && _pendingOrderId == null) return;

    // A real delivery address is required — no fake fallback.
    final address = _address;
    if (address == null) {
      showAppSnack(context, 'Add a delivery address to continue',
          success: false);
      _changeAddress();
      return;
    }

    // razorpay_flutter is a MOBILE-ONLY plugin: on Flutter web the gateway never
    // opens and no callback fires, so the button would spin forever. Guide the
    // user to COD / the mobile app instead of hanging.
    if (_payment == PaymentMethod.razorpay && kIsWeb) {
      showAppSnack(context,
          'Online payment opens only in the mobile app. Use Cash on Delivery here, or test on an Android/iOS device.',
          success: false);
      return;
    }

    setState(() => _placing = true);

    // Ids that existed BEFORE this placement — used to recover the new order's
    // id if the place-order response is lost to a timeout/cold start. The
    // recovery only ever picks an order NOT in this set (and placed in the
    // last few minutes), so it can never grab an old order.
    final knownIds =
        OrdersController.instance.orders.map((o) => o.id).toSet();

    // ---- Cash on Delivery: place + finalise straight away. ----
    if (_payment == PaymentMethod.cod) {
      // Make the server cart EXACTLY match the on-screen cart (verified) —
      // the backend builds the order from its cart, so on any mismatch the
      // order is NOT placed (this is what used to double quantities).
      final synced = await cart.pushToServer();
      if (!synced) {
        if (!mounted) return;
        setState(() => _placing = false);
        showAppSnack(
            context,
            'Could not confirm your cart with the server. '
            'Check your connection and try again.',
            success: false);
        return;
      }
      final (backendId, orderError) = await _api.placeOrderFromCart(
        address,
        couponCode: cart.appliedCoupon?.code,
      );
      // The server explicitly rejected the order (out of stock / coupon
      // already used or expired) — tell the user, don't place anything.
      if (orderError != null) {
        if (!mounted) return;
        setState(() => _placing = false);
        showAppSnack(context, orderError, success: false);
        return;
      }
      // Response lost (timeout) but the order may exist server-side — recover
      // its real id so invoice + live tracking work.
      var placedId = backendId;
      placedId ??= await _api.recoverPlacedOrderId(knownIds);
      if (placedId != null) {
        await _api.payForOrder(placedId, method: PaymentMethod.cod);
      }
      await _finalizeLocally(placedId);
      return;
    }

    // ---- Razorpay (online): order-first, then a verifiable payment. ----
    try {
      // Reuse an already-placed order on retry so a failed payment never
      // creates a duplicate order.
      String? orderId = _pendingOrderId;
      if (orderId == null) {
        // Same verified cart sync as the COD path — no order on a mismatch.
        final synced = await cart.pushToServer();
        if (!synced) {
          if (!mounted) return;
          setState(() => _placing = false);
          showAppSnack(
              context,
              'Could not confirm your cart with the server. '
              'Check your connection and try again.',
              success: false);
          return;
        }
        final (newId, orderError) = await _api.placeOrderFromCart(
          address,
          couponCode: cart.appliedCoupon?.code,
        );
        // Explicit server rejection (stock / coupon) — show the real reason.
        if (orderError != null) {
          if (!mounted) return;
          setState(() => _placing = false);
          showAppSnack(context, orderError, success: false);
          return;
        }
        orderId = newId;
        // Lost response? Recover the order the server actually created so a
        // retry never places a DUPLICATE order.
        orderId ??= await _api.recoverPlacedOrderId(knownIds);
      }
      if (!mounted) return;
      if (orderId == null) {
        setState(() => _placing = false);
        showAppSnack(context,
            'Could not reach the server for payment. Check your connection or use Cash on Delivery.',
            success: false);
        return;
      }
      _pendingOrderId = orderId;

      // Ask the backend to create the Razorpay order (amount/signature live here).
      final pay = await _api.createOnlinePayment(orderId);
      if (!mounted) return;
      if (pay == null) {
        setState(() => _placing = false);
        showAppSnack(context,
            'Could not start the payment. Please check your connection and try again.',
            success: false);
        return;
      }
      _openRazorpayGateway(pay);
      // Flow continues in _onPaymentSuccess / _onPaymentError.
    } catch (e) {
      // Bulletproof: never leave the button spinning on an unexpected error.
      if (!mounted) return;
      setState(() => _placing = false);
      showAppSnack(context, 'Something went wrong starting the payment. Try again.',
          success: false);
    }
  }

  /// Opens the Razorpay checkout sheet using the SERVER-created order id + key,
  /// so the payment is captured against a real order and can be verified.
  void _openRazorpayGateway(OnlinePayment pay) {
    // Razorpay wants a bare phone number (no spaces / country-code punctuation).
    final contact = (_address?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final options = <String, dynamic>{
      'key': pay.keyId,
      'order_id': pay.razorpayOrderId, // server-created — enables verification
      'amount': pay.amount, // paise, from the server (matches the order)
      'currency': pay.currency,
      'name': 'VS Arogya',
      'description': 'MediCaPlus order payment',
      if (contact.length >= 10)
        'prefill': <String, dynamic>{
          'contact': contact.substring(contact.length - 10),
        },
      'theme': <String, dynamic>{'color': '#1E8E5A'},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showAppSnack(context, 'Could not open Razorpay: $e', success: false);
    }
  }

  /// Razorpay success → verify the signature server-side. Reaching this callback
  /// means Razorpay CAPTURED the payment, so we never re-open the gateway from
  /// here (that would create a second order = double charge). We always finalise
  /// the order; the server only marks it "paid" when the signature verifies, and
  /// an unverified capture stays a pending order for reconciliation.
  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = _pendingOrderId;
    if (orderId == null || !mounted) return;

    // Payment captured — this order must not be charged again.
    _pendingOrderId = null;

    final verified = await _api.verifyPayment(
      razorpayOrderId: response.orderId ?? '',
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    );
    if (!mounted) return;

    await _finalizeLocally(
      orderId,
      successMessage: verified
          ? 'Payment successful 🎉'
          : 'Payment received — we\'re confirming it. Check your orders shortly.',
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _placing = false);

    // Surface the REAL Razorpay error so failures are diagnosable instead of a
    // generic "try again". Code 2 == user cancelled; anything else is a real
    // gateway/config error worth showing in full.
    final code = response.code;
    final rawMessage = response.message ?? '';
    debugPrint('Razorpay error → code=$code message=$rawMessage');

    if (code == Razorpay.PAYMENT_CANCELLED) {
      // The order stays placed-but-unpaid; tapping Place Order retries the SAME
      // order (see _pendingOrderId) rather than creating a new one.
      showAppSnack(context, 'Payment cancelled. Tap Place Order to retry.',
          success: false);
      return;
    }

    // Razorpay often nests the useful text inside a JSON string — show whatever
    // we can so the exact cause is visible.
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment error'),
        content: Text(
          rawMessage.isEmpty ? 'Error code: $code' : rawMessage,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    showAppSnack(context, 'Opening ${response.walletName ?? 'wallet'}…');
  }

  /// Records the order locally, clears the cart and opens Order Details. Called
  /// once the order is placed (COD) or the online payment is verified.
  Future<void> _finalizeLocally(String? backendId, {String? successMessage}) async {
    final cart = CartController.instance;
    final orderId =
        backendId ?? 'MCP-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final order = Order(
      id: orderId,
      placedAt: DateTime.now(),
      status: OrderStatus.placed,
      items: cart.items.map(OrderItem.fromCartItem).toList(),
      // Non-null here: _placeOrder guards on a chosen address before finalising.
      address: _address!,
      paymentMethod: _payment,
      subtotal: cart.subtotal,
      deliveryFee: cart.deliveryFee,
      gst: cart.gst,
      discount: cart.discount,
    );

    if (!mounted) return;

    OrdersController.instance.addOrder(order);
    Catalog.decrementForOrder(cart.items);
    cart.clear();
    setState(() => _placing = false);
    if (successMessage != null) showAppSnack(context, successMessage);

    // Replace checkout + cart with a fresh order-details view.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: order.id, justPlaced: true),
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
    final address = _address;
    // No address yet → a tappable prompt to add/select one (no fake fallback).
    if (address == null) {
      return InkWell(
        onTap: _changeAddress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: const [
              Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text('Add a delivery address',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.darkText)),
              ),
              Icon(Icons.chevron_right, color: AppColors.greyText),
            ],
          ),
        ),
      );
    }
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
                    Text(address.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (address.phone.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(address.phone,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGreen)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    address.fullName.isEmpty
                        ? address.formatted
                        : '${address.fullName}\n${address.formatted}',
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
          row('GST', 'Included in price'),
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
              onPressed: (cart.isEmpty || _address == null) ? null : _placeOrder,
            ),
          );
        },
      ),
    );
  }
}
