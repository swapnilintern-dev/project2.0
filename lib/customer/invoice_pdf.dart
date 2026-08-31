// =============================================================================
// MediCaPlus — On-device Tax Invoice PDF
//
// Builds the customer's tax invoice entirely on the device using the `pdf`
// package — NO server call, so it works offline, instantly, and never depends
// on the backend's PDF engine (Puppeteer/Chromium on Render). Numbers mirror
// the Order's own Invoice Summary exactly, so the PDF matches what the customer
// sees on screen.
//
// Brand assets (logo / QR / signature stamp) are bundled in assets/invoice/.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'customer_models.dart';

class InvoicePdf {
  InvoicePdf._();

  // Brand palette (matches the app theme).
  static const PdfColor _green = PdfColor.fromInt(0xFF1E8E5A);
  static const PdfColor _darkGreen = PdfColor.fromInt(0xFF11633C);
  static const PdfColor _lightGreen = PdfColor.fromInt(0xFFE7F5EE);
  static const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFD8DEDA);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);

  // Brand images are read once and cached.
  static pw.MemoryImage? _logo;
  static pw.MemoryImage? _qr;
  static pw.MemoryImage? _stamp;

  static Future<pw.MemoryImage> _img(String path) async {
    final data = await rootBundle.load(path);
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  static Future<void> _ensureAssets() async {
    _logo ??= await _img('assets/invoice/logo.jpg');
    _qr ??= await _img('assets/invoice/qr.png');
    _stamp ??= await _img('assets/invoice/stamp.png');
  }

  /// `INV-XXXXXXXX` — stable, derived from the order id (matches the on-screen
  /// invoice number shown by the InvoiceCard).
  static String invoiceNo(String orderId) {
    final tail =
        orderId.length >= 8 ? orderId.substring(orderId.length - 8) : orderId;
    return 'INV-${tail.toUpperCase()}';
  }

  /// True when [bytes] start with the PDF magic marker `%PDF`. Used to accept a
  /// downloaded body as a real PDF regardless of its Content-Type header
  /// (Cloudinary raw sometimes serves `application/octet-stream`).
  static bool looksLikePdf(Uint8List bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

  /// Builds the invoice PDF bytes for [order] ON-DEVICE. Safe to call
  /// repeatedly.
  static Future<Uint8List> build(Order order) async {
    await _ensureAssets();

    final doc = pw.Document(
      title: invoiceNo(order.id),
      author: 'VS Arogya Meda Pvt. Ltd.',
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(),
            pw.SizedBox(height: 10),
            pw.Divider(color: _border, thickness: 1),
            pw.SizedBox(height: 10),
            _billAndMeta(order),
            pw.SizedBox(height: 14),
            _itemsTable(order),
            pw.SizedBox(height: 12),
            _totals(order),
            pw.SizedBox(height: 10),
            _amountInWordsBar(order),
            pw.Spacer(),
            pw.SizedBox(height: 14),
            _footer(),
            pw.SizedBox(height: 10),
            _careBar(),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // --- sections --------------------------------------------------------------

  static pw.Widget _header() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 66,
          height: 66,
          child: pw.Image(_logo!, fit: pw.BoxFit.contain),
        ),
        pw.Spacer(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('VS Arogya Meda Pvt. Ltd.',
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGreen)),
            pw.SizedBox(height: 2),
            _rightLine('Flat D3, Block B, S K Residency, Bariatu Housing'),
            _rightLine('Colony, Ranchi, Jharkhand - 834009'),
            _rightLine('support@vsarogya.com'),
            _rightLine('DL No.: JH-RN7-153721/153722'),
            pw.Text('GST No.: 20AAJCV8843L1ZW',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGreen)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _rightLine(String s) => pw.Text(s,
      style: const pw.TextStyle(fontSize: 9, color: _grey),
      textAlign: pw.TextAlign.right);

  static pw.Widget _billAndMeta(Order order) {
    final a = order.address;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Bill-to box
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _green, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BILL TO',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _grey)),
                pw.SizedBox(height: 3),
                pw.Text(a.fullName.isNotEmpty ? a.fullName : a.label,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (a.phone.isNotEmpty)
                  pw.Text('Phone: ${a.phone}',
                      style: const pw.TextStyle(fontSize: 9.5, color: _grey)),
                pw.SizedBox(height: 2),
                pw.Text(a.formatted,
                    style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        // Meta box
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _lightGreen,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaRow('Invoice No', invoiceNo(order.id)),
                _metaRow('Invoice Date', _date(DateTime.now())),
                _metaRow('Order No', order.id),
                _metaRow('Order Date', _date(order.placedAt)),
                _metaRow(
                    'Payment',
                    order.paymentMethod == PaymentMethod.cod
                        ? 'Cash on Delivery'
                        : 'Online (Prepaid)'),
                _metaRow('Status', order.status.label),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 62,
            child: pw.Text('$label:',
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _grey)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 8.5, color: _ink)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable(Order order) {
    final headers = ['#', 'Description', 'Qty', 'Rate', 'Amount'];
    final rows = <List<String>>[
      for (var i = 0; i < order.items.length; i++)
        [
          '${i + 1}',
          order.items[i].title,
          '${order.items[i].quantity}',
          _money(order.items[i].price),
          _money(order.items[i].lineTotal),
        ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: _border, width: 0.5),
      headerStyle: pw.TextStyle(
          color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _green),
      headerHeight: 24,
      cellHeight: 22,
      cellStyle: const pw.TextStyle(fontSize: 9.5, color: _ink),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6FAF8)),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(26),
        1: const pw.FlexColumnWidth(5),
        2: const pw.FixedColumnWidth(38),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2.2),
      },
    );
  }

  static pw.Widget _totals(Order order) {
    pw.Widget row(String label, String value,
        {bool bold = false, PdfColor? valueColor}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: bold ? 12 : 10,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: bold ? _darkGreen : _grey)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: bold ? 12 : 10,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: valueColor ?? (bold ? _darkGreen : _ink))),
          ],
        ),
      );
    }

    return pw.Row(
      children: [
        pw.Spacer(flex: 3),
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                row('Subtotal', _money(order.subtotal)),
                if (order.discount > 0)
                  row('Discount', '- ${_money(order.discount)}',
                      valueColor: _green),
                row(
                    'Delivery',
                    order.deliveryFee == 0
                        ? 'FREE'
                        : _money(order.deliveryFee),
                    valueColor: order.deliveryFee == 0 ? _green : null),
                row('GST', _money(order.gst)),
                pw.Divider(color: _border, thickness: 0.5, height: 10),
                row('Total', _money(order.total), bold: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _amountInWordsBar(Order order) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _green,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Text(
              '${_amountInWords(order.total.round())} Rupees Only',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic),
            ),
          ),
          pw.Text('TOTAL: ${_money(order.total)}',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _footer() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Terms
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle('TERMS & CONDITIONS'),
              _term('Goods once sold will not be taken back or exchanged.'),
              _term(
                  'Lifesaving injections are returnable only if received 90+ days before expiry.'),
              _term('Payment in favour of "VS Arogya Meda Pvt. Ltd."'),
              _term('Subject to Ranchi jurisdiction only.'),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        // Bank
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle('BANK DETAILS'),
              _bank('Account Name', 'VS AROGYA MEDA PRIVATE LIMITED'),
              _bank('Bank', 'Indian Overseas Bank'),
              _bank('A/C No', '067233000000111'),
              _bank('IFSC', 'IOBA0000672'),
              _bank('Branch', 'Bariatu Road, Ranchi'),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        // Signature + QR
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                  width: 54,
                  height: 54,
                  child: pw.Image(_qr!, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 2),
              pw.Container(
                  width: 52,
                  height: 40,
                  child: pw.Image(_stamp!, fit: pw.BoxFit.contain)),
              pw.Text('For VS Arogya Meda Pvt. Ltd.',
                  style: pw.TextStyle(
                      fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
              pw.Text('Authorized Signatory',
                  style: const pw.TextStyle(fontSize: 7, color: _grey)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(s,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkGreen)),
      );

  static pw.Widget _term(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.5),
        child: pw.Text('-  $s',
            style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      );

  static pw.Widget _bank(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.5),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                  text: '$k: ',
                  style: pw.TextStyle(
                      fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(
                  text: v, style: const pw.TextStyle(fontSize: 7.5, color: _ink)),
            ],
          ),
        ),
      );

  static pw.Widget _careBar() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _green, width: 0.5)),
      ),
      child: pw.Text(
        'Customer Care: 0651-4502340  |  WhatsApp: 9430762051  |  This is a computer-generated invoice.',
        style: const pw.TextStyle(fontSize: 7.5, color: _grey),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // --- helpers ---------------------------------------------------------------

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  /// "Rs. 1,23,456.00" — Indian digit grouping, no ₹ glyph (avoids missing-font
  /// rendering issues in the PDF).
  static String _money(double value) {
    final neg = value < 0;
    final s = value.abs().toStringAsFixed(2);
    final dot = s.indexOf('.');
    final intPart = s.substring(0, dot);
    final dec = s.substring(dot);
    // Indian grouping: last 3 digits, then groups of 2.
    final buf = StringBuffer();
    final n = intPart.length;
    for (var i = 0; i < n; i++) {
      final fromEnd = n - i;
      if (i != 0 && (fromEnd == 3 || (fromEnd > 3 && (fromEnd - 3) % 2 == 0))) {
        buf.write(',');
      }
      buf.write(intPart[i]);
    }
    return '${neg ? '-' : ''}Rs. $buf$dec';
  }

  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty',
    'Ninety'
  ];

  static String _below100(int x) {
    if (x < 20) return _ones[x];
    final t = _tens[x ~/ 10];
    final o = x % 10;
    return o == 0 ? t : '$t ${_ones[o]}';
  }

  static String _below1000(int x) {
    if (x < 100) return _below100(x);
    final h = x ~/ 100;
    final rest = x % 100;
    return rest == 0
        ? '${_ones[h]} Hundred'
        : '${_ones[h]} Hundred ${_below100(rest)}';
  }

  /// Indian-format integer to words (up to crores).
  static String _amountInWords(int n) {
    if (n <= 0) return 'Zero';
    final parts = <String>[];
    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;
    if (crore > 0) parts.add('${_below100(crore)} Crore');
    if (lakh > 0) parts.add('${_below100(lakh)} Lakh');
    if (thousand > 0) parts.add('${_below100(thousand)} Thousand');
    if (n > 0) parts.add(_below1000(n));
    return parts.join(' ');
  }
}
