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
import '../widgets/expiry_alert.dart';
import 'batch_manager.dart';
import 'marketing_controllers.dart';
import 'marketing_models.dart';
import 'product_media_editor.dart';

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
  late final TextEditingController _batch;

  late String _category;
  late bool _active;

  /// The selected batch expiry date (mandatory). Null until picked.
  DateTime? _expiry;

  /// Set true once the form is submitted, so the expiry picker can show its
  /// "required" error inline the same way the TextFormFields do.
  bool _submitted = false;

  /// Owns the image + video selection (see [ProductMediaEditor]).
  late final ProductMediaController _media;
  bool _saving = false;
  double _progress = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _media = ProductMediaController(existing: e);
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
    _batch = TextEditingController(text: e?.batchNo ?? '');
    _expiry = e?.expiryDate;
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
      _batch,
    ]) {
      c.dispose();
    }
    _media.dispose();
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
            if (_isEdit && (widget.existing?.isExpiringSoon ?? false)) ...[
              const SizedBox(height: 12),
              const ExpiryAlertBanner(),
            ],
            const SizedBox(height: 16),
            _sectionHeader(Icons.perm_media_outlined, 'Product Media'),
            const SizedBox(height: 8),
            ProductMediaEditor(controller: _media),
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
                          hint: '5 / 12 / 18 / 28',
                          controller: _gst,
                          keyboardType: TextInputType.number,
                          validator: _gstSlab,
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
                      // Stock is entered as the FIRST batch only when creating a
                      // product. On edit, stock is owned by the batch manager
                      // below (sum of all batches), so the raw field is hidden.
                      if (!_isEdit) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            icon: Icons.inventory_2_outlined,
                            hint: 'Initial Stock Qty',
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            validator: _nonNegativeInt,
                          ),
                        ),
                      ],
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
            if (!_isEdit) ...[
              // NEW product → capture its first batch (number + expiry). The
              // backend materialises the initial stock above into this batch.
              _sectionHeader(Icons.event_note_outlined, 'First Batch & Expiry'),
              const SizedBox(height: 8),
              _card(
                child: Column(
                  children: [
                    _field(
                      icon: Icons.tag_outlined,
                      label: 'Batch Number',
                      hint: 'e.g. BCH240701A',
                      controller: _batch,
                      validator: _required,
                    ),
                    _gap(),
                    _expiryPickerField(),
                  ],
                ),
              ),
            ] else ...[
              // EXISTING product → manage unlimited batches. Restocking = "Add
              // New Batch" here, never a new product.
              _sectionHeader(Icons.inventory_2_outlined, 'Inventory Batches'),
              const SizedBox(height: 8),
              BatchManager(productId: widget.existing!.id),
            ],
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

  Future<void> _submit() async {
    // Prevent duplicate submission while an upload is in flight.
    if (_saving) return;
    setState(() => _submitted = true);
    final formOk = _formKey.currentState?.validate() ?? false;
    // Expiry lives outside the Form (it's a picker), so it is checked here.
    // Only required when CREATING (the first batch); on edit, batches — and
    // their expiries — are managed by the BatchManager, not this field.
    if (!formOk || (!_isEdit && _expiry == null)) {
      showAppSnack(context, 'Please fix the highlighted fields',
          success: false);
      return;
    }
    // New stock must not already be expired (the backend enforces this too).
    if (!_isEdit) {
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      if (_expiry!.isBefore(startOfToday)) {
        showAppSnack(context, 'Expiry date cannot be in the past',
            success: false);
        return;
      }
    }
    if (!_media.hasImages) {
      showAppSnack(context, 'Please add at least one product image',
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
      batchNo: _batch.text.trim(),
      expiryDate: _expiry,
      inactiveReason: _active ? null : (existing?.inactiveReason),
      icon: existing?.icon ?? Icons.medication_liquid_outlined,
    );

    final controller = MarketingProductsController.instance;
    setState(() {
      _saving = true;
      _progress = 0;
    });
    void onProgress(double p) {
      if (mounted) setState(() => _progress = p);
    }

    final bool ok;
    if (_isEdit) {
      // Sync the edit: keep/reorder existing images, upload any new ones, and
      // replace / remove / keep the video — all in one request.
      ok = await controller.updateRemote(
        product,
        keptImages: _media.keptImages,
        newImages: _media.newImageFiles,
        video: _media.videoToUpload,
        removeVideo: _media.removeVideo,
        onProgress: onProgress,
      );
    } else {
      ok = await controller.addRemote(
        product,
        images: _media.newImageFiles,
        video: _media.videoToUpload,
        onProgress: onProgress,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showAppSnack(context,
          _isEdit ? '${product.name} updated' : '${product.name} added to inventory');
      Navigator.of(context).pop();
    } else {
      showAppSnack(
        context,
        _isEdit
            ? 'Could not update. Check your connection and try again.'
            : 'Could not add product. Check your connection and try again.',
        success: false,
      );
    }
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

  /// GST must be one of the government slabs the invoice summarises
  /// (5 / 12 / 18 / 28, or 0 for tax-exempt). Any other value would show on
  /// the item line but silently DROP OUT of the invoice's GST slab table and
  /// CGST/SGST totals — so it's blocked here at entry.
  String? _gstSlab(String? v) {
    if (v == null || v.trim().isEmpty) return null; // defaults apply
    final value = double.tryParse(v.trim());
    if (value == null) return 'Invalid';
    const slabs = [0, 5, 12, 18, 28];
    if (value % 1 != 0 || !slabs.contains(value.toInt())) {
      return '0/5/12/18/28';
    }
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

  /// The mandatory expiry-date picker, styled to match the form's text fields.
  /// Shows a red "Required" error once the form has been submitted with no date.
  Widget _expiryPickerField() {
    final hasError = _submitted && _expiry == null;
    final borderColor = hasError ? AppColors.error : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickExpiry,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Expiry Date',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              floatingLabelStyle: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.event_outlined,
                  size: 19, color: AppColors.greyText),
              filled: true,
              fillColor: AppColors.pageBg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
            child: Text(
              _expiry == null ? 'Select expiry date' : _formatDate(_expiry!),
              style: TextStyle(
                fontSize: 14,
                color: _expiry == null
                    ? AppColors.greyText
                    : AppColors.darkText,
              ),
            ),
          ),
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 12),
            child: Text('Required',
                style: TextStyle(color: AppColors.error, fontSize: 11)),
          ),
      ],
    );
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    // Adding new stock cannot expire in the past; when editing historical data
    // allow any date so an existing record can be corrected.
    final first = _isEdit ? DateTime(now.year - 5) : DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year, now.month, now.day),
      firstDate: first,
      lastDate: DateTime(now.year + 15),
      helpText: 'Select expiry date',
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  /// Formats a date as "31 Dec 2027".
  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
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
    final pct = (_progress * 100).clamp(0, 100).round();
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                    value: _progress > 0 && _progress < 1 ? _progress : null))
            : Icon(_isEdit ? Icons.save_outlined : Icons.add),
        label: Text(
            _saving
                ? (_progress > 0 && _progress < 1
                    ? 'Uploading… $pct%'
                    : 'Saving…')
                : (_isEdit ? 'Save Changes' : 'Add to Inventory'),
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
