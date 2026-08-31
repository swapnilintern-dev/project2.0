// =============================================================================
// MediCaPlus — Addresses Screen
//
// Lists saved addresses with set-default / edit / delete actions and an
// "Add Address" form (bottom sheet). When opened with selectMode = true it acts
// as a picker for checkout and pops the chosen Address back to the caller.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import 'customer_controllers.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.selectMode = false});

  /// When true, tapping a card returns it to the previous route.
  final bool selectMode;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    // The saved address book lives on the user's backend account — load it.
    AddressController.instance.hydrate();
    // Past-order addresses supplement the saved list (via syncFromOrders), so
    // make sure orders are loaded too.
    if (!OrdersController.instance.isLoaded) {
      OrdersController.instance.refresh();
    }
  }

  Future<void> _openForm(BuildContext context, {Address? existing}) async {
    final result = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressForm(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      AddressController.instance.add(result);
    } else {
      AddressController.instance.update(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectMode = widget.selectMode;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: Text(selectMode ? 'Select Address' : 'My Addresses',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: AddressController.instance,
        builder: (context, _) {
          final addresses = AddressController.instance.addresses;
          if (addresses.isEmpty) {
            return EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No saved addresses',
              message: 'Add a delivery address to get started.',
              actionLabel: 'Add Address',
              onAction: () => _openForm(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              for (final a in addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AddressCard(
                    address: a,
                    selectMode: selectMode,
                    onTap: selectMode
                        ? () => Navigator.of(context).pop(a)
                        : null,
                    onEdit: () => _openForm(context, existing: a),
                    onDelete: () =>
                        AddressController.instance.remove(a.id),
                    onSetDefault: () =>
                        AddressController.instance.setDefault(a.id),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Address',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selectMode,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    this.onTap,
  });

  final Address address;
  final bool selectMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: address.isDefault ? AppColors.primary : AppColors.border,
            width: address.isDefault ? 1.5 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  address.label == 'Work'
                      ? Icons.work_outline
                      : Icons.home_outlined,
                  size: 18,
                  color: AppColors.darkGreen,
                ),
                const SizedBox(width: 8),
                Text(address.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('DEFAULT',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkGreen)),
                  ),
                const Spacer(),
                if (selectMode)
                  const Icon(Icons.chevron_right, color: AppColors.greyText),
              ],
            ),
            const SizedBox(height: 8),
            Text(address.fullName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(address.phone,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.greyText)),
            Text(address.formatted,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.greyText, height: 1.4)),
            if (!selectMode) ...[
              const Divider(height: 22, color: AppColors.border),
              Row(
                children: [
                  if (!address.isDefault)
                    TextButton.icon(
                      onPressed: onSetDefault,
                      icon: const Icon(Icons.star_outline, size: 16),
                      label: const Text('Set default'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.darkGreen,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({this.existing});

  final Address? existing;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pin;
  late String _label;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.fullName ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _line1 = TextEditingController(text: e?.line1 ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _state = TextEditingController(text: e?.state ?? '');
    _pin = TextEditingController(text: e?.pincode ?? '');
    _label = e?.label ?? 'Home';
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _city.dispose();
    _state.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final e = widget.existing;
    final address = Address(
      id: e?.id ?? 'a${DateTime.now().millisecondsSinceEpoch}',
      label: _label,
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pin.text.trim(),
      isDefault: _isDefault,
    );
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.existing == null ? 'Add Address' : 'Edit Address',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final l in ['Home', 'Work', 'Other'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(l),
                          selected: _label == l,
                          onSelected: (_) => setState(() => _label = l),
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.pageBg,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _label == l
                                ? Colors.white
                                : AppColors.darkText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_name, 'Full name', validator: _required),
                _field(_phone, 'Phone number',
                    keyboard: TextInputType.phone, validator: _required),
                _field(_line1, 'Address (house, street, area)',
                    validator: _required),
                Row(
                  children: [
                    Expanded(
                        child: _field(_city, 'City', validator: _required)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(_state, 'State', validator: _required)),
                  ],
                ),
                _field(_pin, 'Pincode',
                    keyboard: TextInputType.number, validator: _pincode),
                CheckboxListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primary,
                  title: const Text('Set as default address',
                      style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 8),
                PrimaryButton(label: 'Save Address', onPressed: _save),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _pincode(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.trim().length != 6) return 'Enter a valid 6-digit pincode';
    return null;
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: AppColors.pageBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
