// =============================================================================
// VS Arogya — Outlet Staff · Batch picker (single lot, FEFO-ordered)
//
// The bottom sheet the Outlet manual-order flow opens the moment a medicine is
// added, and again whenever staff change the lot on an existing line. ONE batch
// is chosen per line — that lot is then pinned on the cart line and sent to the
// backend as the line's `allocations` entry.
//
// Everything shown here is read LIVE from
//   GET /vsArogya/outlet/product/:id/available-batches
// which is scoped server-side to the signed-in outlet and already returns only
// SELLABLE lots (available > 0, not past expiry) in FEFO order — nearest expiry
// first, then the oldest lot. This file therefore never sorts, filters or
// invents inventory: the server's order IS the policy, and the nearest-expiry
// lot is what sits on top.
//
// Batches are fetched when the sheet opens (lazy — never on the stock list), and
// the sheet surfaces its own loading / empty / error states with a retry.
// =============================================================================

import 'package:flutter/material.dart';

import '../widgets/expiry_alert.dart';
import 'outlet_live_datasource.dart' show OutletApiException;
import 'outlet_models.dart';
import 'outlet_repository.dart';
import 'outlet_theme.dart';

/// Opens the picker for one medicine and returns the chosen lot, or null when
/// staff backed out (leaving any previous choice untouched).
///
/// [selectedBatchId] pre-selects the lot the line is currently pinned to; when
/// it is empty (a fresh add) the FEFO front — the first row the server returned
/// — is pre-selected instead.
Future<OutletBatch?> showOutletBatchPicker({
  required BuildContext context,
  required String productId,
  required String productName,
  String selectedBatchId = '',
  OutletRepository? repository,
}) {
  return showModalBottomSheet<OutletBatch>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OutletBatchPickerSheet(
      productId: productId,
      productName: productName,
      selectedBatchId: selectedBatchId,
      repository: repository ?? OutletRepository(),
    ),
  );
}

class _OutletBatchPickerSheet extends StatefulWidget {
  const _OutletBatchPickerSheet({
    required this.productId,
    required this.productName,
    required this.selectedBatchId,
    required this.repository,
  });

  final String productId;
  final String productName;
  final String selectedBatchId;
  final OutletRepository repository;

  @override
  State<_OutletBatchPickerSheet> createState() =>
      _OutletBatchPickerSheetState();
}

class _OutletBatchPickerSheetState extends State<_OutletBatchPickerSheet> {
  List<OutletBatch> _batches = const [];
  bool _loading = true;
  String? _error;

  /// The lot currently highlighted. Empty until the batches land.
  String _selectedId = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedBatchId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batches = await widget.repository.fetchAvailableBatches(
        widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _loading = false;
        // Keep the line's current lot selected when it is still offered;
        // otherwise fall back to the FEFO front the server put first.
        final stillThere = batches.any((b) => b.id == _selectedId);
        if (!stillThere) {
          _selectedId = batches.isEmpty ? '' : batches.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is OutletApiException
            ? e.message
            : 'Could not load batches. Check your connection and try again.';
      });
    }
  }

  OutletBatch? get _selected {
    for (final b in _batches) {
      if (b.id == _selectedId) return b;
    }
    return null;
  }

  void _confirm() {
    final chosen = _selected;
    if (chosen == null) return;
    Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: OutletColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            _header(),
            Flexible(child: _body()),
            if (!_loading && _error == null && _batches.isNotEmpty) _footer(),
          ],
        ),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 12),
        decoration: BoxDecoration(
          color: OutletColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.inventory_2_outlined,
                  size: 18, color: OutletColors.grad1),
              SizedBox(width: 8),
              Expanded(
                child: Text('Select batch',
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: OutletColors.textDark)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(widget.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OutletTextStyles.prodName),
          const SizedBox(height: 3),
          const Text(
            'Your outlet\'s own lots, nearest expiry first. The top lot is '
            'selected for you — change it only when the counter needs another.',
            style: TextStyle(fontSize: 11.5, color: OutletColors.textMid),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 44),
        child: Center(
          child: CircularProgressIndicator(color: OutletColors.success),
        ),
      );
    }
    if (_error != null) return _errorState(_error!);
    if (_batches.isEmpty) return _emptyState();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      itemCount: _batches.length,
      itemBuilder: (_, i) => _batchTile(_batches[i], i == 0),
    );
  }

  Widget _batchTile(OutletBatch b, bool isFefoFront) {
    final selected = b.id == _selectedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedId = b.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: OutletColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? OutletColors.success : OutletColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color:
                        selected ? OutletColors.success : OutletColors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.batchNumber.isEmpty
                                  ? 'Unnumbered lot'
                                  : 'Batch ${b.batchNumber}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: OutletColors.textDark),
                            ),
                          ),
                          if (isFefoFront) ...[
                            _tag('FEFO', OutletColors.success),
                            const SizedBox(width: 4),
                          ],
                          // The colour-graded expiry warning (Outlet is one of
                          // the two roles allowed to see it).
                          ExpiryTierBadge(expiry: b.expiry, dense: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _fact(Icons.event_outlined, formatExpiry(b.expiry),
                              color: expiryTierOf(b.expiry).color),
                          _fact(Icons.timelapse_outlined,
                              expiryCountdown(b.expiry)),
                          _fact(Icons.inventory_outlined,
                              '${b.available} available'),
                          if (b.manufacturingDate != null)
                            _fact(
                              Icons.precision_manufacturing_outlined,
                              'Mfg ${formatExpiry(b.manufacturingDate).replaceFirst('Exp ', '')}',
                            ),
                          if (b.supplier.isNotEmpty)
                            _fact(Icons.local_shipping_outlined, b.supplier),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String label, {Color? color}) {
    final c = color ?? OutletColors.textMid;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
      );

  /// A failed fetch must never fall through to "no batches" — staff would read
  /// that as "nothing in stock" and restock something they already hold.
  Widget _errorState(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 38, color: OutletColors.textMuted),
          const SizedBox(height: 10),
          const Text('Could not load batches',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: OutletTextStyles.prodSub),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style:
                OutlinedButton.styleFrom(foregroundColor: OutletColors.success),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 38, color: OutletColors.textMuted),
          SizedBox(height: 10),
          Text('No sellable batch',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            'Every lot of this medicine in your outlet is either empty or past '
            'its expiry date, so none can be issued. Ask Marketing to assign '
            'fresh stock.',
            textAlign: TextAlign.center,
            style: OutletTextStyles.prodSub,
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final chosen = _selected;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: OutletColors.white,
        border: Border(top: BorderSide(color: OutletColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                chosen == null
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 16,
                color:
                    chosen == null ? OutletColors.danger : OutletColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  chosen == null
                      ? 'Choose the lot this line is issued from'
                      : 'Up to ${chosen.available} unit'
                          '${chosen.available == 1 ? '' : 's'} from this lot',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: chosen == null
                          ? OutletColors.danger
                          : OutletColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OutletColors.textMid,
                    side: const BorderSide(color: OutletColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: chosen == null ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OutletColors.grad1,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: OutletColors.border,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Use this batch',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
