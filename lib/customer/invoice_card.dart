// =============================================================================
// MediCaPlus — Invoice card (Order Details)
//
// Sits below the Bill Summary once the order has been ACCEPTED. Shows the
// tax-invoice number and lets the buyer:
//   • Download PDF — server invoice first (the official HTML-template PDF);
//     if the backend has no PDF, the invoice is built on-device (InvoicePdf)
//     so the download always succeeds. Opens the OS save/share sheet.
//   • Preview     — opens the invoice in-app (same server-first logic).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import 'customer_api.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'invoice_pdf.dart';
import 'invoice_preview_screen.dart';

class InvoiceCard extends StatefulWidget {
  const InvoiceCard({super.key, required this.order});

  final Order order;

  @override
  State<InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<InvoiceCard> {
  final CustomerApi _api = CustomerApi();
  bool _busy = false;

  /// The REAL invoice number from the backend when available (populated
  /// `invoice` document), falling back to a derived reference otherwise.
  String get _invoiceNo {
    final real = widget.order.invoiceNumber;
    if (real != null && real.isNotEmpty) return real;
    return InvoicePdf.invoiceNo(widget.order.id);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    // SERVER-ONLY (GET /prev-invoice/:id → redirect → PDF) — the official
    // HTML-template document, so the downloaded invoice is always IDENTICAL
    // to the previewed one. No on-device stand-in: if the server PDF isn't
    // ready yet, the user is asked to try again in a moment.
    final (bytes, error) = await _api.fetchServerInvoice(widget.order);
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null || bytes.isEmpty) {
      final stillGenerating =
          (error ?? '').toLowerCase().contains('invoice not found');
      showAppSnack(
          context,
          stillGenerating
              ? 'The invoice is still being generated on the server — try again in a moment.'
              : (error ?? 'Could not prepare the invoice. Try again.'),
          success: false);
      return;
    }
    try {
      await Printing.sharePdf(bytes: bytes, filename: '$_invoiceNo.pdf');
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not open the save sheet. Try again.',
            success: false);
      }
    }
  }

  void _preview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(order: widget.order),
      ),
    );
  }

  void _copyNumber() {
    Clipboard.setData(ClipboardData(text: _invoiceNo));
    showAppSnack(context, 'Invoice number copied');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.receipt_long, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tax Invoice',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _invoiceNo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.greyText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _copyNumber,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.copy_rounded,
                                size: 15, color: AppColors.greyText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: PrimaryButton(
                  label: _busy ? 'Preparing…' : 'Download PDF',
                  icon: _busy ? null : Icons.download_rounded,
                  loading: _busy,
                  onPressed: _busy ? null : _download,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SecondaryButton(
                  label: 'Preview',
                  icon: Icons.visibility_outlined,
                  onPressed: _busy ? null : _preview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
