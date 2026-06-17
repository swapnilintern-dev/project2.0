// =============================================================================
// MediCaPlus — Admin · Add New Product (pushed from Products)
//
// Catalogue entry form: image picker placeholder, product name, MRP / sell
// price, stock qty / min order, category dropdown and description, with
// Save Draft / Publish actions. Pops `true` on publish so the list can react.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_common.dart';
import '../admin_models.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _name = TextEditingController();
  final _mrp = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _minOrder = TextEditingController();
  final _desc = TextEditingController();
  String _category = kProductCategories.first;

  @override
  void dispose() {
    for (final c in [_name, _mrp, _price, _stock, _minOrder, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _publish() {
    if (_name.text.trim().isEmpty || _price.text.trim().isEmpty) {
      adminSnack(context, 'Product name and sell price are required',
          color: AdminColors.red);
      return;
    }
    adminSnack(context, '${_name.text.trim()} published');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Add New Product',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.darkText)),
      ),
      body: ListView(
        physics: adminScroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _photoPicker(),
          const SizedBox(height: 20),
          const _Label('Product Name'),
          _field(_name, 'e.g. Paracetamol 650mg'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('MRP (₹)'),
                    _field(_mrp, '42', number: true, prefix: '₹'),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Sell Price (₹)'),
                    _field(_price, '36', number: true, prefix: '₹'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Stock Qty'),
                    _field(_stock, '500', number: true),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Min Order'),
                    _field(_minOrder, '10', number: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Category'),
          _categoryDropdown(),
          const SizedBox(height: 16),
          const _Label('Description'),
          _field(_desc, 'Composition, usage, storage…', maxLines: 4),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AdminButton(
                  label: 'Save Draft',
                  icon: Icons.save_outlined,
                  outlined: true,
                  onPressed: () {
                    adminSnack(context, 'Draft saved');
                    Navigator.of(context).pop(false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminButton(
                  label: 'Publish',
                  icon: Icons.check_circle_outline,
                  onPressed: _publish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoPicker() {
    return InkWell(
      onTap: () => adminSnack(context, 'Image picker'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_a_photo_outlined,
                color: AppColors.darkGreen, size: 30),
            SizedBox(height: 8),
            Text('Add Photo',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen)),
            SizedBox(height: 2),
            Text('Up to 5 images · PNG, JPG',
                style: TextStyle(fontSize: 11, color: AppColors.greyText)),
          ],
        ),
      ),
    );
  }

  Widget _categoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.greyText),
          borderRadius: BorderRadius.circular(12),
          items: [
            for (final c in kProductCategories)
              DropdownMenuItem(
                value: c,
                child: Text(c,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.darkText)),
              ),
          ],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    bool number = false,
    int maxLines = 1,
    String? prefix,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters:
          number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      style: const TextStyle(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        prefixStyle: const TextStyle(
            color: AppColors.darkText, fontWeight: FontWeight.w700, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText)),
    );
  }
}
