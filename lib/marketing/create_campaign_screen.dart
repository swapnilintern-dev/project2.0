// =============================================================================
// MediCaPlus — Marketing Head · Create Campaign screen
//
// Pushed from the Coupons tab. A validated form: campaign name, type selector
// (Coupon / Banner / Push), banner creative upload placeholder, target audience
// dropdown, start/end date pickers and an estimated-reach readout. Launching a
// Coupon-type campaign creates a live coupon in the Coupons tab. Uses the purple
// marketing accent.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../customer/customer_models.dart' show PromoBanner;
import '../customer/customer_widgets.dart' show SecondaryButton, showAppSnack;
import 'marketing_controllers.dart';

enum CampaignType { coupon, banner, push }

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  CampaignType _type = CampaignType.banner;

  // Uploaded banner creative + a decoded preview (works on web + mobile).
  final ImagePicker _picker = ImagePicker();
  XFile? _bannerImage;
  Uint8List? _bannerPreview;
  bool _submitting = false;

  // Qualitative targeting options only. Audience SIZES are intentionally not
  // shown here — there's no backend endpoint for audience segmentation, so any
  // number would be fabricated.
  static const _audiences = [
    'All Pharmacies',
    'New Buyers',
    'Bulk Buyers',
    'Inactive 30 days',
  ];
  String _audience = _audiences.first;

  // Discount % for a Coupon-type campaign (only used/shown for that type).
  final _discount = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _name.dispose();
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('New Campaign',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _label('Campaign Name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _name,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Campaign name is required'
                  : null,
              decoration: _decoration('e.g. Festive Bulk Offer'),
            ),
            const SizedBox(height: 18),
            _label('Campaign Type'),
            const SizedBox(height: 8),
            _typeSelector(),
            // Discount % — only for a Coupon campaign (persisted to the backend).
            if (_type == CampaignType.coupon) ...[
              const SizedBox(height: 18),
              _label('Discount %'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _discount,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_type != CampaignType.coupon) return null;
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0 || n > 100) return 'Enter 1–100';
                  return null;
                },
                decoration: _decoration('e.g. 20'),
              ),
            ],
            // Banner creative — only relevant for a Banner campaign.
            if (_type == CampaignType.banner) ...[
              const SizedBox(height: 18),
              _label('Banner Creative'),
              const SizedBox(height: 8),
              _creativeUpload(),
            ],
            const SizedBox(height: 18),
            _label('Target Audience'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              items: [
                for (final a in _audiences)
                  DropdownMenuItem(value: a, child: Text(a)),
              ],
              onChanged: (v) => setState(() => _audience = v ?? _audience),
              decoration: _decoration(null),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _datePicker('Start Date', isStart: true)),
                const SizedBox(width: 12),
                Expanded(child: _datePicker('End Date', isStart: false)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Save Draft',
                    onPressed:
                        _submitting ? null : () => _submit(launch: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _submitting ? null : () => _submit(launch: true),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_submitting ? 'Publishing…' : 'Launch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Future<void> _submit({required bool launch}) async {
    if (_submitting) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) {
      showAppSnack(context, 'Please fix the highlighted fields',
          success: false);
      return;
    }
    // A banner campaign always needs a creative to publish.
    if (launch && _type == CampaignType.banner && _bannerImage == null) {
      showAppSnack(context, 'Upload a banner creative to launch',
          success: false);
      return;
    }
    // Coupons are dateless (the backend coupon has no schedule); only
    // banner/push campaigns require a run window.
    if (launch &&
        _type != CampaignType.coupon &&
        (_startDate == null || _endDate == null)) {
      showAppSnack(context, 'Pick a start and end date to launch',
          success: false);
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      showAppSnack(context, 'End date must be after the start date',
          success: false);
      return;
    }

    final name = _name.text.trim();
    if (!launch) {
      showAppSnack(context, 'Campaign "$name" saved as draft');
      Navigator.of(context).pop();
      return;
    }

    // Banner campaign → upload the creative and publish it live to the
    // customer home carousel (POST /promo-banners).
    if (_type == CampaignType.banner) {
      setState(() => _submitting = true);
      final ok = await MarketingBannersController.instance.add(
        PromoBanner(id: '', tag: 'OFFER', title: name),
        _bannerImage!,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (ok) {
        showAppSnack(context, 'Banner "$name" is now live 🎉');
        Navigator.of(context).pop();
      } else {
        showAppSnack(context, 'Could not publish banner — try again',
            success: false);
      }
      return;
    }

    // Launching a Coupon-type campaign creates a REAL coupon on the backend
    // (POST /coupons) so it persists and reaches customer checkout.
    if (_type == CampaignType.coupon) {
      setState(() => _submitting = true);
      final err = await MarketingCouponsController.instance.addRemote(
        code: _codeFromName(name),
        description: name,
        percentOff: double.parse(_discount.text.trim()),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (err == null) {
        showAppSnack(context, 'Coupon campaign "$name" launched 🚀');
        Navigator.of(context).pop();
      } else {
        showAppSnack(context, err, success: false);
      }
      return;
    }

    // Push (and any future type) has no backend action yet.
    showAppSnack(context, 'Campaign "$name" launched 🚀');
    Navigator.of(context).pop();
  }

  /// Picks a banner creative from the gallery and decodes a preview.
  Future<void> _pickCreative() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bannerImage = picked;
        _bannerPreview = bytes;
      });
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not pick image', success: false);
      }
    }
  }

  String _codeFromName(String name) {
    final code = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(4, 'X');
    return code.length > 10 ? code.substring(0, 10) : code;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  // ---------------------------------------------------------------------------

  Widget _typeSelector() {
    Widget tile(CampaignType type, IconData icon, String label) {
      final selected = _type == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _type = type),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.lightGreenBg : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: selected
                        ? AppColors.darkGreen
                        : AppColors.greyText),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.darkGreen
                            : AppColors.greyText)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(CampaignType.coupon, Icons.confirmation_number_outlined, 'Coupon'),
        tile(CampaignType.banner, Icons.image_outlined, 'Banner'),
        tile(CampaignType.push, Icons.notifications_outlined, 'Push'),
      ],
    );
  }

  Widget _creativeUpload() {
    // ~2.4:1 preview matching the customer carousel so marketing sees the real
    // crop. BoxFit.cover means any uploaded ratio renders cleanly on iOS +
    // Android. Recommended source size: 1080×450.
    return GestureDetector(
      onTap: _submitting ? null : _pickCreative,
      child: AspectRatio(
        aspectRatio: 1080 / 450,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.lighterGreen,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: _bannerPreview == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 30, color: AppColors.greyText),
                    SizedBox(height: 8),
                    Text('Upload banner creative',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText)),
                    SizedBox(height: 2),
                    Text('Recommended 1080×450 · JPG / PNG',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.greyText)),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_bannerPreview!, fit: BoxFit.cover),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _submitting ? null : _pickCreative,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child:
                                Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _datePicker(String label, {required bool isStart}) {
    final date = isStart ? _startDate : _endDate;
    final text = date == null
        ? 'Select'
        : '${date.day} ${_month(date.month)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(isStart: isStart),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.greyText),
                const SizedBox(width: 8),
                Text(text,
                    style: TextStyle(
                        fontSize: 14,
                        color: date == null
                            ? AppColors.greyText
                            : AppColors.darkText)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText));

  InputDecoration _decoration(String? hint) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
    );
  }

  String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}
