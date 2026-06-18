// =============================================================================
// MediCaPlus — Marketing Head · Add / Edit Medicine screen
//
// Pushed from the inventory's "Add Medicine" FAB (or "Edit" on a card). A
// sectioned, validated form — Basic Details, Pricing & Stock and Settings —
// that creates a new medicine or updates an existing one (when [existing] is
// passed). Saving routes through MarketingProductsController.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart' show showAppSnack;
import 'marketing_controllers.dart';
import 'marketing_models.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key, this.existing});

  /// When non-null the form edits this medicine instead of creating a new one.
  final InventoryProduct? existing;

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _brand;
  late final TextEditingController _manufacturer;
  late final TextEditingController _marketedBy;
  late final TextEditingController _description;
  late final TextEditingController _mrp;
  late final TextEditingController _packOf;
  late final TextEditingController _hsn;
  late final TextEditingController _gst;
  late final TextEditingController _discount;
  late final TextEditingController _sell;
  late final TextEditingController _stock;
  late final TextEditingController _lowThreshold;

  late String _category;
  late bool _active;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _code = TextEditingController(text: e?.code ?? '');
    _brand = TextEditingController(text: e?.brand ?? '');
    _manufacturer = TextEditingController(text: e?.manufacturer ?? '');
    _marketedBy = TextEditingController(text: e?.marketedBy ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _mrp = TextEditingController(text: e?.mrp?.toString() ?? '');
    _packOf = TextEditingController(text: (e?.packOf ?? 1).toString());
    _hsn = TextEditingController(text: e?.hsnCode ?? '');
    _gst = TextEditingController(text: (e?.gstPercent ?? 5).toString());
    _discount = TextEditingController(text: (e?.discountPercent ?? 0).toString());
    _sell = TextEditingController(text: e?.price.toString() ?? '');
    _stock = TextEditingController(text: e?.stock.toString() ?? '');
    _lowThreshold = TextEditingController(text: (e?.lowThreshold ?? 10).toString());
    // Always start on a category that exists in the (3-item) list, so the
    // dropdown never gets a value with no matching item.
    final existingCategory = e?.category;
    _category =
        (existingCategory != null &&
            kMedicineCategories.contains(existingCategory))
        ? existingCategory
        : kMedicineCategories.first;
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _code, _brand, _manufacturer, _marketedBy, _description,
      _mrp, _packOf, _hsn, _gst, _discount, _sell, _stock, _lowThreshold,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(_isEdit ? 'Edit Medicine' : 'Add Medicine',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _introCard(),
            const SizedBox(height: 16),
            _sectionHeader(Icons.info_outline, 'Basic Details'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  _field(
                    icon: Icons.medication_outlined,
                    hint: 'Medicine Name',
                    controller: _name,
                    validator: _required,
                  ),
                  _gap(),
                  _categoryDropdown(),
                  _gap(),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          icon: Icons.qr_code_2_outlined,
                          hint: 'Product Code',
                          controller: _code,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          icon: Icons.sell_outlined,
                          hint: 'Brand',
                          controller: _brand,
                        ),
                      ),
                    ],
                  ),
                  _gap(),
                  _field(
                    icon: Icons.factory_outlined,
                    hint: 'Manufacturer (optional)',
                    controller: _manufacturer,
                  ),
                  _gap(),
                  _field(
                    icon: Icons.storefront_outlined,
                    hint: 'Marketed By (optional)',
                    controller: _marketedBy,
                  ),
                  _gap(),
                  _field(
                    icon: Icons.notes_outlined,
                    hint: 'Description (optional)',
                    controller: _description,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionHeader(Icons.currency_rupee, 'Pricing & Stock'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          icon: Icons.sell_outlined,
                          hint: 'MRP (₹)',
                          controller: _mrp,
                          keyboardType: TextInputType.number,
                          validator: _price,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          icon: Icons.inventory_outlined,
                          label: 'Pack Of',
                          hint: '1',
                          controller: _packOf,
                          keyboardType: TextInputType.number,
                          validator: _positiveInt,
                        ),
                      ),
                    ],
                  ),
                  _gap(),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          icon: Icons.numbers_outlined,
                          hint: 'HSN Code',
                          controller: _hsn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          icon: Icons.percent_outlined,
                          label: 'GST %',
                          hint: '5',
                          controller: _gst,
                          keyboardType: TextInputType.number,
                          validator: _percent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          icon: Icons.discount_outlined,
                          label: 'Discount %',
                          hint: '0',
                          controller: _discount,
                          keyboardType: TextInputType.number,
                          validator: _percent,
                        ),
                      ),
                    ],
                  ),
                  _gap(),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          icon: Icons.currency_rupee,
                          hint: 'Selling Price (₹)',
                          controller: _sell,
                          keyboardType: TextInputType.number,
                          validator: _sellPrice,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          icon: Icons.inventory_2_outlined,
                          hint: 'Stock Qty',
                          controller: _stock,
                          keyboardType: TextInputType.number,
                          validator: _nonNegativeInt,
                        ),
                      ),
                    ],
                  ),
                  _gap(),
                  _field(
                    icon: Icons.warning_amber_outlined,
                    label: 'Low Stock Alert Threshold',
                    hint: '10',
                    controller: _lowThreshold,
                    keyboardType: TextInputType.number,
                    validator: _nonNegativeInt,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Alert when stock falls below this number',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.greyText)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionHeader(Icons.settings_outlined, 'Settings'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  _toggleRow(
                    icon: Icons.visibility_outlined,
                    title: 'Active (visible to customers)',
                    subtitle: 'Inactive medicines are hidden in shop',
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _submitButton(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Submit + validation
  // ---------------------------------------------------------------------------

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Please fix the highlighted fields',
          success: false);
      return;
    }
    final existing = widget.existing;
    final product = InventoryProduct(
      id: existing?.id ?? 'm${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      code: _code.text.trim().isEmpty
          ? _generateCode(_name.text.trim())
          : _code.text.trim(),
      manufacturer: _manufacturer.text.trim(),
      marketedBy: _marketedBy.text.trim(),
      description: _description.text.trim(),
      price: double.parse(_sell.text.trim()),
      mrp: double.tryParse(_mrp.text.trim()),
      stock: int.parse(_stock.text.trim()),
      active: _active,
      category: _category,
      packOf: int.tryParse(_packOf.text.trim()) ?? 1,
      hsnCode: _hsn.text.trim(),
      gstPercent: double.tryParse(_gst.text.trim()) ?? 0,
      discountPercent: double.tryParse(_discount.text.trim()) ?? 0,
      lowThreshold: int.tryParse(_lowThreshold.text.trim()) ?? 10,
      inactiveReason: _active ? null : (existing?.inactiveReason),
      icon: existing?.icon ?? Icons.medication_liquid_outlined,
    );

    final controller = MarketingProductsController.instance;
    if (_isEdit) {
      controller.update(product);
      showAppSnack(context, '${product.name} updated');
    } else {
      controller.add(product);
      showAppSnack(context, '${product.name} added to inventory');
    }
    Navigator.of(context).pop();
  }

  String _generateCode(String name) {
    final letters = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(3, 'X')
        .substring(0, 3);
    final suffix = (DateTime.now().millisecondsSinceEpoch % 1000)
        .toString()
        .padLeft(3, '0');
    return '$letters-$suffix';
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _price(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final value = double.tryParse(v.trim());
    if (value == null || value <= 0) return 'Invalid';
    return null;
  }

  String? _sellPrice(String? v) {
    final base = _price(v);
    if (base != null) return base;
    final sell = double.parse(v!.trim());
    final mrp = double.tryParse(_mrp.text.trim());
    if (mrp != null && sell > mrp) return 'Above MRP';
    return null;
  }

  String? _positiveInt(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final value = int.tryParse(v.trim());
    if (value == null || value < 1) return 'Min 1';
    return null;
  }

  String? _nonNegativeInt(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final value = int.tryParse(v.trim());
    if (value == null || value < 0) return 'Invalid';
    return null;
  }

  String? _percent(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional, defaults apply
    final value = double.tryParse(v.trim());
    if (value == null || value < 0 || value > 100) return '0–100';
    return null;
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(_isEdit ? Icons.edit : Icons.add, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? 'Edit Medicine' : 'New Medicine',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    _isEdit
                        ? 'Update the details and save your changes.'
                        : 'Fill in the details to add to inventory.',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText)),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );

  Widget _gap() => const SizedBox(height: 12);

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _category,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down),
      items: [
        for (final c in kMedicineCategories)
          DropdownMenuItem(value: c, child: Text(c)),
      ],
      onChanged: (v) => setState(() => _category = v ?? _category),
      decoration: _decoration(
        hint: 'Category',
        label: 'Category',
        prefixIcon: Icons.category_outlined,
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.darkText)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.greyText)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: Icon(_isEdit ? Icons.save_outlined : Icons.add),
        label: Text(_isEdit ? 'Save Changes' : 'Add to Inventory',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _field({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    String? label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.darkText),
      decoration: _decoration(hint: hint, label: label, prefixIcon: icon),
    );
  }

  InputDecoration _decoration({
    required String hint,
    String? label,
    IconData? prefixIcon,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: hint,
      labelText: label,
      floatingLabelStyle:
          const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 19, color: AppColors.greyText),
      filled: true,
      fillColor: AppColors.pageBg,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
    );
  }
}
