// =============================================================================
// MediCaPlus — Staff Invoice Viewer (Marketing / Admin)
//
// Shows the invoice PDF for an accepted order — SERVER-FIRST:
// GET /vsArogya/prev-invoice/:id → 302 redirect → hosted PDF (the official
// HTML-template document, followed by the client). If the backend has no PDF
// (its generator failed / is still pending), the SAME invoice is built
// on-device from the order data, so staff always see a document, never an
// error.
//
// Reached from the Marketing order details screen and the Admin order sheet —
// both staff roles see the same invoice as the vendor panel.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../customer/invoice_pdf.dart' show InvoicePdf;
import 'marketing_api.dart';

class StaffInvoiceScreen extends StatefulWidget {
  const StaffInvoiceScreen({
    super.key,
    required this.orderId,
    this.buyer = '',
  });

  final String orderId;

  /// The buyer's store name, shown under the title when known.
  final String buyer;

  @override
  State<StaffInvoiceScreen> createState() => _StaffInvoiceScreenState();
}

class _StaffInvoiceScreenState extends State<StaffInvoiceScreen> {
  final MarketingOrdersApi _api = MarketingOrdersApi();
  late Future<(Uint8List?, String?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// SERVER-ONLY invoice load — staff see the SAME backend-generated PDF the
  /// vendor sees, on the first open and every open after it (no on-device
  /// stand-in that looks different from the official template).
  ///
  /// Right after Accept the backend may still be generating/linking the PDF,
  /// so "invoice not found" is retried for up to ~1 minute before giving up
  /// with a Try-again message.
  Future<(Uint8List?, String?)> _load() async {
    var result = await _api.fetchInvoicePdf(widget.orderId);
    var attempt = 0;
    while (mounted &&
        result.$1 == null &&
        (result.$2 ?? '').toLowerCase().contains('invoice not found') &&
        attempt < 10) {
      await Future.delayed(const Duration(seconds: 6));
      if (!mounted) break;
      result = await _api.fetchInvoicePdf(widget.orderId);
      attempt++;
    }
    if (result.$1 == null &&
        (result.$2 ?? '').toLowerCase().contains('invoice not found')) {
      return (
        null,
        'The invoice is still being generated on the server. '
        'Please try again in a moment.',
      );
    }
    return result;
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  String get _fileName => '${InvoicePdf.invoiceNo(widget.orderId)}.pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invoice',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (widget.buyer.isNotEmpty)
              Text(widget.buyer,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.greyText)),
          ],
        ),
      ),
      body: FutureBuilder<(Uint8List?, String?)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _loading();
          }
          final bytes = snapshot.data?.$1;
          final error = snapshot.data?.$2;
          if (bytes != null && bytes.isNotEmpty) {
            return PdfPreview(
              build: (_) => bytes,
              useActions: true,
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: _fileName,
              loadingWidget: _loading(),
              previewPageMargin: const EdgeInsets.all(12),
            );
          }
          return _errorView(error ?? 'Could not load the invoice.');
        },
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Loading invoice…',
              style: TextStyle(color: AppColors.greyText, fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.greyText),
            const SizedBox(height: 14),
            const Text('Invoice unavailable',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.greyText, fontSize: 13),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
