// =============================================================================
// VS Arogya — Outlet Billing (POS) · Success screen
//
// Shown the moment the bill is placed (stock already deducted, invoice being
// rendered server-side). Two things happen here, neither blocking the cashier:
//   • the customer's VENDOR REGISTRATION is submitted to Admin IN THE BACKGROUND
//     (register-vendor API) with a live status + a Retry if it fails, so the
//     request reliably reaches Admin for approval → the normal approval + email
//     flow then continues on its own; and
//   • the INVOICE can be downloaded / shared / viewed as soon as the server
//     finishes generating it.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../customer/invoice_pdf.dart' show InvoicePdf;
import '../outlet_api.dart';
import '../../theme/app_widgets.dart' show shareOriginFor;
import '../outlet_models.dart';
import '../outlet_theme.dart';
import '../screens/outlet_invoice_screen.dart';
import 'billing_widgets.dart';

enum _RegStatus { submitting, done, failed }

class BillingSuccessScreen extends StatefulWidget {
  const BillingSuccessScreen({
    super.key,
    required this.order,
    required this.registrationPayload,
  });

  final OutletOrder order;

  /// JSON body for POST /outlet/register-vendor — filed to Admin here, in the
  /// background (PENDING vendor, registrationSource:"outlet"). NO file uploads.
  final Map<String, dynamic> registrationPayload;

  @override
  State<BillingSuccessScreen> createState() => _BillingSuccessScreenState();
}

class _BillingSuccessScreenState extends State<BillingSuccessScreen> {
  final OutletApi _api = OutletApi();

  _RegStatus _reg = _RegStatus.submitting;
  String? _regError;

  Uint8List? _pdf;
  bool _pdfLoading = true;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    _registerCustomer();
    _loadInvoice();
  }

  // --- Background vendor registration ----------------------------------------

  Future<void> _registerCustomer() async {
    if (mounted) {
      setState(() {
        _reg = _RegStatus.submitting;
        _regError = null;
      });
    }
    final (ok, message) =
        await _api.registerOutletVendor(widget.registrationPayload);
    if (!mounted) return;
    setState(() {
      if (ok) {
        _reg = _RegStatus.done;
      } else {
        _reg = _RegStatus.failed;
        _regError = message;
      }
    });
  }

  // --- Invoice (retry while the server is still rendering it) -----------------

  Future<void> _loadInvoice() async {
    if (widget.order.id.isEmpty) {
      setState(() {
        _pdfLoading = false;
        _pdfError = 'No order reference to load the invoice.';
      });
      return;
    }
    if (mounted) {
      setState(() {
        _pdfLoading = true;
        _pdfError = null;
      });
    }
    var result = await _api.fetchInvoicePdf(widget.order.id);
    var attempt = 0;
    while (mounted &&
        result.$1 == null &&
        (result.$2 ?? '').toLowerCase().contains('invoice not found') &&
        attempt < 12) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      result = await _api.fetchInvoicePdf(widget.order.id);
      attempt++;
    }
    if (!mounted) return;
    setState(() {
      _pdf = result.$1;
      _pdfLoading = false;
      _pdfError = result.$1 == null
          ? 'The invoice is still being generated. Tap retry in a moment.'
          : null;
    });
  }

  String get _fileName => '${InvoicePdf.invoiceNo(widget.order.id)}.pdf';

  Future<void> _download() async {
    final bytes = _pdf;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileName);
  }

  Future<void> _share() async {
    final bytes = _pdf;
    if (bytes == null) return;
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName,
      bounds: shareOriginFor(context),
    );
  }

  void _view() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OutletInvoiceScreen(
            orderId: widget.order.id, buyer: widget.order.customer.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutletColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _hero(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 12),
                  _registrationCard(),
                  const SizedBox(height: 12),
                  _invoiceCard(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: BillingGhostButton(
                label: 'Done',
                icon: Icons.home_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        gradient: OutletColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 16),
          const Text('Bill Created',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Stock updated · invoice generated',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return BillingCard(
      child: Column(
        children: [
          _row('Customer', widget.order.customer.name),
          const Divider(height: 18, color: OutletColors.border),
          _row('Items', '${widget.order.itemCount}'),
          const Divider(height: 18, color: OutletColors.border),
          _row('Total', '₹${widget.order.total.toStringAsFixed(2)}'),
          const Divider(height: 18, color: OutletColors.border),
          _row('Order ID', widget.order.id, mono: true),
        ],
      ),
    );
  }

  // --- Registration status ---------------------------------------------------

  Widget _registrationCard() {
    final (icon, color, title, sub) = switch (_reg) {
      _RegStatus.submitting => (
          Icons.cloud_upload_outlined,
          OutletColors.amber,
          'Submitting to Admin…',
          'Sending the customer\'s vendor registration for approval.'
        ),
      _RegStatus.done => (
          Icons.verified_outlined,
          OutletColors.success,
          'Registration submitted',
          'Pending Admin approval — once approved, the backend emails the '
              'customer their login automatically.'
        ),
      _RegStatus.failed => (
          Icons.error_outline_rounded,
          OutletColors.danger,
          'Registration not sent',
          _regError ?? 'Could not submit the registration.'
        ),
    };

    return BillingCard(
      icon: Icons.how_to_reg_outlined,
      title: 'Customer registration',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_reg == _RegStatus.submitting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: OutletColors.amber),
            )
          else
            Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 12, color: OutletColors.textMuted)),
                if (_reg == _RegStatus.failed) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 140,
                    child: BillingButton(
                        label: 'Retry', onPressed: _registerCustomer),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Invoice actions -------------------------------------------------------

  Widget _invoiceCard() {
    return BillingCard(
      icon: Icons.receipt_long_outlined,
      title: 'Invoice',
      child: _pdfLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: OutletColors.success),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Preparing invoice…',
                        style: TextStyle(
                            fontSize: 13, color: OutletColors.textMuted)),
                  ),
                ],
              ),
            )
          : _pdf == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pdfError ?? 'Invoice unavailable.',
                        style: const TextStyle(
                            fontSize: 12.5, color: OutletColors.textMuted)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 160,
                      child: BillingButton(
                          label: 'Retry', onPressed: _loadInvoice),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: BillingButton(
                            label: 'Download',
                            icon: Icons.download_rounded,
                            onPressed: _download,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BillingButton(
                            label: 'Share',
                            icon: Icons.share_rounded,
                            onPressed: _share,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    BillingGhostButton(
                        label: 'View full invoice',
                        icon: Icons.open_in_full_rounded,
                        onPressed: _view),
                  ],
                ),
    );
  }

  Widget _row(String label, String value, {bool mono = false}) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: OutletColors.textMid)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: OutletColors.textDark,
                  fontFamily: mono ? 'monospace' : null)),
        ),
      ],
    );
  }
}
