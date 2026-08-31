// =============================================================================
// MediCaPlus — Marketing · Product media editor
//
// The premium media section of the Add / Edit Medicine form:
//   • Multiple product images (reorderable, first = primary) with camera /
//     multi-select gallery, per-image remove and a live "n / max" counter.
//   • One optional promotional video with pick → compress → preview, showing a
//     thumbnail, duration and file size, plus Replace / Remove.
//
// All selection state lives in [ProductMediaController] (a ChangeNotifier) so
// the host screen stays declarative: it reads `keptImages` / `newImageFiles` /
// `videoToUpload` / `removeVideo` at save time and passes them straight to the
// controller layer. No API/business logic lives in the widgets.
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

import '../services/product_media.dart';
import '../theme/video_player_view.dart';
import '../vendor_registration_screen.dart' show AppColors;
import 'marketing_models.dart';

/// One image slot in the editor: either an already-uploaded [ProductMedia]
/// (carrying its Cloudinary publicId) or a freshly picked local [XFile].
class ProductImageEntry {
  ProductImageEntry.existing(ProductMedia media)
      : existing = media,
        file = null;
  ProductImageEntry.file(XFile f)
      : existing = null,
        file = f;

  final ProductMedia? existing;
  final XFile? file;

  bool get isExisting => existing != null;

  /// Stable key for the ReorderableListView.
  Key get key => ValueKey(existing?.publicId ?? existing?.url ?? file!.path);
}

/// Holds the editor's media selection and exposes what the save call needs.
class ProductMediaController extends ChangeNotifier {
  ProductMediaController({InventoryProduct? existing}) {
    if (existing != null) {
      _images.addAll(existing.images.map(ProductImageEntry.existing));
      _existingVideo = existing.video;
    }
  }

  final List<ProductImageEntry> _images = [];
  ProductMedia? _existingVideo;
  XFile? _newVideo;
  bool _videoRemoved = false;

  // --- images --------------------------------------------------------------

  List<ProductImageEntry> get images => List.unmodifiable(_images);
  int get imageCount => _images.length;
  bool get hasImages => _images.isNotEmpty;
  bool get canAddImages => _images.length < kMaxProductImages;
  int get remainingSlots => kMaxProductImages - _images.length;

  /// Adds picked image [files] (dropping any past the max and any with an
  /// unsupported extension). Returns a user-facing note when some were skipped.
  String? addImages(List<XFile> files) {
    if (files.isEmpty) return null;
    var skippedType = 0;
    var skippedFull = 0;
    for (final f in files) {
      if (_images.length >= kMaxProductImages) {
        skippedFull++;
        continue;
      }
      if (!_isAllowedImage(f)) {
        skippedType++;
        continue;
      }
      _images.add(ProductImageEntry.file(f));
    }
    notifyListeners();
    if (skippedFull > 0) {
      return 'Up to $kMaxProductImages images — $skippedFull extra skipped';
    }
    if (skippedType > 0) {
      return '$skippedType file(s) skipped — use jpg, jpeg, png or webp';
    }
    return null;
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= _images.length) return;
    _images.removeAt(index);
    notifyListeners();
  }

  // newIndex arrives pre-adjusted (onReorderItem semantics) — it is already
  // the destination slot after the dragged item is removed from oldIndex.
  void reorderImage(int oldIndex, int newIndex) {
    final entry = _images.removeAt(oldIndex);
    _images.insert(newIndex, entry);
    notifyListeners();
  }

  // --- video ---------------------------------------------------------------

  /// The picked-but-not-uploaded video (shows a local preview), or null.
  XFile? get pickedVideo => _newVideo;

  /// The existing uploaded video still in effect (network preview), or null.
  ProductMedia? get shownExistingVideo =>
      (_existingVideo != null && !_videoRemoved && _newVideo == null)
          ? _existingVideo
          : null;

  bool get hasVideo => shownExistingVideo != null || _newVideo != null;

  void setVideo(XFile file) {
    _newVideo = file;
    _videoRemoved = false;
    notifyListeners();
  }

  void removeVideoSelection() {
    _newVideo = null;
    // Only flag removal of the persisted one if there was one to begin with.
    _videoRemoved = _existingVideo != null;
    notifyListeners();
  }

  // --- save-time projection -------------------------------------------------

  /// Existing images the edit is keeping, in display order (backend deletes the
  /// rest).
  List<ProductMedia> get keptImages =>
      _images.where((e) => e.isExisting).map((e) => e.existing!).toList();

  /// Newly picked image files, in order (appended after the kept ones).
  List<XFile> get newImageFiles =>
      _images.where((e) => !e.isExisting).map((e) => e.file!).toList();

  /// The video file to upload (replace/add), or null.
  XFile? get videoToUpload => _newVideo;

  /// True when the persisted video should be deleted with no replacement.
  bool get removeVideo =>
      _existingVideo != null && _videoRemoved && _newVideo == null;

  static bool _isAllowedImage(XFile f) {
    final ext = f.name.toLowerCase().split('.').last;
    // Some gallery picks lack an extension in the name; fall back to allow.
    if (!f.name.contains('.')) return true;
    return kAllowedImageExt.contains(ext);
  }
}

/// The media section widget. Renders [controller] and mutates it via the picker.
class ProductMediaEditor extends StatefulWidget {
  const ProductMediaEditor({super.key, required this.controller});

  final ProductMediaController controller;

  @override
  State<ProductMediaEditor> createState() => _ProductMediaEditorState();
}

class _ProductMediaEditorState extends State<ProductMediaEditor> {
  final ImagePicker _picker = ImagePicker();

  // Derived metadata for the freshly picked video (null for existing/network).
  Uint8List? _videoThumb;
  Duration? _videoDuration;
  int? _videoBytes;
  bool _processingVideo = false;
  String? _lastProcessedVideoPath;

  ProductMediaController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    // When the picked video changes, (re)compute its thumbnail + info.
    final v = _c.pickedVideo;
    if (v == null) {
      if (_videoThumb != null || _videoDuration != null) {
        setState(() {
          _videoThumb = null;
          _videoDuration = null;
          _videoBytes = null;
        });
      }
    } else if (v.path != _lastProcessedVideoPath) {
      _processVideo(v);
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Image picking
  // ---------------------------------------------------------------------------

  Future<void> _addFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        limit: _c.remainingSlots,
      );
      if (files.isEmpty) return;
      final note = _c.addImages(files);
      if (note != null && mounted) _snack(note, ok: false);
    } catch (_) {
      if (mounted) _snack('Could not open the gallery', ok: false);
    }
  }

  Future<void> _addFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final note = _c.addImages([file]);
      if (note != null && mounted) _snack(note, ok: false);
    } catch (_) {
      if (mounted) _snack('Could not open the camera', ok: false);
    }
  }

  void _showAddImageSheet() {
    if (!_c.canAddImages) {
      _snack('You already have the maximum of $kMaxProductImages images',
          ok: false);
      return;
    }
    _showSourceSheet(
      title: 'Add Images',
      onCamera: _addFromCamera,
      onGallery: _addFromGallery,
      galleryLabel: 'Choose from Gallery (multi-select)',
    );
  }

  // ---------------------------------------------------------------------------
  // Video picking + processing
  // ---------------------------------------------------------------------------

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (file == null) return;

      // Extension guard (server re-validates).
      final ext = file.name.toLowerCase().split('.').last;
      if (file.name.contains('.') && !kAllowedVideoExt.contains(ext)) {
        if (mounted) _snack('Video must be mp4, mov, mkv or webm', ok: false);
        return;
      }
      // Size guard before any (optional) compression.
      final rawBytes = await file.length();
      if (rawBytes > kMaxVideoBytes) {
        if (mounted) {
          _snack('Video is ${_fmtSize(rawBytes)} — max ${_fmtSize(kMaxVideoBytes)}',
              ok: false);
        }
        return;
      }
      _c.setVideo(file);
    } catch (_) {
      if (mounted) _snack('Could not pick the video', ok: false);
    }
  }

  void _showAddVideoSheet() {
    _showSourceSheet(
      title: 'Product Video',
      onCamera: () => _pickVideo(ImageSource.camera),
      onGallery: () => _pickVideo(ImageSource.gallery),
      galleryLabel: 'Choose from Gallery',
    );
  }

  /// Compresses (best-effort) the picked video and extracts thumbnail +
  /// duration + size. Compression failures fall back to the original file.
  Future<void> _processVideo(XFile file) async {
    _lastProcessedVideoPath = file.path;
    setState(() {
      _processingVideo = true;
      _videoThumb = null;
      _videoDuration = null;
      _videoBytes = null;
    });

    // Web has no native compressor — just read size and skip thumbnail.
    if (kIsWeb) {
      final bytes = await file.length();
      if (!mounted) return;
      setState(() {
        _processingVideo = false;
        _videoBytes = bytes;
      });
      return;
    }

    try {
      // 1) Compress to a medium quality to keep the upload light. On any
      //    failure we keep the original file the controller already holds.
      MediaInfo? compressed;
      try {
        compressed = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
      } catch (_) {
        compressed = null;
      }

      final effectivePath = compressed?.file?.path ?? file.path;
      if (compressed?.file != null) {
        // Guard BEFORE swapping so the resulting notify doesn't re-process.
        _lastProcessedVideoPath = effectivePath;
        // Swap in the smaller file for upload.
        _c.setVideo(XFile(effectivePath));
      }

      final info = await VideoCompress.getMediaInfo(effectivePath);
      final thumb = await VideoCompress.getByteThumbnail(
        effectivePath,
        quality: 60,
        position: -1,
      );

      if (!mounted) return;
      setState(() {
        _processingVideo = false;
        _videoThumb = thumb;
        _videoBytes = info.filesize ?? compressed?.filesize;
        final ms = info.duration ?? 0;
        _videoDuration = Duration(milliseconds: ms.round());
      });
    } catch (_) {
      // Fall back to just the raw size so the UI still shows something useful.
      final bytes = await file.length();
      if (!mounted) return;
      setState(() {
        _processingVideo = false;
        _videoBytes = bytes;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _imagesSection(),
        const SizedBox(height: 16),
        _videoSection(),
      ],
    );
  }

  Widget _imagesSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionRow(
            icon: Icons.photo_library_outlined,
            title: 'Product Images',
            trailing: Text('${_c.imageCount} / $kMaxProductImages',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _c.imageCount == 0
                        ? AppColors.error
                        : AppColors.darkGreen)),
          ),
          const SizedBox(height: 4),
          const Text('First image is the primary. Drag to reorder.',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
          const SizedBox(height: 12),
          if (_c.images.isEmpty)
            _emptyImages()
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _c.images.length,
              onReorderItem: _c.reorderImage,
              itemBuilder: (context, i) => _imageRow(i, key: _c.images[i].key),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _c.canAddImages ? _showAddImageSheet : null,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
              label: Text(_c.images.isEmpty ? 'Add Images' : 'Add More Images'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageRow(int index, {required Key key}) {
    final entry = _c.images[index];
    final isPrimary = index == 0;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPrimary ? AppColors.primary : AppColors.border,
            width: isPrimary ? 1.4 : 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 54,
              height: 54,
              child: _imageThumb(entry),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image ${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppColors.darkText)),
                const SizedBox(height: 3),
                if (isPrimary)
                  _pill('PRIMARY', AppColors.primary)
                else
                  Text(entry.isExisting ? 'Uploaded' : 'New',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.greyText)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _c.removeImageAt(index),
            icon: const Icon(Icons.close, size: 20, color: AppColors.error),
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 2, right: 4),
              child: Icon(Icons.drag_handle, color: AppColors.greyText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageThumb(ProductImageEntry entry) {
    if (entry.isExisting) {
      return Image.network(entry.existing!.url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _thumbFallback());
    }
    return FutureBuilder<Uint8List>(
      future: entry.file!.readAsBytes(),
      builder: (context, snap) => snap.hasData
          ? Image.memory(snap.data!, fit: BoxFit.cover)
          : _thumbFallback(),
    );
  }

  Widget _thumbFallback() => Container(
        color: AppColors.lightGreenBg,
        child: const Icon(Icons.image_outlined,
            color: AppColors.greyText, size: 22),
      );

  Widget _emptyImages() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 40, color: AppColors.greyText),
          SizedBox(height: 8),
          Text('No images yet',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
          SizedBox(height: 2),
          Text('At least one image is required',
              style: TextStyle(fontSize: 11.5, color: AppColors.greyText)),
        ],
      ),
    );
  }

  // --- video UI --------------------------------------------------------------

  Widget _videoSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionRow(
            icon: Icons.movie_creation_outlined,
            title: 'Product Video',
            trailing: Text('Optional · max ${_fmtSize(kMaxVideoBytes)}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.greyText)),
          ),
          const SizedBox(height: 12),
          if (!_c.hasVideo)
            _emptyVideo()
          else
            _videoPreview(),
        ],
      ),
    );
  }

  Widget _emptyVideo() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showAddVideoSheet,
        icon: const Icon(Icons.video_call_outlined, size: 20),
        label: const Text('Upload Video'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkGreen,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _videoPreview() {
    final picked = _c.pickedVideo;
    final existing = _c.shownExistingVideo;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: _processingVideo ? null : _openVideoFull,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (picked != null && _videoThumb != null)
                    Image.memory(_videoThumb!, fit: BoxFit.cover)
                  else
                    Container(color: Colors.black12),
                  Container(color: Colors.black.withValues(alpha: 0.15)),
                  if (_processingVideo)
                    const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                  else
                    const Center(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.black45,
                        child: Icon(Icons.play_arrow,
                            color: Colors.white, size: 34),
                      ),
                    ),
                  if (existing != null)
                    const Positioned(
                      left: 8,
                      top: 8,
                      child: _MiniTag(text: 'Current video'),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.videocam_outlined,
                size: 16, color: AppColors.greyText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _processingVideo
                    ? 'Processing video…'
                    : _videoMetaLine(),
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.greyText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processingVideo ? null : _showAddVideoSheet,
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('Replace'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkGreen),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _processingVideo ? null : _c.removeVideoSelection,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _videoMetaLine() {
    final parts = <String>[];
    if (_videoDuration != null) parts.add(_fmtDuration(_videoDuration!));
    if (_videoBytes != null) parts.add(_fmtSize(_videoBytes!));
    if (parts.isEmpty) {
      return _c.shownExistingVideo != null
          ? 'Tap to preview the current video'
          : 'Ready to upload';
    }
    return parts.join('  ·  ');
  }

  void _openVideoFull() {
    final picked = _c.pickedVideo;
    final existing = _c.shownExistingVideo;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(
        filePath: picked?.path,
        networkUrl: picked == null ? existing?.url : null,
        title: 'Product Video',
      ),
    ));
  }

  // --- shared bits -----------------------------------------------------------

  void _showSourceSheet({
    required String title,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required String galleryLabel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary),
              title: const Text('Take with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                onCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: Text(galleryLabel),
              onTap: () {
                Navigator.pop(ctx);
                onGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionRow(
      {required IconData icon, required String title, Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText)),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );

  void _snack(String message, {bool ok = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppColors.darkGreen : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  static String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Small overlay tag used on the video preview.
class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
      );
}
