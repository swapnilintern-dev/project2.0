// =============================================================================
// VS Arogya — Outlet Staff · Invoice viewer
//
// Shows the SERVER-generated invoice PDF (the official HTML-template document)
// for an outlet order. Identical experience to the staff viewer, but fetched
// with the OUTLET's own session token — an outlet login never populates the
// shared AuthService the marketing/admin viewer relies on, so the outlet role
// needs its own authenticated fetch (OutletApi.fetchInvoicePdf).
//
// Right after a bill is placed the server may still be rendering/uploading the
// PDF, so "invoice not found" is retried for up to ~1 minute before giving up.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../customer/invoice_pdf.dart' show InvoicePdf;
import '../outlet_api.dart';
import '../outlet_theme.dart';

class OutletInvoiceScreen extends StatefulWidget {
  const OutletInvoiceScreen({super.key, required this.orderId, this.buyer = ''});

  final String orderId;

  /// The customer's firm name, shown under the title when known.
  final String buyer;

  @override
  State<OutletInvoiceScreen> createState() => _OutletInvoiceScreenState();
}

class _OutletInvoiceScreenState extends State<OutletInvoiceScreen> {
  final OutletApi _api = OutletApi();
  late Future<(Uint8List?, String?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Fetches the invoice, retrying while the server is still generating it.
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

  void _retry() => setState(() => _future = _load());

  String get _fileName => '${InvoicePdf.invoiceNo(widget.orderId)}.pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutletColors.bg,
      appBar: AppBar(
        backgroundColor: OutletColors.grad1,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invoice',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (widget.buyer.isNotEmpty)
              Text(widget.buyer,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
          CircularProgressIndicator(color: OutletColors.success),
          SizedBox(height: 16),
          Text('Loading invoice…',
              style: TextStyle(color: OutletColors.textMuted, fontSize: 13.5)),
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
                size: 48, color: OutletColors.textMuted),
            const SizedBox(height: 14),
            const Text('Invoice unavailable',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: OutletColors.textMuted, fontSize: 13)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: OutletColors.success,
                side: const BorderSide(color: OutletColors.border),
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
