// =============================================================================
// VS Arogya — Outlet Billing (POS) · Step 1 · Customer details
//
// Captures the fields the outlet vendor-registration API needs, so this walk-in
// customer can be filed as a PENDING vendor after the bill (JSON only — NO file
// uploads). Instead of a Store Photo / GST / drug-license document upload, the
// counter now records the GST and Drug License NUMBERS as plain text fields.
// Validation reuses the shared FormValidators (identical rules to the Vendor
// Registration screen). The parent wizard calls [validateAndSave] before
// advancing; it writes the collected values into the shared VendorRegistration
// model held by the BillingController.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/form_validators.dart';
import '../../outlet_theme.dart';
import '../billing_controller.dart';
import '../billing_widgets.dart';

// Option lists (presentation config — mirror the Vendor Registration screen).
const List<String> _vendorTypes = ['Shop / Pharmacy', 'Hospital / Clinic'];
const List<String> _shopTypes = [
  'Retail Pharmacy',
  'Wholesale Pharmacy',
  'Online Pharmacy',
  'Hospital Pharmacy',
  'Ayurvedic / Herbal Store',
  'Medical Equipment',
];
class BillingCustomerStep extends StatefulWidget {
  const BillingCustomerStep({super.key, required this.controller});

  final BillingController controller;

  @override
  State<BillingCustomerStep> createState() => BillingCustomerStepState();
}

class BillingCustomerStepState extends State<BillingCustomerStep> {
  final _formKey = GlobalKey<FormState>();

  final _firmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _dlCtrl = TextEditingController();

  String? _vendorType;
  String? _shopType;
  DateTime? _dlExpiry;
  bool _declaration = false;

  @override
  void dispose() {
    for (final c in [
      _firmCtrl, _nameCtrl, _mobileCtrl, _emailCtrl, _addressCtrl,
      _cityCtrl, _stateCtrl, _pinCtrl, _gstCtrl, _dlCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Validates every field + document; on success writes them into the shared
  /// vendor model and returns true. Shows a message for the first failure.
  bool validateAndSave() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_vendorType == null) return _fail('Select the customer type.');
    if (_shopType == null) return _fail('Select the shop type.');
    if (_dlExpiry == null) return _fail('Select the drug-license expiry date.');
    if (!_declaration) return _fail('Please accept the declaration to continue.');

    widget.controller.customer
      ..storeName = _firmCtrl.text.trim()
      ..contactPerson = _nameCtrl.text.trim()
      ..mobile = _mobileCtrl.text.trim()
      ..email = _emailCtrl.text.trim()
      ..fullAddress = _addressCtrl.text.trim()
      ..city = _cityCtrl.text.trim()
      ..state = _stateCtrl.text.trim()
      ..pinCode = _pinCtrl.text.trim()
      ..vendorType = _vendorType
      ..shopType = _shopType
      // GST is now a required certificate NUMBER (no upload), so this walk-in is
      // always recorded as GST-registered on the backend.
      ..gstStatus = 'Registered (Regular)'
      ..gstNumber = _gstCtrl.text.trim()
      ..drugLicenseNumber = _dlCtrl.text.trim()
      ..drugLicenseExpiry = _dlExpiry
      ..declarationAccepted = _declaration;
    return true;
  }

  bool _fail(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return false;
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dlExpiry ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 25),
    );
    if (picked != null) setState(() => _dlExpiry = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          BillingCard(
            icon: Icons.person_outline_rounded,
            title: 'Customer & Firm',
            child: Column(
              children: [
                BillingField(
                  label: 'Customer Name',
                  controller: _nameCtrl,
                  hint: 'Contact person name',
                  required: true,
                  validator: FormValidators.required('Customer Name'),
                ),
                BillingField(
                  label: 'Firm Name',
                  controller: _firmCtrl,
                  hint: 'Store / clinic name',
                  required: true,
                  validator: FormValidators.required('Firm Name'),
                ),
                BillingDropdown(
                  label: 'Customer Type',
                  value: _vendorType,
                  items: _vendorTypes,
                  hint: 'Select type',
                  required: true,
                  onChanged: (v) => setState(() => _vendorType = v),
                ),
                BillingDropdown(
                  label: 'Shop Type',
                  value: _shopType,
                  items: _shopTypes,
                  hint: 'Select shop type',
                  required: true,
                  onChanged: (v) => setState(() => _shopType = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BillingCard(
            icon: Icons.call_outlined,
            title: 'Contact',
            child: Column(
              children: [
                BillingField(
                  label: 'Mobile Number',
                  controller: _mobileCtrl,
                  hint: '10-digit number',
                  required: true,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: FormValidators.mobile,
                ),
                BillingField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  hint: 'name@email.com',
                  required: true,
                  keyboardType: TextInputType.emailAddress,
                  validator: FormValidators.email,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BillingCard(
            icon: Icons.location_on_outlined,
            title: 'Address',
            child: Column(
              children: [
                BillingField(
                  label: 'Full Address',
                  controller: _addressCtrl,
                  hint: 'Street, area, landmark',
                  required: true,
                  maxLines: 2,
                  validator: FormValidators.required('Full Address'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: BillingField(
                        label: 'City',
                        controller: _cityCtrl,
                        hint: 'City',
                        required: true,
                        validator: FormValidators.required('City'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BillingField(
                        label: 'State',
                        controller: _stateCtrl,
                        hint: 'State',
                        required: true,
                        validator: FormValidators.required('State'),
                      ),
                    ),
                  ],
                ),
                BillingField(
                  label: 'Pincode',
                  controller: _pinCtrl,
                  hint: '6-digit pin code',
                  required: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: FormValidators.pincode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BillingCard(
            icon: Icons.verified_outlined,
            title: 'Licensing',
            child: Column(
              children: [
                // Certificate NUMBERS only — no document/photo uploads.
                BillingField(
                  label: 'GST Certificate Number',
                  controller: _gstCtrl,
                  hint: '15-character GSTIN',
                  required: true,
                  maxLength: 15,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    _UpperCaseFormatter(),
                  ],
                  validator: FormValidators.gstin,
                ),
                BillingField(
                  label: 'Drug License Number',
                  controller: _dlCtrl,
                  hint: 'License number issued by FDA',
                  required: true,
                  validator: FormValidators.required('Drug License Number'),
                ),
                BillingDateField(
                  label: 'Drug License Expiry',
                  value: _dlExpiry,
                  hint: 'Select expiry date',
                  required: true,
                  onTap: _pickExpiry,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _declarationTile(),
        ],
      ),
    );
  }

  Widget _declarationTile() {
    return InkWell(
      onTap: () => setState(() => _declaration = !_declaration),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OutletColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OutletColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _declaration
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: _declaration ? OutletColors.success : OutletColors.textMuted,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'I confirm the customer\'s details are correct and consent to '
                'registering them as a vendor for future orders.',
                style: TextStyle(fontSize: 12.5, color: OutletColors.textMid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Forces GSTIN input to upper-case as the user types.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
