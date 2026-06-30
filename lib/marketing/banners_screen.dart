// =============================================================================
// MediCaPlus — Marketing Head · Promo Banners
//
// Create / delete the promotional banners shown on the customer home carousel.
// Backed by the backend (GET/POST/DELETE /promo-banners) via
// MarketingBannersController, so changes appear in the customer app.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../customer/customer_models.dart' show PromoBanner;
import '../customer/customer_widgets.dart' show showAppSnack, EmptyState;
import 'marketing_controllers.dart';

/// A selectable gradient preset (start -> end) for a banner.
class _Gradient {
  const _Gradient(this.name, this.start, this.end);
  final String name;
  final Color start;
  final Color end;
}

const List<_Gradient> _presets = [
  _Gradient('Green', Color(0xFF4CAF82), Color(0xFF2E7D5E)),
  _Gradient('Blue', Color(0xFF3B82F6), Color(0xFF1D4ED8)),
  _Gradient('Purple', Color(0xFF8B5CF6), Color(0xFF6D28D9)),
  _Gradient('Amber', Color(0xFFF59E0B), Color(0xFFD97706)),
  _Gradient('Red', Color(0xFFEF4444), Color(0xFFB91C1C)),
];

/// Category options (label -> id); null id = no deep link ("All").
const Map<String, String?> _bannerCategories = {
  'All': null,
  'Medicine': 'medicine',
  'Vaccines': 'vaccines',
  'Lifesaving Injections': 'injections',
};

class MarketingBannersScreen extends StatefulWidget {
  const MarketingBannersScreen({super.key});

  @override
  State<MarketingBannersScreen> createState() => _MarketingBannersScreenState();
}

class _MarketingBannersScreenState extends State<MarketingBannersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _tag = TextEditingController(text: 'OFFER');
  final _cta = TextEditingController(text: 'Shop Now');

  int _preset = 0;
  String _category = 'All';
  bool _saving = false;

  MarketingBannersController get _controller =>
      MarketingBannersController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _title.dispose();
    _tag.dispose();
    _cta.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final g = _presets[_preset];
    final banner = PromoBanner(
      id: '',
      tag: _tag.text.trim().isEmpty ? 'OFFER' : _tag.text.trim(),
      title: _title.text.trim(),
      ctaLabel: _cta.text.trim().isEmpty ? 'Shop Now' : _cta.text.trim(),
      startColor: g.start,
      endColor: g.end,
      categoryId: _bannerCategories[_category],
    );
    final ok = await _controller.add(banner);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _title.clear();
      showAppSnack(context, 'Banner published');
    } else {
      showAppSnack(context, 'Could not publish banner. Try again.',
          success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Promo Banners',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final banners = _controller.banners;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _previewCard(),
              const SizedBox(height: 16),
              _formCard(),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Text('Live Banners',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (_controller.loading)
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 10),
              if (banners.isEmpty && !_controller.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.view_carousel_outlined,
                    title: 'No banners yet',
                    message: 'Publish a banner above to show it on the '
                        'customer home screen.',
                  ),
                )
              else
                for (final b in banners) _liveBanner(b),
            ],
          );
        },
      ),
    );
  }

  /// Live preview of what the form will produce.
  Widget _previewCard() {
    final g = _presets[_preset];
    return _bannerVisual(
      tag: _tag.text.trim().isEmpty ? 'OFFER' : _tag.text.trim(),
      title: _title.text.trim().isEmpty ? 'Your banner title' : _title.text.trim(),
      cta: _cta.text.trim().isEmpty ? 'Shop Now' : _cta.text.trim(),
      start: g.start,
      end: g.end,
    );
  }

  Widget _formCard() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Banner',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              decoration: _dec('Banner title', 'e.g. Flat 20% OFF above ₹5,000'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tag,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('Tag', 'BULK OFFER'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _cta,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('Button label', 'Shop Now'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Colour',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (int i = 0; i < _presets.length; i++) _swatch(i),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Links to category (optional)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              items: [
                for (final c in _bannerCategories.keys)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: _dec(null, null),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _add,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.publish_outlined),
                label: Text(_saving ? 'Publishing…' : 'Publish Banner',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(int i) {
    final g = _presets[i];
    final selected = _preset == i;
    return GestureDetector(
      onTap: () => setState(() => _preset = i),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [g.start, g.end]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.darkText : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _liveBanner(PromoBanner b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          _bannerVisual(
            tag: b.tag,
            title: b.title,
            cta: b.ctaLabel,
            start: b.startColor,
            end: b.endColor,
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.25),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 20),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(b),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(PromoBanner b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete banner?'),
        content: Text('"${b.title}" will be removed from the customer app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    final done = await _controller.remove(b.id);
    if (!mounted) return;
    showAppSnack(context, done ? 'Banner deleted' : 'Could not delete banner',
        success: done);
  }

  Widget _bannerVisual({
    required String tag,
    required String title,
    required String cta,
    required Color start,
    required Color end,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tag,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(cta,
                style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String? label, String? hint) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelStyle: const TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
      filled: true,
      fillColor: AppColors.pageBg,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
    );
  }
}
