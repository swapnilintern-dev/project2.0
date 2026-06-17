// =============================================================================
// MediCaPlus — Marketing Head · Create Campaign screen
//
// Pushed from the Coupons tab. A validated form: campaign name, type selector
// (Coupon / Banner / Push), banner creative upload placeholder, target audience
// dropdown, start/end date pickers and an estimated-reach readout. Launching a
// Coupon-type campaign creates a live coupon in the Coupons tab. Uses the purple
// marketing accent.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../customer/customer_widgets.dart' show SecondaryButton, showAppSnack;
import 'marketing_controllers.dart';
import 'marketing_models.dart';

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

  static const _audiences = [
    'All Pharmacies · 12.4k',
    'New Buyers · 3.1k',
    'Bulk Buyers · 1.8k',
    'Inactive 30d · 2.5k',
  ];
  String _audience = _audiences.first;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Rough reach estimate: a slice of the selected audience size.
  int get _estimatedReach {
    final match = RegExp(r'([\d.]+)k').firstMatch(_audience);
    final base = match == null ? 0.0 : (double.tryParse(match.group(1)!) ?? 0);
    return (base * 1000 * 0.74).round();
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
            const SizedBox(height: 18),
            _label('Banner Creative'),
            const SizedBox(height: 8),
            _creativeUpload(),
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
            const SizedBox(height: 18),
            _reachCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Save Draft',
                    onPressed: () => _submit(launch: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _submit(launch: true),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Launch'),
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

  void _submit({required bool launch}) {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) {
      showAppSnack(context, 'Please fix the highlighted fields',
          success: false);
      return;
    }
    if (launch && (_startDate == null || _endDate == null)) {
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

    // Launching a Coupon-type campaign creates a live coupon in the list.
    if (_type == CampaignType.coupon) {
      MarketingCouponsController.instance.add(
        MarketingCoupon(
          code: _codeFromName(name),
          description: name,
          redemptions: 0,
        ),
      );
    }
    showAppSnack(context, 'Campaign "$name" launched 🚀');
    Navigator.of(context).pop();
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
    return GestureDetector(
      onTap: () =>
          showAppSnack(context, 'Creative upload coming soon', success: true),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.lighterGreen,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const Text('BANNER CREATIVE · 1080×400',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.greyText)),
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

  Widget _reachCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined,
              color: AppColors.darkGreen),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estimated Reach',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.darkText)),
                SizedBox(height: 2),
                Text('Based on audience & budget',
                    style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
              ],
            ),
          ),
          Text('~${(_estimatedReach / 1000).toStringAsFixed(1)}k',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.darkGreen)),
        ],
      ),
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
