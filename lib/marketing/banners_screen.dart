// =============================================================================
// MediCaPlus — Marketing Head · Promo Banners
//
// Upload / delete the promotional banners shown on the customer home carousel.
// Banners are IMAGE-first: the marketing team picks a creative which is uploaded
// to the backend (POST /promo-banners, Cloudinary) and appears live on the
// customer app. Older image-less (gradient) banners still render in the list.
// Live via MarketingBannersController (GET/POST/DELETE /promo-banners).
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../theme/app_theme.dart' show AppShadows;
import '../services/live_refresh.dart';
import '../customer/customer_models.dart' show PromoBanner;
import '../customer/customer_widgets.dart' show showAppSnack, EmptyState;
import 'marketing_controllers.dart';

/// Optional deep-link target for a banner (label -> category id; null = no link).
const Map<String, String?> _bannerCategories = {
  'No link': null,
  'Medicine': 'medicine',
  'Vaccines': 'vaccines',
  'Lifesaving Injections': 'injections',
};

/// The aspect ratio the customer carousel crops to. Kept here so the marketing
/// preview shows the EXACT crop the customer will see (works on iOS + Android).
const double _bannerAspect = 1080 / 450;

class MarketingBannersScreen extends StatefulWidget {
  const MarketingBannersScreen({super.key});

  @override
  State<MarketingBannersScreen> createState() => _MarketingBannersScreenState();
}

class _MarketingBannersScreenState extends State<MarketingBannersScreen>
    with LiveRefreshMixin {
  final ImagePicker _picker = ImagePicker();
  final _nameCtrl = TextEditingController();

  XFile? _image;
  Uint8List? _preview; // decoded bytes for the on-screen preview (web + mobile)
  String _category = _bannerCategories.keys.first;
  bool _saving = false;

  MarketingBannersController get _controller =>
      MarketingBannersController.instance;

  @override
  void initState() {
    super.initState();
    // Fetch on open + keep the live list in sync (poll + app-resume).
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _controller.refresh();

  /// Picks a banner creative from the gallery and decodes a preview.
  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = picked;
        _preview = bytes;
      });
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not open the gallery. Try again.',
            success: false);
      }
    }
  }

  Future<void> _publish() async {
    if (_image == null) {
      showAppSnack(context, 'Pick a banner image first', success: false);
      return;
    }
    setState(() => _saving = true);
    final banner = PromoBanner(
      id: '',
      tag: 'OFFER',
      // Stored for identification in the list / delete dialog (not shown on the
      // full-image banner). Falls back to a generic name.
      title: _nameCtrl.text.trim().isEmpty ? 'Banner' : _nameCtrl.text.trim(),
      categoryId: _bannerCategories[_category],
    );
    final ok = await _controller.add(banner, _image!);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      setState(() {
        _image = null;
        _preview = null;
        _nameCtrl.clear();
        _category = _bannerCategories.keys.first;
      });
      showAppSnack(context, 'Banner published — live on the app 🎉');
    } else {
      showAppSnack(context,
          'Could not publish banner. Check your connection and try again.',
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
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _uploadCard(),
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
                    const Spacer(),
                    Text('${banners.length} live',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greyText)),
                  ],
                ),
                const SizedBox(height: 10),
                if (banners.isEmpty && !_controller.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.view_carousel_outlined,
                      title: 'No banners yet',
                      message: 'Upload a creative above to show it on the '
                          'customer home screen.',
                    ),
                  )
                else
                  for (final b in banners) _liveBanner(b),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- upload form ---------------------------------------------------------

  Widget _uploadCard() {
    return Container(
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
          const SizedBox(height: 4),
          const Text('Upload a custom creative — it appears on the customer '
              'home carousel.',
              style: TextStyle(fontSize: 12, color: AppColors.greyText)),
          const SizedBox(height: 12),
          _imagePicker(),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: _dec('Banner name (optional)', 'e.g. Diwali Sale'),
          ),
          const SizedBox(height: 12),
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
              onPressed: (_saving || _image == null) ? null : _publish,
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
                disabledBackgroundColor: AppColors.border,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tap-to-pick creative card that previews the EXACT customer crop.
  Widget _imagePicker() {
    return GestureDetector(
      onTap: _saving ? null : _pickImage,
      child: AspectRatio(
        aspectRatio: _bannerAspect,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.lightGreenBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: _preview == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 30, color: AppColors.greyText),
                    SizedBox(height: 8),
                    Text('Tap to upload banner creative',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText)),
                    SizedBox(height: 2),
                    Text('Recommended 1080×450 · JPG / PNG',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.greyText)),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_preview!, fit: BoxFit.cover),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _saving ? null : _pickImage,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child:
                                Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // --- live list -----------------------------------------------------------

  Widget _liveBanner(PromoBanner b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          if (b.hasImage)
            _bannerImageVisual(b)
          else
            _bannerVisual(b),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
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
        content: Text(
            '"${b.title.isEmpty ? 'This banner' : b.title}" will be removed from the customer app.'),
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

  /// Image-backed banner preview (same crop the customer sees).
  Widget _bannerImageVisual(PromoBanner b) {
    return AspectRatio(
      aspectRatio: _bannerAspect,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: b.startColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Image.network(
          b.imageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(Icons.image_not_supported_outlined,
                color: Colors.white70, size: 36),
          ),
        ),
      ),
    );
  }

  /// Fallback render for legacy image-less (gradient + text) banners.
  Widget _bannerVisual(PromoBanner b) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [b.startColor, b.endColor],
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
            child: Text(b.tag,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 8),
          Text(b.title,
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
            child: Text(b.ctaLabel,
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
    );
  }
}
