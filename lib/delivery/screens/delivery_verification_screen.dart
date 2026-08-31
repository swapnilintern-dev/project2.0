// =============================================================================
// MediCaPlus — Delivery Partner · Confirm Delivery
//
// Opened from a task that is Out for Delivery. The agent verifies the items,
// optionally captures proof, then taps "Mark Delivered" which calls the live
// backend (PUT /delivered-prder/:id via DeliveryController.markDelivered). The
// backend has no OTP / proof storage, so those steps are local confirmations
// only — the authoritative action is the delivered status change.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../customer/customer_widgets.dart' show formatRupees;
import '../../vendor_registration_screen.dart' show AppColors;
import '../../theme/app_widgets.dart' show shareOriginFor;
import '../delivery_api.dart';
import '../delivery_models.dart';

/// How the agent settled the order's payment before delivering.
///   [none]   — not collected yet ("Mark Delivered" stays disabled).
///   [online] — customer paid online via QR / payment link (agent confirmed).
///   [cash]   — online failed / declined, so the agent collected cash (COD).
enum _DeliveryPayMode { none, online, cash }

class DeliveryVerificationScreen extends StatefulWidget {
  const DeliveryVerificationScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<DeliveryVerificationScreen> createState() =>
      _DeliveryVerificationScreenState();
}

class _DeliveryVerificationScreenState
    extends State<DeliveryVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _photoBytes;
  bool _signatureCaptured = false;
  bool _submitting = false;

  /// Payment must be settled (online OR cash) before the order can be delivered.
  _DeliveryPayMode _pay = _DeliveryPayMode.none;

  bool get _photoTaken => _photoBytes != null;
  bool get _paymentCollected => _pay != _DeliveryPayMode.none;

  // ---------------------------------------------------------------------------
  // PAYMENT COLLECTION (delivery role)
  //
  // The agent collects the order amount before marking it delivered. Online is
  // offered first: the SERVER mints a Razorpay payment link for the order
  // (POST /delivery/payment-link/:id) — the QR shown here is that link, and
  // scanning it opens Razorpay's hosted checkout. "Online paid" is only ever
  // set once the server (asking Razorpay) reports the order as paid — the
  // agent cannot assert it. Cash (COD) remains an agent-confirmed fallback.
  // ---------------------------------------------------------------------------

  final DeliveryApi _api = DeliveryApi();
  Timer? _payPoll;
  bool _sheetOpen = false;
  bool _fetchingLink = false;

  @override
  void dispose() {
    _payPoll?.cancel();
    super.dispose();
  }

  void _setPaid(_DeliveryPayMode mode) {
    _payPoll?.cancel();
    setState(() => _pay = mode);
    _snack(mode == _DeliveryPayMode.cash
        ? 'Cash payment collected'
        : 'Online payment confirmed by the server');
  }

  /// Fetches the order's server-minted payment link. Returns null (after
  /// snacking the reason) when it can't be had; flips straight to paid when
  /// the server says the order is already settled.
  Future<String?> _fetchServerLink(DeliveryTask task) async {
    if (_fetchingLink) return null;
    setState(() => _fetchingLink = true);
    final (link, alreadyPaid, error) = await _api.createDoorstepPaymentLink(
      task.id,
      token: DeliveryController.instance.token,
    );
    if (!mounted) return null;
    setState(() => _fetchingLink = false);
    if (alreadyPaid) {
      _setPaid(_DeliveryPayMode.online);
      return null;
    }
    if (link == null) {
      _snack(error ?? 'Could not create the payment link', error: true);
      return null;
    }
    return link;
  }

  /// Polls the server every 3s while a payment sheet is open; the sheet closes
  /// itself the moment Razorpay confirms the payment.
  void _startPaymentPoll(DeliveryTask task) {
    _payPoll?.cancel();
    _payPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final paid = await _api.doorstepPaymentPaid(
        task.id,
        token: DeliveryController.instance.token,
      );
      if (!mounted || paid != true) return;
      if (_sheetOpen) Navigator.of(context).pop();
      _setPaid(_DeliveryPayMode.online);
    });
  }

  /// The sheet's confirm button: a one-off server check, NOT an assertion.
  Future<void> _confirmOnlinePaid(DeliveryTask task) async {
    final paid = await _api.doorstepPaymentPaid(
      task.id,
      token: DeliveryController.instance.token,
    );
    if (!mounted) return;
    if (paid == true) {
      if (_sheetOpen) Navigator.of(context).pop();
      _setPaid(_DeliveryPayMode.online);
    } else {
      _snack(
        paid == null
            ? 'Could not check the payment — trying again shortly.'
            : 'Payment not received yet — ask the customer to complete it.',
        error: true,
      );
    }
  }

  Future<void> _showPaymentSheet(
    DeliveryTask task, {
    required String title,
    required String subtitle,
    required Widget Function(String link) body,
  }) async {
    final link = await _fetchServerLink(task);
    if (link == null || !mounted) return;
    _sheetOpen = true;
    _startPaymentPoll(task);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaymentSheet(
        title: title,
        subtitle: subtitle,
        amount: task.codAmount,
        child: body(link),
        onConfirm: () => _confirmOnlinePaid(task),
      ),
    );
    _sheetOpen = false;
    // Keep polling briefly after the sheet closes? No — the agent can reopen
    // the sheet (same link is reused server-side) or fall back to cash.
    if (_pay != _DeliveryPayMode.online) _payPoll?.cancel();
  }

  /// Bottom sheet: QR of the server's payment link (scanning opens Razorpay's
  /// hosted checkout). Closes on its own once the server reports paid.
  Future<void> _showQrSheet(DeliveryTask task) => _showPaymentSheet(
        task,
        title: 'Scan to pay',
        subtitle: 'Opens Razorpay checkout — UPI, cards and more',
        body: (link) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: QrImageView(
            data: link,
            version: QrVersions.auto,
            size: 210,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.darkGreen,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.darkText,
            ),
          ),
        ),
      );

  /// Bottom sheet: the same server link, shareable/copyable.
  Future<void> _showLinkSheet(DeliveryTask task) => _showPaymentSheet(
        task,
        title: 'Payment link',
        subtitle: 'Send this to the customer to pay online',
        body: (link) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  _snack('Payment link copied');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.greyText,
                tooltip: 'Copy',
              ),
              IconButton(
                onPressed: () => Share.share(
                  link,
                  subject: 'VS Arogya payment link',
                  sharePositionOrigin: shareOriginFor(context),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                color: AppColors.greyText,
                tooltip: 'Share',
              ),
            ],
          ),
        ),
      );

  /// Cash fallback (COD) — used when the online payment fails or is declined.
  Future<void> _collectCash(DeliveryTask task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Collect cash (COD)'),
        content: Text(
          'Confirm you collected ${formatRupees(task.codAmount)} in cash '
          'from the customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cash collected'),
          ),
        ],
      ),
    );
    if (ok == true) _setPaid(_DeliveryPayMode.cash);
  }

  /// Opens the device camera (Android + iOS + web) and keeps the captured
  /// image as bytes so the thumbnail renders on every platform (no dart:io).
  Future<void> _takePhoto() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (img == null) return; // user cancelled
      final bytes = await img.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
      _snack('Delivery photo captured');
    } catch (_) {
      if (mounted) {
        _snack('Could not open the camera. Check camera permission.',
            error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AppColors.error : AppColors.darkGreen,
        ),
      );
  }

  List<DeliveryTaskItem> _items(DeliveryTask task) => task.items;

  void _toggleItem(DeliveryTask task, int index) {
    final items = List<DeliveryTaskItem>.from(_items(task));
    items[index] = items[index].copyWith(verified: !items[index].verified);
    DeliveryController.instance.updateTaskItems(task.id, items);
  }

  Future<void> _complete(DeliveryTask task) async {
    // Payment must be settled first (online or cash) — locked gate.
    if (!_paymentCollected) {
      _snack('Collect the payment before marking delivered', error: true);
      return;
    }
    final allVerified = _items(task).every((i) => i.verified);
    if (!allVerified) {
      _snack('Verify all items before completing', error: true);
      return;
    }
    setState(() => _submitting = true);
    final error = await DeliveryController.instance.markDelivered(task.id);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      _snack(error, error: true);
      return;
    }
    _snack('Order #${task.id} marked as delivered');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DeliveryController.instance,
      builder: (context, _) {
        final task = DeliveryController.instance.taskById(widget.taskId);
        if (task == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Confirm Delivery')),
            body: const Center(child: Text('Task not found')),
          );
        }

        final items = _items(task);

        return Scaffold(
          backgroundColor: AppColors.pageBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.darkText,
            elevation: 0.5,
            title: const Text(
              'Confirm Delivery',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              _orderCard(task),
              const SizedBox(height: 16),
              _sectionTitle('Verify Items'),
              const SizedBox(height: 10),
              _itemsCard(task, items),
              const SizedBox(height: 16),
              _sectionTitle('Collect Payment'),
              const SizedBox(height: 10),
              _paymentCard(task),
              const SizedBox(height: 16),
              _sectionTitle('Proof of Delivery (optional)'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _photoButton()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _proofButton(
                      icon: Icons.draw_outlined,
                      label: _signatureCaptured
                          ? 'Signature Saved'
                          : 'Capture Signature',
                      done: _signatureCaptured,
                      onTap: () {
                        setState(() => _signatureCaptured = true);
                        _snack('Customer signature captured');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _snack('Calling ${task.customerPhone}'),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call Customer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreen,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _snack('Calling ${task.pharmacyPhone}'),
                      icon:
                          const Icon(Icons.local_pharmacy_outlined, size: 18),
                      label: const Text('Call Buyer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreen,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Mark Delivered" is disabled until payment is settled.
                if (!_paymentCollected)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 15, color: AppColors.greyText),
                        SizedBox(width: 6),
                        Text(
                          'Collect payment to enable delivery',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.greyText),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_submitting || !_paymentCollected)
                        ? null
                        : () => _complete(task),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.greyText.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text(
                            'Mark Delivered',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _orderCard(DeliveryTask task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${task.id}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            task.pharmacyName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${task.itemCount} items · COD ${formatRupees(task.codAmount)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.darkText,
      ),
    );
  }

  /// Payment collection card: amount due, current status, and the three ways to
  /// collect — QR + payment link (online), with Cash (COD) as the fallback.
  Widget _paymentCard(DeliveryTask task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Amount to collect',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greyText),
              ),
              const Spacer(),
              Text(
                formatRupees(task.codAmount),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _paymentStatusRow(),
          const SizedBox(height: 14),
          // Online options.
          Row(
            children: [
              Expanded(
                child: _payOption(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Show QR',
                  selected: _pay == _DeliveryPayMode.online,
                  onTap: () => _showQrSheet(task),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _payOption(
                  icon: Icons.link_rounded,
                  label: 'Payment link',
                  selected: _pay == _DeliveryPayMode.online,
                  onTap: () => _showLinkSheet(task),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Cash fallback (full width so it reads as the alternative path).
          _payOption(
            icon: Icons.payments_outlined,
            label: 'Collect cash (COD)',
            selected: _pay == _DeliveryPayMode.cash,
            onTap: () => _collectCash(task),
            fullWidth: true,
          ),
          if (!_paymentCollected) ...[
            const SizedBox(height: 10),
            const Text(
              'Tip: if the online payment fails, use Collect cash to proceed.',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentStatusRow() {
    final collected = _paymentCollected;
    final label = switch (_pay) {
      _DeliveryPayMode.online => 'Paid online',
      _DeliveryPayMode.cash => 'Cash collected',
      _DeliveryPayMode.none => 'Not collected yet',
    };
    final color = collected ? AppColors.darkGreen : AppColors.greyText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: collected ? AppColors.lightGreenBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: collected ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            collected ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _payOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return Material(
      color: selected ? AppColors.lightGreenBg : AppColors.lighterGreen,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.darkGreen),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.darkGreen : AppColors.greyText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemsCard(DeliveryTask task, List<DeliveryTaskItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            ListTile(
              onTap: () => _toggleItem(task, i),
              leading: Icon(
                items[i].verified
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color:
                    items[i].verified ? AppColors.primary : AppColors.greyText,
              ),
              title: Text(
                items[i].name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                '×${items[i].quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.greyText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The camera capture tile — opens the camera, then shows the captured photo
  /// as a thumbnail (re-tap to retake).
  Widget _photoButton() {
    final done = _photoTaken;
    return Material(
      color: done ? AppColors.lightGreenBg : AppColors.lighterGreen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _takePhoto,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done ? AppColors.primary : AppColors.border,
            ),
          ),
          child: done
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_photoBytes!, fit: BoxFit.cover),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.refresh,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 28, color: AppColors.darkGreen),
                    SizedBox(height: 8),
                    Text('Take Photo',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greyText)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _proofButton({
    required IconData icon,
    required String label,
    required bool done,
    required VoidCallback onTap,
  }) {
    return Material(
      color: done ? AppColors.lightGreenBg : AppColors.lighterGreen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 28,
                  color: done ? AppColors.primary : AppColors.darkGreen),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: done ? AppColors.darkGreen : AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable online-payment bottom sheet (QR or link). Shows the amount, the
/// payment [child] (QR image / link row), and a "Payment received" confirm.
/// Renders identically on Android + iOS (Material sheet, SafeArea-padded).
class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.child,
    required this.onConfirm,
  });

  final String title;
  final String subtitle;
  final double amount;
  final Widget child;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.greyText),
            ),
            const SizedBox(height: 8),
            Text(
              formatRupees(amount),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen),
            ),
            const SizedBox(height: 18),
            child,
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  'Payment received',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close',
                  style: TextStyle(color: AppColors.greyText)),
            ),
          ],
        ),
      ),
    );
  }
}
