// =============================================================================
// MediCaPlus — Delivery Partner · Confirm Delivery
//
// Opened from a task that is Out for Delivery. The agent verifies the items,
// optionally captures proof, then taps "Mark Delivered" which calls the live
// backend (PUT /delivered-prder/:id via DeliveryController.markDelivered). The
// backend has no OTP / proof storage, so those steps are local confirmations
// only — the authoritative action is the delivered status change.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../customer/customer_widgets.dart' show formatRupees;
import '../../vendor_registration_screen.dart' show AppColors;
import '../delivery_models.dart';

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

  bool get _photoTaken => _photoBytes != null;

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
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _complete(task),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
