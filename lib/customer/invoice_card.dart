// =============================================================================
// MediCaPlus — Invoice card (Order Details)
//
// Sits below the Invoice Summary. Shows the tax-invoice number and lets the
// buyer:
//   • Download PDF — builds the invoice on-device (see InvoicePdf) and opens the
//     OS save/share sheet (Android + iOS + web, no storage permission → store
//     safe).
//   • Preview     — opens the rendered invoice in-app.
//
// Generation is fully local, so it works for every placed order (even offline)
// and never depends on the backend.
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

  String get _invoiceNo => InvoicePdf.invoiceNo(widget.order.id);

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Server invoice only (GET /prev-invoice/:id → redirect → PDF).
    final (bytes, error) = await _api.fetchServerInvoice(widget.order);
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null || bytes.isEmpty) {
      // Right after checkout the server may still be generating the PDF.
      final msg = (error ?? '').toLowerCase().contains('invoice not found')
          ? 'Your invoice is still being generated — try again in a few seconds.'
          : (error ?? 'Could not download the invoice.');
      showAppSnack(context, msg, success: false);
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
