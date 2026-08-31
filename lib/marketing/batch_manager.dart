// =============================================================================
// MediCaPlus — Marketing · Batch Manager
//
// Embedded in the Edit Medicine screen. Lists every inventory batch of a
// product (loaded live from the backend), and lets the Marketing Head:
//   • Add a New Batch  (each purchase = a brand-new lot, never a new product)
//   • Edit a batch
//   • Delete a batch
//
// The product's total stock is always the SUM of the batches' available
// quantities — recomputed by the backend on every change and echoed back here.
// Every action hits the backend immediately (BatchApi) and then refreshes the
// shared products list so stock stays in sync everywhere.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_widgets.dart' show showAppSnack;
import '../widgets/expiry_alert.dart';
import 'marketing_api.dart';
import 'marketing_controllers.dart';
import 'marketing_models.dart';

class BatchManager extends StatefulWidget {
  const BatchManager({
    super.key,
    required this.productId,
    this.onTotalStockChanged,
  });

  /// The product whose batches are managed.
  final String productId;

  /// Called with the new total stock (SUM of available quantities) after every
  /// successful change, so the host screen can update any stock display.
  final ValueChanged<int>? onTotalStockChanged;

  @override
  State<BatchManager> createState() => _BatchManagerState();
}

class _BatchManagerState extends State<BatchManager> {
  final BatchApi _api = BatchApi();

  List<ProductBatch> _batches = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false; // an add/edit/delete is in flight

  int get _totalStock =>
      _batches.fold(0, (sum, b) => sum + b.availableQuantity);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (batches, error) = await _api.getBatches(widget.productId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (batches != null) {
        _batches = batches;
        _error = null;
      } else {
        _error = error;
      }
    });
    if (batches != null) widget.onTotalStockChanged?.call(_totalStock);
  }

  /// Runs a mutation ([action] returns null on success or an error message),
  /// then reloads the list and refreshes the shared products list on success.
  Future<void> _mutate(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (error != null) {
      showAppSnack(context, error, success: false);
      return;
    }
    await _load();
    // Keep the inventory list / customer shop stock in sync.
    unawaited(MarketingProductsController.instance.refresh());
  }

  Future<void> _addOrEdit({ProductBatch? existing}) async {
    final result = await showModalBottomSheet<ProductBatch>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BatchFormSheet(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      await _mutate(() => _api.addBatch(widget.productId, result));
    } else {
      await _mutate(() => _api.updateBatch(existing.id, result));
    }
  }

  Future<void> _confirmDelete(ProductBatch b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete batch?'),
        content: Text(
          'Batch "${b.batchNumber}" (${b.availableQuantity} in stock) will be '
          'removed and the product total will drop by that amount.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _mutate(() => _api.deleteBatch(b.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _totalRow(),
          const SizedBox(height: 4),
          const Text(
            'Total stock is the sum of all batches. Each new purchase should be '
            'added as a New Batch — never a new product.',
            style: TextStyle(fontSize: 11.5, color: AppColors.greyText),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (_error != null)
            _errorRow()
          else if (_batches.isEmpty)
            _emptyRow()
          else
            ..._batches.map(_batchTile),
          const SizedBox(height: 12),
          _addButton(),
        ],
      ),
    );
  }

  Widget _totalRow() {
    return Row(
      children: [
        const Icon(Icons.inventory_2_outlined,
            size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text('Total Stock',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText)),
        const Spacer(),
        Text(
          _loading ? '…' : '$_totalStock',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary),
        ),
        const SizedBox(width: 4),
        const Text('units',
            style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
      ],
    );
  }

  Widget _batchTile(ProductBatch b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: b.isExpiringSoon
              ? AppColors.error.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.batchNumber,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (b.isExpiringSoon) ...[
                const ExpiryAlertBadge(),
                const SizedBox(width: 4),
              ],
              _iconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit batch',
                onTap: _busy ? null : () => _addOrEdit(existing: b),
              ),
              _iconButton(
                icon: Icons.delete_outline,
                color: AppColors.error,
                tooltip: 'Delete batch',
                onTap: _busy ? null : () => _confirmDelete(b),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _chip(Icons.inventory_outlined,
                  '${b.availableQuantity} / ${b.purchaseQuantity}'),
              const SizedBox(width: 8),
              if (b.expiryDate != null)
                _chip(Icons.event_outlined, 'Exp ${_monthYear(b.expiryDate!)}',
                    danger: b.isExpiringSoon),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool danger = false}) {
    final color = danger ? AppColors.error : AppColors.greyText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: danger ? AppColors.error : AppColors.darkText)),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color color = AppColors.primary,
    String? tooltip,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 19, color: onTap == null ? AppColors.greyText : color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }

  Widget _emptyRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'No batches yet. Add the first batch to give this product stock.',
        style: TextStyle(fontSize: 12.5, color: AppColors.greyText),
      ),
    );
  }

  Widget _errorRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(_error ?? 'Could not load batches',
                style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _addButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : () => _addOrEdit(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add New Batch',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static String _monthYear(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Add / Edit batch bottom sheet
// ---------------------------------------------------------------------------

class _BatchFormSheet extends StatefulWidget {
  const _BatchFormSheet({this.existing});

  final ProductBatch? existing;

  @override
  State<_BatchFormSheet> createState() => _BatchFormSheetState();
}

class _BatchFormSheetState extends State<_BatchFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _batchNo;
  late final TextEditingController _purchaseQty;
  late final TextEditingController _availableQty;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _supplier;

  DateTime? _mfg;
  DateTime? _expiry;
  bool _submitted = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _batchNo = TextEditingController(text: e?.batchNumber ?? '');
    _purchaseQty =
        TextEditingController(text: e == null ? '' : e.purchaseQuantity.toString());
    _availableQty = TextEditingController(
        text: e == null ? '' : e.availableQuantity.toString());
    _purchasePrice = TextEditingController(
        text: (e == null || e.purchasePrice == 0)
            ? ''
            : e.purchasePrice.toString());
    _sellingPrice = TextEditingController(
        text: (e == null || e.sellingPrice == 0) ? '' : e.sellingPrice.toString());
    _supplier = TextEditingController(text: e?.supplier ?? '');
    _mfg = e?.manufacturingDate;
    _expiry = e?.expiryDate;
  }

  @override
  void dispose() {
    for (final c in [
      _batchNo, _purchaseQty, _availableQty, _purchasePrice, _sellingPrice,
      _supplier,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    if (_expiry == null) {
      showAppSnack(context, 'Please select an expiry date', success: false);
      return;
    }
    if (_mfg != null && _expiry!.isBefore(_mfg!)) {
      showAppSnack(context, 'Expiry cannot be before manufacturing date',
          success: false);
      return;
    }

    final purchase = int.tryParse(_purchaseQty.text.trim()) ?? 0;
    // Available defaults to purchase on a new batch (fresh lot fully in stock).
    final available = _availableQty.text.trim().isEmpty
        ? purchase
        : int.tryParse(_availableQty.text.trim()) ?? 0;
    if (available > purchase) {
      showAppSnack(context, 'Available cannot exceed purchase quantity',
          success: false);
      return;
    }

    Navigator.of(context).pop(
      ProductBatch(
        id: widget.existing?.id ?? '',
        batchNumber: _batchNo.text.trim(),
        purchaseQuantity: purchase,
        availableQuantity: available,
        purchasePrice: double.tryParse(_purchasePrice.text.trim()) ?? 0,
        sellingPrice: double.tryParse(_sellingPrice.text.trim()) ?? 0,
        manufacturingDate: _mfg,
        expiryDate: _expiry,
        supplier: _supplier.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(_isEdit ? 'Edit Batch' : 'Add New Batch',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkText)),
                const SizedBox(height: 14),
                _field(
                  icon: Icons.tag_outlined,
                  label: 'Batch Number',
                  hint: 'e.g. BCH240701A',
                  controller: _batchNo,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Purchase Qty',
                        hint: '0',
                        controller: _purchaseQty,
                        keyboardType: TextInputType.number,
                        validator: _nonNegInt,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        icon: Icons.inventory_2_outlined,
                        label: 'Available Qty',
                        hint: 'defaults to purchase',
                        controller: _availableQty,
                        keyboardType: TextInputType.number,
                        validator: _optionalNonNegInt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _datePicker(
                      label: 'Mfg Date',
                      value: _mfg,
                      onPick: (d) => setState(() => _mfg = d),
                      optional: true,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _datePicker(
                      label: 'Expiry Date',
                      value: _expiry,
                      onPick: (d) => setState(() => _expiry = d),
                      hasError: _submitted && _expiry == null,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        icon: Icons.currency_rupee,
                        label: 'Purchase Price',
                        hint: '0',
                        controller: _purchasePrice,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        icon: Icons.sell_outlined,
                        label: 'Selling Price',
                        hint: '0',
                        controller: _sellingPrice,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  icon: Icons.local_shipping_outlined,
                  label: 'Supplier (optional)',
                  hint: 'Supplier name',
                  controller: _supplier,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: Icon(_isEdit ? Icons.save_outlined : Icons.add),
                    label: Text(_isEdit ? 'Save Batch' : 'Add Batch',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _nonNegInt(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Invalid';
    return null;
  }

  String? _optionalNonNegInt(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Invalid';
    return null;
  }

  Widget _field({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelStyle: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 12.5),
        prefixIcon: Icon(icon, size: 19, color: AppColors.greyText),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
    bool optional = false,
    bool hasError = false,
  }) {
    final borderColor = hasError ? AppColors.error : AppColors.border;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 15),
          helpText: 'Select $label',
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          floatingLabelStyle: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w600),
          prefixIcon:
              const Icon(Icons.event_outlined, size: 18, color: AppColors.greyText),
          filled: true,
          fillColor: Colors.white,
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
          value == null ? (optional ? 'Optional' : 'Select') : _fmt(value),
          style: TextStyle(
            fontSize: 13.5,
            color: value == null ? AppColors.greyText : AppColors.darkText,
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}
