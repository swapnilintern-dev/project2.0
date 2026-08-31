// =============================================================================
// VS Arogya — Outlet Staff · Editable quantity control
//
// "− [12] +" where the number is a REAL text field: staff either type the
// quantity or step it, and both paths update the cart on the spot. Used by the
// Stock rows (filled, on the brand gradient) and by the Review Order lines
// (outlined, on white), so the two can never drift apart in behaviour.
//
// The rules it enforces structurally rather than by after-the-fact validation:
//   • digits only — a minus sign or a decimal point cannot be typed at all;
//   • never below 1 — an empty or 0 entry is not pushed into the cart (which
//     would delete the line mid-edit); − at 1 removes the line explicitly;
//   • never above [max] — the pinned batch's available units. The owner clamps
//     and this field re-reads the clamped value, so typing past the cap is
//     corrected as it happens.
//
// [max] of 0 means "no server-reported ceiling" (nothing pinned yet); the + is
// then left to the owner to gate.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'outlet_theme.dart';

enum OutletQtyFieldStyle {
  /// White-on-gradient pill — for use on light card surfaces.
  filled,

  /// Bordered, dark-on-white — for use inside a list row or panel.
  outlined,
}

class OutletQtyField extends StatefulWidget {
  const OutletQtyField({
    super.key,
    required this.qty,
    required this.max,
    required this.onSet,
    required this.onRemove,
    this.style = OutletQtyFieldStyle.filled,
    this.enabled = true,
  });

  /// The quantity the owner currently holds — always the source of truth.
  final int qty;

  /// The ceiling (the pinned lot's available units), or 0 when unknown.
  final int max;

  /// Called with every accepted quantity (typed or stepped).
  final ValueChanged<int> onSet;

  /// Called when − is pressed at 1 — the line leaves the cart.
  final VoidCallback onRemove;

  final OutletQtyFieldStyle style;

  /// False freezes the control — used while an order is being submitted, so the
  /// quantity can't be edited between the backend's validation and the write.
  final bool enabled;

  @override
  State<OutletQtyField> createState() => _OutletQtyFieldState();
}

class _OutletQtyFieldState extends State<OutletQtyField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: '${widget.qty}');
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Leaving the field half-edited (or empty) must not leave a number on
    // screen that the cart never accepted.
    _focus.addListener(() {
      if (!_focus.hasFocus) _syncText();
    });
  }

  @override
  void didUpdateWidget(OutletQtyField old) {
    super.didUpdateWidget(old);
    // Whenever the owner disagrees with what is displayed — a clamp to the
    // lot's ceiling, a step from the buttons — the field re-reads it. Assigning
    // text does not re-fire onChanged, so this cannot loop.
    _syncText();
  }

  void _syncText() {
    if (!mounted) return;
    if (int.tryParse(_ctrl.text) == widget.qty) return;
    _ctrl.text = '${widget.qty}';
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  bool get _atMax => widget.max > 0 && widget.qty >= widget.max;
  bool get _filled => widget.style == OutletQtyFieldStyle.filled;

  void _onTyped(String raw) {
    final parsed = int.tryParse(raw);
    // Empty / mid-edit input is left alone rather than pushed in as a zero. The
    // focus listener restores the accepted value when the user moves on.
    if (parsed == null || parsed < 1) return;
    widget.onSet(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final fg = _filled ? Colors.white : OutletColors.grad1;
    final disabled =
        _filled ? Colors.white.withValues(alpha: 0.35) : OutletColors.border;

    Widget btn(IconData icon, VoidCallback? onTap, {String? tooltip}) {
      final child = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: onTap == null ? disabled : fg),
        ),
      );
      return tooltip == null ? child : Tooltip(message: tooltip, child: child);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: _filled ? OutletColors.headerGradient : null,
        color: _filled ? null : OutletColors.white,
        borderRadius: BorderRadius.circular(12),
        border: _filled ? null : Border.all(color: OutletColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            widget.qty <= 1 ? Icons.delete_outline : Icons.remove,
            !widget.enabled
                ? null
                : widget.qty <= 1
                    ? widget.onRemove
                    : () => widget.onSet(widget.qty - 1),
            tooltip: widget.qty <= 1 ? 'Remove' : 'Decrease',
          ),
          SizedBox(
            width: 46,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              readOnly: !widget.enabled,
              onChanged: _onTyped,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              // Digits only — this is what makes negatives and decimals
              // impossible to enter, rather than merely rejected afterwards.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _focus.unfocus(),
              cursorColor: fg,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: fg,
                height: 1.1,
              ),
              decoration: const InputDecoration(
                // `filled: false` is NOT redundant: the app-wide
                // inputDecorationTheme turns fill ON with a white fillColor, so
                // without this the field paints a white box over the gradient —
                // and white-on-gradient text disappears into it.
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          btn(
            Icons.add,
            (_atMax || !widget.enabled)
                ? null
                : () => widget.onSet(widget.qty + 1),
            tooltip: _atMax ? 'No more units in this batch' : 'Increase',
          ),
        ],
      ),
    );
  }
}
