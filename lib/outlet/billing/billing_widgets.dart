// =============================================================================
// VS Arogya — Outlet Billing (POS) · Shared widgets
//
// Small presentational building blocks shared across the billing wizard steps,
// styled with the existing OutletTheme tokens so the flow matches the rest of
// the Outlet role. Pure UI — no business logic lives here.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../outlet_theme.dart';

/// Primary gradient action button (matches the outlet header gradient).
class BillingButton extends StatelessWidget {
  const BillingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: enabled ? OutletColors.headerGradient : null,
        color: enabled ? null : OutletColors.textMuted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled ? OutletColors.cardShadow : null,
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
    );
    final button = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onPressed : null,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary/outline button used for "Back".
class BillingGhostButton extends StatelessWidget {
  const BillingGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_back_rounded, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: OutletColors.success,
        side: const BorderSide(color: OutletColors.border),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// A titled white card grouping related fields/rows.
class BillingCard extends StatelessWidget {
  const BillingCard({
    super.key,
    required this.child,
    this.icon,
    this.title,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final IconData? icon;
  final String? title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OutletColors.border),
        boxShadow: OutletColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: OutletColors.success),
                  const SizedBox(width: 8),
                ],
                Text(title!, style: OutletTextStyles.sectionTitle),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Labelled text field wrapping [TextFormField] with the outlet look.
class BillingField extends StatelessWidget {
  const BillingField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.required = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool required;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label, required: required),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            style: const TextStyle(fontSize: 14, color: OutletColors.textDark),
            decoration: _decoration(hint),
          ),
        ],
      ),
    );
  }
}

/// Labelled dropdown for the enum-like registration fields.
class BillingDropdown extends StatelessWidget {
  const BillingDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.required = false,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label, required: required),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            items: [
              for (final it in items)
                DropdownMenuItem(value: it, child: Text(it)),
            ],
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: OutletColors.textDark),
            decoration: _decoration(hint),
          ),
        ],
      ),
    );
  }
}

/// Labelled read-only date field that opens a picker on tap.
class BillingDateField extends StatelessWidget {
  const BillingDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? (hint ?? 'Select date')
        : '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label, required: required),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _decoration(null),
              child: Row(
                children: [
                  Expanded(
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 14,
                            color: value == null
                                ? OutletColors.textMuted
                                : OutletColors.textDark)),
                  ),
                  const Icon(Icons.calendar_today_rounded,
                      size: 18, color: OutletColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// +/- quantity stepper with a live cap; tapping the number opens manual entry
/// (when [onEdit] is provided).
class BillingQtyStepper extends StatelessWidget {
  const BillingQtyStepper({
    super.key,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
    this.onEdit,
    this.atMax = false,
  });

  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onEdit;
  final bool atMax;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OutletColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OutletColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove_rounded, onDecrement),
          InkWell(
            onTap: onEdit,
            child: Container(
              constraints: const BoxConstraints(minWidth: 34),
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              child: Text('$qty',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OutletColors.textDark)),
            ),
          ),
          _stepBtn(Icons.add_rounded, atMax ? null : onIncrement),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 18,
            color: onTap == null ? OutletColors.textMuted : OutletColors.success),
      ),
    );
  }
}

/// Prompts for a typed quantity, clamped to [1, max], and reports it via [onSet].
Future<void> showQtyEntryDialog(
  BuildContext context, {
  required int current,
  required int max,
  required ValueChanged<int> onSet,
}) async {
  final ctrl = TextEditingController(text: '$current');
  final value = await showDialog<int>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: const Text('Enter quantity'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          helperText: 'Max $max in stock',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(dctx, int.tryParse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dctx, int.tryParse(ctrl.text)),
          child: const Text('Set'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (value == null) return;
  onSet(value.clamp(1, max < 1 ? 1 : max));
}

/// Small caption label with an optional required asterisk.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: OutletColors.textMid)),
        if (required)
          const Text(' *', style: TextStyle(color: OutletColors.danger)),
      ],
    );
  }
}

InputDecoration _decoration(String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: OutletColors.textMuted, fontSize: 13),
      isDense: true,
      filled: true,
      fillColor: OutletColors.white,
      counterText: '',
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OutletColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OutletColors.success, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OutletColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OutletColors.danger, width: 1.4),
      ),
    );
