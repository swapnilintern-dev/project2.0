// =============================================================================
// VS Arogya — Marketing · Bulk product upload
//
// Pick an Excel/CSV sheet → upload → see exactly what went in and what did not.
//
// The server validates every row on its own, so a sheet of 500 medicines with
// 3 bad lines imports 497 and reports those 3. This screen is built around that
// outcome: the result is a BREAKDOWN, not a success/failure banner, because
// "partially imported" is the normal case and the user needs the row numbers to
// fix their sheet.
//
// Reached from the Marketing dashboard.
// =============================================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'bulk_upload_api.dart';
import 'marketing_controllers.dart';

/// The columns the server reads, in the order it expects to find them.
/// Shown in-app so the user does not have to guess the header names.
const _expectedColumns = <({String name, bool required, String note})>[
  (name: 'Title', required: true, note: 'Medicine name'),
  (name: 'Category', required: true, note: 'Medicine / Vaccines / …'),
  (name: 'Batch No', required: true, note: 'Must be unique'),
  (name: 'Selling Price', required: true, note: 'Number'),
  (name: 'MRP', required: false, note: 'Printed price'),
  (name: 'Brand', required: false, note: ''),
  (name: 'Code', required: false, note: 'SKU'),
  (name: 'Stock', required: false, note: 'Opening quantity'),
  (name: 'Expiry Date', required: false, note: 'e.g. 2027-06-30'),
  (name: 'Manufacturer', required: false, note: ''),
  (name: 'Marketed By', required: false, note: ''),
  (name: 'Pack Of', required: false, note: 'Units per pack'),
  (name: 'Pack Info', required: false, note: 'e.g. Strip of 15'),
  (name: 'HSN Code', required: false, note: ''),
  (name: 'GST Percent', required: false, note: ''),
  (name: 'Discount Percent', required: false, note: 'Everyone'),
  (name: 'DR_DIS_%', required: false, note: 'Hospital / clinic rate'),
  (name: 'Wholseller_%', required: false, note: 'Wholesale rate'),
  (name: 'Low Threshold', required: false, note: 'Reorder point'),
  (name: 'Prescription Required', required: false, note: 'yes / no'),
  (name: 'Cold Stored', required: false, note: ''),
  (name: 'Image URL', required: false, note: 'Comma-separated'),
  (name: 'Active', required: false, note: 'yes / no'),
  // Medicine information — shown under the name on the product page.
  (name: 'Composition', required: false, note: 'Salt + strength'),
  (name: 'Use of Product', required: false, note: 'or "Uses"'),
  (name: 'Storage', required: false, note: ''),
  (name: 'Side Effects', required: false, note: 'One per line, or a details sheet'),
  (name: 'Precautions', required: false, note: 'or a details sheet'),
  (name: 'Usage Direction', required: false, note: 'or a details sheet'),
];

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  PlatformFile? _file;
  bool _busy = false;
  BulkUploadResult? _result;

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        // The server reads req.file.buffer, and on web / Android scoped storage
        // a path may not be readable — take the bytes directly.
        withData: true,
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;
      setState(() {
        _file = picked.files.first;
        _result = null; // a new file invalidates the previous report
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Could not open the file picker. $e');
    }
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null) return;

    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Could not read that file. Please pick it again.');
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
    });

    final result = await const BulkUploadApi()
        .upload(bytes: bytes, filename: file.name);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });

    // Anything that actually landed changes the catalogue, so refresh the
    // shared inventory the rest of the role reads from.
    if (result.uploaded > 0) {
      MarketingProductsController.instance.refresh();
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyFailures() {
    final r = _result;
    if (r == null || r.failures.isEmpty) return;
    final text = r.failures
        .map((f) => '${f.label} → ${f.reason}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _snack('Rejected rows copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Bulk Upload'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _filePicker(),
          const SizedBox(height: 16),
          if (_result != null) ...[
            _resultCard(_result!),
            const SizedBox(height: 16),
          ],
          _columnsCard(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _filePicker() {
    final file = _file;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload a product sheet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Excel (.xlsx, .xls) or CSV. Each row is checked on its own — a bad '
            'row is skipped and reported, the rest still import.',
            style: TextStyle(fontSize: 12.5, color: AppColors.greyText),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _busy ? null : _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lighterGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: file == null ? AppColors.border : AppColors.primary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    file == null
                        ? Icons.upload_file_outlined
                        : Icons.description_outlined,
                    color: AppColors.darkGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file?.name ?? 'Choose a file',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        Text(
                          file == null
                              ? '.xlsx · .xls · .csv'
                              : _readableSize(file.size),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.greyText),
                        ),
                      ],
                    ),
                  ),
                  if (file != null && !_busy)
                    IconButton(
                      onPressed: () => setState(() {
                        _file = null;
                        _result = null;
                      }),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remove',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_file == null || _busy) ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 20),
              label: Text(_busy ? 'Uploading…' : 'Upload products'),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 10),
            const Text(
              'Large sheets can take a minute. Please keep this screen open.',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(BulkUploadResult r) {
    // Three outcomes, three treatments: a clean import, a partial one (the
    // common case), and a sheet the server refused outright.
    final (Color accent, IconData icon, String headline) = switch (r) {
      _ when !r.success => (
          AppColors.error,
          Icons.error_outline,
          'Upload failed',
        ),
      _ when r.isPartial => (
          const Color(0xFFF59E0B),
          Icons.warning_amber_rounded,
          'Partly imported',
        ),
      _ => (AppColors.primary, Icons.check_circle_outline, 'Imported'),
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Text(headline,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accent)),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.message,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.greyText)),
          if (r.success || r.totalRows > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _stat('Rows', r.totalRows, AppColors.darkText),
                _stat('Imported', r.uploaded, AppColors.darkGreen),
                _stat('Rejected', r.failed,
                    r.failed > 0 ? AppColors.error : AppColors.greyText),
              ],
            ),
          ],
          if (r.failures.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text('Rejected rows',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _copyFailures,
                  icon: const Icon(Icons.copy, size: 15),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Bounded so one very broken sheet can't produce an endless list.
            ...r.failures.take(50).map(_failureRow),
            if (r.failures.length > 50)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '…and ${r.failures.length - 50} more. Use Copy for the full list.',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.greyText),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _failureRow(BulkUploadFailure f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.remove_circle_outline,
                  size: 14, color: AppColors.error),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.label,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(f.reason,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.greyText)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _stat(String label, int value, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.greyText)),
          ],
        ),
      );

  Widget _columnsCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sheet columns',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text(
              'Header names must match exactly. Only the first four are required.',
              style: TextStyle(fontSize: 12, color: AppColors.greyText),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _expectedColumns.map((c) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.required
                        ? AppColors.lightGreenBg
                        : AppColors.pageBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          c.required ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.required ? '${c.name} *' : c.name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              c.required ? FontWeight.w800 : FontWeight.w600,
                          color: c.required
                              ? AppColors.darkGreen
                              : AppColors.darkText,
                        ),
                      ),
                      if (c.note.isNotEmpty)
                        Text(c.note,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.greyText)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  static String _readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
