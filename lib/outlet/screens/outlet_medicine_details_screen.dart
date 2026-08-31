// =============================================================================
// VS Arogya — Outlet Staff · Medicine Details
//
// Opened by tapping a medicine on the Stock screen (own-outlet rows only). It
// answers the question the Stock row can't: "which lots of this medicine do I
// actually hold, and what shape are they in?"
//
// EVERYTHING here is live. One request —
//   GET /vsArogya/outlet/product/:id/available-batches?all=1
// — returns the catalog product, this outlet's stock totals and every lot it
// holds (expired and emptied included, which the default sellable read hides).
// The screen computes no inventory of its own: quantities are the server's,
// the batch ORDER is the server's FEFO order (never re-sorted here), and the
// only thing derived locally is the expiry grading, which comes from the shared
// [ExpiryTier] scale so a batch looks identical wherever it appears in the app.
//
// The endpoint is outlet-scoped server-side (the session's outlet id), so this
// can only ever show the signed-in outlet's own inventory — district stock is
// not readable here, matching the read-only rule on the Stock screen.
// =============================================================================

import 'package:flutter/material.dart';

import '../outlet_models.dart';
import '../outlet_repository.dart';
import '../outlet_theme.dart';
import '../../widgets/expiry_alert.dart';

class OutletMedicineDetailsScreen extends StatefulWidget {
  const OutletMedicineDetailsScreen({super.key, required this.item});

  /// The row that was tapped. Used ONLY to render the title and price band
  /// while the live detail loads — every number on this screen is replaced by
  /// the server's answer the moment it arrives.
  final OutletStockItem item;

  @override
  State<OutletMedicineDetailsScreen> createState() =>
      _OutletMedicineDetailsScreenState();
}

class _OutletMedicineDetailsScreenState
    extends State<OutletMedicineDetailsScreen> {
  final _repo = OutletRepository();

  OutletMedicineDetail? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final detail = await _repo.fetchMedicineDetail(widget.item.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep whatever was already on screen: a failed refresh must not blank
      // out inventory the user is reading. The banner says the data is stale.
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutletColors.bg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: OutletColors.success,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  // --- Header ----------------------------------------------------------------

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 10, 18, 18),
      decoration: const BoxDecoration(gradient: OutletColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back to stock',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    _detail?.name.isNotEmpty == true
                        ? _detail!.name
                        : widget.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text('Batch-wise stock in your outlet',
                      style: OutletTextStyles.subGreet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Body states -----------------------------------------------------------

  Widget _body() {
    final detail = _detail;

    // First load — nothing to show yet.
    if (detail == null && _loading) return const _DetailShimmer();

    // First load failed — a full-screen error with a retry, never an empty
    // state: "no batches" and "couldn't load" mean very different things to
    // someone about to hand over medicine.
    if (detail == null) return _errorState(_error ?? 'Could not load details');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        // A refresh that failed while detail is already on screen: say so
        // rather than silently showing figures that may have moved.
        if (_error != null) ...[
          _staleBanner(_error!),
          const SizedBox(height: 12),
        ],
        _productCard(detail),
        const SizedBox(height: 12),
        _stockSummary(detail),
        const SizedBox(height: 12),
        _infoCard(detail),
        if (detail.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _descriptionCard(detail.description.trim()),
        ],
        const SizedBox(height: 18),
        _batchesHeader(detail),
        const SizedBox(height: 10),
        if (detail.batches.isEmpty)
          _noBatches(detail)
        else
          for (var i = 0; i < detail.batches.length; i++)
            _batchCard(detail, detail.batches[i], i),
      ],
    );
  }

  Widget _errorState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 70, 28, 0),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 42, color: OutletColors.textMuted),
              const SizedBox(height: 12),
              const Text('Could not load this medicine',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: OutletColors.textDark)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: OutletTextStyles.prodSub),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: OutletColors.success),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _staleBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OutletColors.badgeAmberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OutletColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_outlined,
              size: 16, color: OutletColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing the last loaded figures — $message',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: OutletColors.textDark),
            ),
          ),
          TextButton(
            onPressed: _load,
            style: TextButton.styleFrom(
                foregroundColor: OutletColors.success,
                visualDensity: VisualDensity.compact),
            child: const Text('Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // --- Product ---------------------------------------------------------------

  Widget _productCard(OutletMedicineDetail d) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbnail(d.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: OutletColors.textDark)),
                const SizedBox(height: 4),
                Text(
                  [
                    if (d.brand.isNotEmpty) d.brand,
                    if (d.packInfo.isNotEmpty) d.packInfo,
                    if (d.category.isNotEmpty) d.category,
                  ].join(' · '),
                  style: OutletTextStyles.prodSub,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('₹${d.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: OutletColors.textDark)),
                    if (d.mrp > d.price)
                      Text('MRP ₹${d.mrp.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: OutletColors.textMuted,
                              decoration: TextDecoration.lineThrough)),
                    if (d.mrpSaving > 0)
                      OutletBadge(
                        label: 'Save ₹${d.mrpSaving.toStringAsFixed(2)}',
                        bg: OutletColors.badgeGreenBg,
                        fg: OutletColors.success,
                      ),
                  ],
                ),
                if (d.prescriptionRequired || d.coldStored.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (d.prescriptionRequired)
                        const OutletBadge(
                          label: 'Prescription required',
                          bg: OutletColors.badgeRedBg,
                          fg: OutletColors.danger,
                        ),
                      if (d.coldStored.isNotEmpty)
                        OutletBadge(
                          label: 'Cold chain · ${d.coldStored}',
                          bg: OutletColors.badgeAmberBg,
                          fg: OutletColors.amber,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Product image, loaded lazily and degrading to a neutral icon — a broken
  /// or missing image must never look like a broken screen.
  Widget _thumbnail(String url) {
    const size = 74.0;
    Widget placeholder([bool spinning = false]) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: OutletColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OutletColors.border),
          ),
          child: Center(
            child: spinning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: OutletColors.success),
                  )
                : const Icon(Icons.medication_outlined,
                    size: 26, color: OutletColors.textMuted),
          ),
        );

    if (url.isEmpty) return placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder(true),
        errorBuilder: (context, error, stack) => placeholder(),
      ),
    );
  }

  // --- Stock summary ---------------------------------------------------------

  Widget _stockSummary(OutletMedicineDetail d) {
    // The server's SUM over the lots is the number staff can sell. When the
    // stored mirror disagrees, show it rather than hide it — a drift is an
    // inventory problem someone needs to see.
    final drifted = d.stockMirror != d.totalStock;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _stat('${d.totalStock}', 'Total stock',
                      OutletColors.success)),
              _divider(),
              Expanded(
                  child: _stat('${d.batchCount}', 'Batches',
                      OutletColors.textDark)),
              _divider(),
              Expanded(
                  child: _stat('${d.sellableBatchCount}', 'Sellable now',
                      OutletColors.textDark)),
            ],
          ),
          if (drifted) ...[
            const SizedBox(height: 10),
            Text(
              'Stored outlet quantity reads ${d.stockMirror} — the batch total '
              'above is what can actually be issued.',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OutletColors.amber),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: OutletTextStyles.statLabel),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: OutletColors.border,
      );

  // --- Medicine information --------------------------------------------------

  Widget _infoCard(OutletMedicineDetail d) {
    // Only facts the catalog actually holds are listed — an empty field is
    // omitted rather than rendered as a blank or invented row.
    final rows = <(String, String)>[
      if (d.manufacturer.isNotEmpty) ('Manufacturer', d.manufacturer),
      if (d.marketedBy.isNotEmpty) ('Marketed by', d.marketedBy),
      if (d.brand.isNotEmpty) ('Brand', d.brand),
      if (d.category.isNotEmpty) ('Category', d.category),
      if (d.packInfo.isNotEmpty) ('Pack', d.packInfo),
      if (d.packOf > 0) ('Units per pack', '${d.packOf}'),
      if (d.code.isNotEmpty) ('Product code', d.code),
      if (d.hsnCode.isNotEmpty) ('HSN code', d.hsnCode),
      if (d.gstPercent > 0) ('GST', '${_trim(d.gstPercent)}%'),
      if (d.discountPercent > 0) ('Discount', '${_trim(d.discountPercent)}%'),
      if (d.mrp > 0) ('MRP', '₹${d.mrp.toStringAsFixed(2)}'),
      ('Selling price', '₹${d.price.toStringAsFixed(2)}'),
      if (d.createdAt != null) ('Added on', _fullDate(d.createdAt)),
      if (d.updatedAt != null) ('Last updated', _fullDate(d.updatedAt)),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.info_outline, 'Medicine information'),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(rows[i].$1, style: OutletTextStyles.prodSub),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: OutletColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _descriptionCard(String description) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.notes_outlined, 'Description'),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.45, color: OutletColors.textMid)),
        ],
      ),
    );
  }

  // --- Batches ---------------------------------------------------------------

  Widget _batchesHeader(OutletMedicineDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 18, color: OutletColors.success),
            const SizedBox(width: 8),
            const Text('Available Batches',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OutletColors.textDark)),
            const Spacer(),
            OutletBadge(
              label: '${d.batchCount} total',
              bg: OutletColors.badgeGreenBg,
              fg: OutletColors.success,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          d.showsAllLots
              ? 'Nearest expiry first (FEFO) — the order stock is actually '
                  'issued in.'
              : 'Nearest expiry first (FEFO). This server returns only the '
                  'sellable lots, so any expired or emptied batch is not '
                  'listed here.',
          style: OutletTextStyles.prodSub,
        ),
      ],
    );
  }

  Widget _noBatches(OutletMedicineDetail d) {
    return _card(
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 34, color: OutletColors.textMuted),
          const SizedBox(height: 10),
          const Text('No Batch Available',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: OutletColors.textDark)),
          const SizedBox(height: 6),
          Text(
            d.showsAllLots
                ? 'This outlet holds no batched stock of this medicine. Ask '
                    'the marketing team to assign stock to your outlet.'
                : 'This outlet has no lot of this medicine that can be sold '
                    'right now — every batch is either empty or past its '
                    'expiry date.',
            textAlign: TextAlign.center,
            style: OutletTextStyles.prodSub,
          ),
        ],
      ),
    );
  }

  Widget _batchCard(OutletMedicineDetail d, OutletBatch b, int index) {
    final status = _BatchStatus.of(b);
    // The backend fills orders from the first lot it can sell, so that is the
    // one this outlet will hand over next.
    final isNext = _isFefoFront(d, b);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: OutletColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OutletColors.cardShadow,
        border: Border.all(
          color: status.alarming
              ? status.color.withValues(alpha: 0.35)
              : OutletColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.batchNumber.isEmpty ? 'Unnumbered lot' : b.batchNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: OutletColors.textDark),
                ),
              ),
              if (isNext) ...[
                const OutletBadge(
                  label: 'Sells next',
                  bg: OutletColors.badgeGreenBg,
                  fg: OutletColors.success,
                ),
                const SizedBox(width: 6),
              ],
              OutletBadge(
                label: status.label,
                bg: status.color.withValues(alpha: 0.12),
                fg: status.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _batchFact(
                  Icons.inventory_outlined,
                  'Quantity',
                  '${b.available}',
                  color: b.available <= 0 ? OutletColors.textMuted : null,
                ),
              ),
              Expanded(
                child: _batchFact(
                  Icons.event_outlined,
                  'Expiry',
                  _fullDate(b.expiry, fallback: 'No printed expiry'),
                  color: b.expiry == null ? null : expiryTierOf(b.expiry).color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _batchFact(
                  Icons.precision_manufacturing_outlined,
                  'Manufactured',
                  _fullDate(b.manufacturingDate, fallback: '—'),
                ),
              ),
              Expanded(
                child: _batchFact(
                  Icons.timelapse_outlined,
                  'Shelf life',
                  b.expiry == null ? '—' : expiryCountdown(b.expiry),
                  color: b.expiry == null ? null : expiryTierOf(b.expiry).color,
                ),
              ),
            ],
          ),
          if (b.sellingPrice > 0 || b.purchasePrice > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _batchFact(
                    Icons.sell_outlined,
                    'Selling price',
                    b.sellingPrice > 0
                        ? '₹${b.sellingPrice.toStringAsFixed(2)}'
                        : '—',
                  ),
                ),
                Expanded(
                  child: _batchFact(
                    Icons.shopping_bag_outlined,
                    'Purchase price',
                    b.purchasePrice > 0
                        ? '₹${b.purchasePrice.toStringAsFixed(2)}'
                        : '—',
                  ),
                ),
              ],
            ),
          ],
          if (b.supplier.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _batchFact(
                Icons.local_shipping_outlined, 'Supplier', b.supplier.trim()),
          ],
          if (b.purchaseDate != null || b.updatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (b.purchaseDate != null)
                  'Received ${_fullDate(b.purchaseDate)}',
                if (b.updatedAt != null) 'updated ${_fullDate(b.updatedAt)}',
              ].join(' · '),
              style: const TextStyle(fontSize: 10.5, color: OutletColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// True for the lot the backend's FEFO allocation would draw from first —
  /// the first one in the server's order that is in stock and not expired.
  bool _isFefoFront(OutletMedicineDetail d, OutletBatch batch) {
    for (final b in d.batches) {
      if (b.available <= 0) continue;
      if (expiryTierOf(b.expiry) == ExpiryTier.expired) continue;
      return identical(b, batch);
    }
    return false;
  }

  Widget _batchFact(IconData icon, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: OutletColors.textMuted),
            const SizedBox(width: 4),
            Text(label, style: OutletTextStyles.statLabel),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            value,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color ?? OutletColors.textDark),
          ),
        ),
      ],
    );
  }

  // --- Shared bits -----------------------------------------------------------

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OutletColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: OutletColors.cardShadow,
        ),
        child: child,
      );

  Widget _cardTitle(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 16, color: OutletColors.success),
          const SizedBox(width: 8),
          Text(title, style: OutletTextStyles.sectionTitle),
        ],
      );

  /// "12 Mar 2027", or [fallback] when the backend carries no date.
  static String _fullDate(DateTime? d, {String fallback = '—'}) {
    if (d == null) return fallback;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  /// "18" not "18.0"; "2.5" stays "2.5".
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

// -----------------------------------------------------------------------------
// Batch status
// -----------------------------------------------------------------------------

/// The one-word verdict on a lot, in the order that matters to someone about to
/// issue it: an expired lot is called out even when it is also empty, because
/// that is the fact that must never be missed.
///
/// Expiry grading itself is delegated to the shared [ExpiryTier] scale, so the
/// colours here are the same ones the Stock rows and the billing batch picker
/// use for the same dates.
class _BatchStatus {
  const _BatchStatus(this.label, this.color, {this.alarming = false});

  final String label;
  final Color color;
  final bool alarming;

  factory _BatchStatus.of(OutletBatch b) {
    final tier = expiryTierOf(b.expiry);
    if (tier == ExpiryTier.expired) {
      return _BatchStatus('Expired', tier.color, alarming: true);
    }
    if (b.available <= 0) {
      return const _BatchStatus('Out of stock', OutletColors.textMuted);
    }
    if (tier.isAlarming) {
      return _BatchStatus('Expiring Soon', tier.color, alarming: true);
    }
    return const _BatchStatus('Healthy', OutletColors.success);
  }
}

// -----------------------------------------------------------------------------
// Loading skeleton
// -----------------------------------------------------------------------------

/// Shimmering placeholder shown on the first load. Hand-rolled (a sweeping
/// gradient over grey blocks) so the app takes on no new dependency for it.
class _DetailShimmer extends StatefulWidget {
  const _DetailShimmer();

  @override
  State<_DetailShimmer> createState() => _DetailShimmerState();
}

class _DetailShimmerState extends State<_DetailShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        _block(height: 108),
        const SizedBox(height: 12),
        _block(height: 74),
        const SizedBox(height: 12),
        _block(height: 150),
        const SizedBox(height: 18),
        _bar(width: 160, height: 16),
        const SizedBox(height: 12),
        _block(height: 128),
        const SizedBox(height: 10),
        _block(height: 128),
      ],
    );
  }

  Widget _block({required double height}) => _shimmer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

  Widget _bar({required double width, required double height}) => _shimmer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );

  Widget _shimmer({required Widget child}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          // Sweep the highlight from left to right across the widget.
          final dx = rect.width * (_controller.value * 2 - 0.5);
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFEDF3F1),
              Color(0xFFF7FBFA),
              Color(0xFFEDF3F1),
            ],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(dx),
          ).createShader(rect);
        },
        child: child,
      ),
    );
  }
}

/// Shifts a gradient horizontally by [dx] logical pixels.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
