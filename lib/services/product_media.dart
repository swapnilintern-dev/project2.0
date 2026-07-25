// =============================================================================
// MediCaPlus — Product media model (shared)
//
// One stored media asset (image or promotional video) on a product. Used by
// both the marketing inventory model and the customer catalogue model so the
// backend media structure has a single source of truth.
//
// Backend shape (server/model/productModel.js):
//   image: [ { url, publicId }, … ]   ← ordered; image[0] is the primary
//   video: { url, publicId }          ← optional, single
//
// `publicId` (the Cloudinary id) is carried through so the Edit flow can tell
// the backend exactly which existing assets to keep vs. delete — that is how
// edits stay orphan-free.
// =============================================================================

import 'dart:convert';

/// The maximum number of images a product may carry. Mirrors the backend
/// `MAX_PRODUCT_IMAGES`. No hard-coded limit lives inside the picker logic —
/// everything reads this constant.
const int kMaxProductImages = 10;

/// The maximum promotional-video size accepted (mirrors backend MAX_VIDEO_BYTES).
const int kMaxVideoBytes = 100 * 1024 * 1024; // 100 MB

/// The maximum single image size accepted (mirrors backend MAX_IMAGE_BYTES).
const int kMaxImageBytes = 10 * 1024 * 1024; // 10 MB

/// Allowed image extensions (client-side guard; the server re-validates).
const Set<String> kAllowedImageExt = {'jpg', 'jpeg', 'png', 'webp'};

/// Allowed video extensions (client-side guard; the server re-validates).
const Set<String> kAllowedVideoExt = {'mp4', 'mov', 'mkv', 'webm'};

/// A single stored media asset (image or video) already uploaded to the backend.
class ProductMedia {
  const ProductMedia({required this.url, this.publicId});

  final String url;
  final String? publicId;

  bool get isValid => url.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'url': url,
        if (publicId != null) 'publicId': publicId,
      };

  factory ProductMedia.fromJson(Map<dynamic, dynamic> j) => ProductMedia(
        url: (j['url'] ?? '').toString(),
        publicId: j['publicId']?.toString(),
      );

  /// Parses a backend product's `image` field (array of `{url, publicId}`; also
  /// tolerates a bare string or a list of strings) into an ordered list.
  static List<ProductMedia> parseImages(Object? raw) {
    final out = <ProductMedia>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map && (e['url'] ?? '').toString().isNotEmpty) {
          out.add(ProductMedia.fromJson(e));
        } else if (e is String && e.isNotEmpty) {
          out.add(ProductMedia(url: e));
        }
      }
    } else if (raw is Map && (raw['url'] ?? '').toString().isNotEmpty) {
      out.add(ProductMedia.fromJson(raw));
    } else if (raw is String && raw.isNotEmpty) {
      out.add(ProductMedia(url: raw));
    }
    return out;
  }

  /// Parses the backend `video` field (`{url, publicId}`) into a [ProductMedia],
  /// or null when absent / empty.
  static ProductMedia? parseVideo(Object? raw) {
    if (raw is Map) {
      final url = (raw['url'] ?? '').toString();
      if (url.isNotEmpty) return ProductMedia.fromJson(raw);
    } else if (raw is String && raw.isNotEmpty) {
      return ProductMedia(url: raw);
    }
    return null;
  }

  /// Encodes a kept-images list for the update multipart `keptImages` field —
  /// the ordered set of existing images the edit is retaining.
  static String encodeKept(List<ProductMedia> images) => jsonEncode(
        images.map((m) => {'url': m.url, 'publicId': m.publicId}).toList(),
      );
}
