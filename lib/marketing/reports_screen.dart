// =============================================================================
// MediCaPlus — Marketing Head · Reports screen
//
// Reached from the "Reports" card on the Marketing dashboard. The marketing
// head picks a report and taps Generate — the app downloads the ready-made
// Excel file from the backend and opens the native share sheet, so the
// spreadsheet can be sent over WhatsApp / email / Drive or saved to Files.
//
// LIVE endpoints (server/routes/xlshRoute.js — server NOT modified):
//   • Order Report  → GET /vsArogya/order-report   (.xlsx, all orders)
//   • Vendor Report → GET /vsArogya/vendor-report  (.xlsx, all vendors)
//
// Stock Report has no backend endpoint yet, so its card is marked "Coming
// soon" and Generate explains that instead of failing.
//
// The server exports the FULL table (it takes no date/format parameters), so
// this screen deliberately has no date-range or CSV options — they can be
// added back the day the backend supports them.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../theme/app_widgets.dart' show shareOriginFor;
import 'marketing_api.dart' show MarketingReportsApi;
import 'marketing_models.dart' show MarketingColors;

/// The three reports the marketing head can generate.
enum ReportType { vendor, stock, order }

class MarketingReportsScreen extends StatefulWidget {
  const MarketingReportsScreen({super.key});

  @override
  State<MarketingReportsScreen> createState() => _MarketingReportsScreenState();
}

class _MarketingReportsScreenState extends State<MarketingReportsScreen> {
  final MarketingReportsApi _api = MarketingReportsApi();

  /// Which report card is currently selected (null = nothing picked yet).
  ReportType? _selected;

  /// True while the report is being downloaded from the server.
  bool _generating = false;

  // ---------------------------------------------------------------------------
  // Static card copy for each report type. `path` is the backend endpoint;
  // null means the endpoint doesn't exist yet (Stock).
  // ---------------------------------------------------------------------------

  static const _cards = [
    (
      type: ReportType.vendor,
      icon: Icons.storefront_outlined,
      color: AppColors.primary,
      title: 'Vendor Report',
      subtitle: 'Every registered vendor with contact person, phone & address',
      path: '/vsArogya/vendor-report',
    ),
    (
      type: ReportType.stock,
      icon: Icons.inventory_2_outlined,
      color: MarketingColors.orange,
      title: 'Stock Report',
      subtitle: 'Current stock of every product with low / out-of-stock flags',
      path: null, // no backend endpoint yet → "Coming soon"
    ),
    (
      type: ReportType.order,
      icon: Icons.receipt_long_outlined,
      color: MarketingColors.blue,
      title: 'Order Report',
      subtitle: 'Every order with vendor, amount, status & date',
      path: '/vsArogya/order-report',
    ),
  ];

  String get _selectedTitle => switch (_selected) {
        ReportType.vendor => 'Vendor Report',
        ReportType.stock => 'Stock Report',
        ReportType.order => 'Order Report',
        null => 'Report',
      };

  /// Backend path for the selected report, or null when it has none (Stock).
  String? get _selectedPath =>
      _cards.firstWhere((c) => c.type == _selected).path;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Downloads the selected report from the backend and opens the native
  /// share sheet with the .xlsx file, so it can be sent or saved anywhere.
  Future<void> _generate() async {
    final path = _selectedPath;

    // Stock has no server endpoint yet — explain instead of failing.
    if (path == null) {
      _showComingSoonSheet();
      return;
    }

    setState(() => _generating = true);
    final (bytes, error) = await _api.downloadExcel(path);
    if (!mounted) return;
    setState(() => _generating = false);

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Could not generate the report.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    await _shareExcel(bytes);
  }

  /// Opens the system share sheet with the downloaded spreadsheet.
  Future<void> _shareExcel(Uint8List bytes) async {
    final now = DateTime.now();
    final stamp = '${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-${now.year}';
    final fileName =
        '${_selectedTitle.toLowerCase().replaceAll(' ', '_')}_$stamp.xlsx';

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      // Guarantees the receiving app sees a proper "….xlsx" filename.
      fileNameOverrides: [fileName],
      subject: '$_selectedTitle — VS Arogya Meda',
      sharePositionOrigin: shareOriginFor(context),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$_selectedTitle ready — $fileName'),
      backgroundColor: AppColors.darkGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Shown for the Stock report until its backend endpoint exists.
  void _showComingSoonSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.lightGreenBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.darkGreen, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Stock Report — coming soon',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            const Text(
              'The stock export is not available on the server yet. '
              'Vendor and Order reports are live — pick one of those to '
              'download a shareable Excel file right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.greyText, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK, got it',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
        title: const Text('Reports',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _infoBanner(),
          const SizedBox(height: 18),
          _sectionLabel('CHOOSE A REPORT'),
          const SizedBox(height: 10),
          for (final c in _cards) ...[
            _ReportCard(
              icon: c.icon,
              color: c.color,
              title: c.title,
              subtitle: c.subtitle,
              comingSoon: c.path == null,
              selected: _selected == c.type,
              onTap: () => setState(() => _selected = c.type),
            ),
            const SizedBox(height: 10),
          ],
          if (_selected != null) ...[
            const SizedBox(height: 8),
            _sectionLabel('FILE'),
            const SizedBox(height: 10),
            _fileInfoRow(),
          ],
        ],
      ),

      // Generate button pinned at the bottom, enabled once a report is picked.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _selected == null || _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              _generating
                  ? 'Generating…'
                  : _selected == null
                      ? 'Select a report'
                      : 'Generate $_selectedTitle',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  /// Small green banner telling the user what this screen produces.
  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lighterGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.table_view_outlined,
              color: AppColors.darkGreen, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Generate Excel reports of vendors and orders — downloaded '
              'live from the server, ready to share or archive.',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.darkGreen, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.greyText));
  }

  /// Static row showing what will be produced — the server exports Excel
  /// (.xlsx) only, so there is nothing to choose here.
  Widget _fileInfoRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.grid_on_rounded, color: AppColors.darkGreen, size: 18),
          SizedBox(width: 8),
          Text('Excel spreadsheet (.xlsx)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText)),
          Spacer(),
          Icon(Icons.ios_share_rounded, color: AppColors.greyText, size: 16),
          SizedBox(width: 4),
          Text('Shareable',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

/// One selectable report card (Vendor / Stock / Order). The selected card gets
/// a green border + check badge; cards without a backend endpoint yet carry an
/// amber "Coming soon" badge.
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.comingSoon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool comingSoon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.lighterGreen : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkText)),
                      ),
                      if (comingSoon) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                MarketingColors.orange.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Coming soon',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: MarketingColors.orange)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.greyText,
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
