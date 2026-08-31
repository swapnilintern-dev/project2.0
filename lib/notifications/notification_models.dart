// =============================================================================
// MediCaPlus — Notification Models
//
// Mirrors the backend contract in server/controller/notificationController.js.
// Two shapes, because the two roles see two different things:
//
//   AppNotification  — a VENDOR's notification-center row (a receipt joined
//                      with its campaign): carries read/opened state.
//   Campaign         — a MARKETING campaign with its delivery analytics.
//
// Both parse defensively: a missing or differently-typed field falls back to a
// safe empty value rather than throwing, so one odd document can never break
// the whole list.
// =============================================================================

import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Vocabularies — kept in lockstep with the schema enums (notificationModel.js).
// The composer refreshes them from GET /notifications/meta at runtime; these are
// the compile-time defaults so the UI is never empty.
// -----------------------------------------------------------------------------

const List<String> kNotificationCategories = [
  'New Medicine',
  'Stock Update',
  'Offer',
  'Discount',
  'Emergency',
  'General Announcement',
  'Health Awareness',
  'Festival Greetings',
  'Important Update',
  'Company News',
  'Maintenance',
  'Policy Update',
];

const List<String> kNotificationPriorities = ['Low', 'Normal', 'High', 'Critical'];

/// In-app destinations a notification can send the vendor to. The value is
/// stored on the backend as `redirectScreen`; anything unrecognised falls back
/// to the notification detail screen.
const Map<String, String> kRedirectScreens = {
  '': 'Notification detail (default)',
  'home': 'Home',
  'products': 'Shop / Catalogue',
  'offers': 'Offers & Discounts',
  'orders': 'My Orders',
  'cart': 'Cart',
  'saved': 'Saved Items',
  'profile': 'Profile',
};

// -----------------------------------------------------------------------------
// Presentation helpers
// -----------------------------------------------------------------------------

/// Accent colour per category — drives the gradient card and the icon chip.
Color categoryColor(String category) {
  switch (category) {
    case 'New Medicine':
      return const Color(0xFF2E7D5E);
    case 'Stock Update':
      return const Color(0xFF00897B);
    case 'Offer':
      return const Color(0xFFEF6C00);
    case 'Discount':
      return const Color(0xFFD81B60);
    case 'Emergency':
      return const Color(0xFFD32F2F);
    case 'Health Awareness':
      return const Color(0xFF0288D1);
    case 'Festival Greetings':
      return const Color(0xFF8E24AA);
    case 'Important Update':
      return const Color(0xFF5E35B1);
    case 'Company News':
      return const Color(0xFF3949AB);
    case 'Maintenance':
      return const Color(0xFF616161);
    case 'Policy Update':
      return const Color(0xFF00695C);
    case 'General Announcement':
    default:
      return const Color(0xFF4CAF82);
  }
}

/// Icon per category. A campaign may override it with its own `icon` key.
IconData categoryIcon(String category) {
  switch (category) {
    case 'New Medicine':
      return Icons.medication_rounded;
    case 'Stock Update':
      return Icons.inventory_2_rounded;
    case 'Offer':
      return Icons.local_offer_rounded;
    case 'Discount':
      return Icons.percent_rounded;
    case 'Emergency':
      return Icons.emergency_rounded;
    case 'Health Awareness':
      return Icons.favorite_rounded;
    case 'Festival Greetings':
      return Icons.celebration_rounded;
    case 'Important Update':
      return Icons.priority_high_rounded;
    case 'Company News':
      return Icons.campaign_rounded;
    case 'Maintenance':
      return Icons.build_rounded;
    case 'Policy Update':
      return Icons.gavel_rounded;
    case 'General Announcement':
    default:
      return Icons.notifications_active_rounded;
  }
}

/// Named icon keys the composer offers, mapped to real Material icons.
const Map<String, IconData> kNotificationIcons = {
  'medication': Icons.medication_rounded,
  'inventory': Icons.inventory_2_rounded,
  'offer': Icons.local_offer_rounded,
  'discount': Icons.percent_rounded,
  'emergency': Icons.emergency_rounded,
  'health': Icons.favorite_rounded,
  'celebration': Icons.celebration_rounded,
  'info': Icons.info_rounded,
  'campaign': Icons.campaign_rounded,
  'shield': Icons.verified_user_rounded,
  'truck': Icons.local_shipping_rounded,
  'clock': Icons.schedule_rounded,
};

/// Resolves the icon a card should show: the campaign's own key when it set
/// one, otherwise the category default.
IconData resolveIcon(String iconKey, String category) =>
    kNotificationIcons[iconKey] ?? categoryIcon(category);

Color priorityColor(String priority) {
  switch (priority) {
    case 'Critical':
      return const Color(0xFFD32F2F);
    case 'High':
      return const Color(0xFFEF6C00);
    case 'Low':
      return const Color(0xFF757575);
    case 'Normal':
    default:
      return const Color(0xFF2E7D5E);
  }
}

// -----------------------------------------------------------------------------
// Safe JSON readers
// -----------------------------------------------------------------------------

String _s(dynamic v) => v is String ? v : (v == null ? '' : v.toString());

bool _b(dynamic v) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return false;
}

int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _d(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final parsed = DateTime.tryParse(v.toString());
  return parsed?.toLocal();
}

/// "just now" / "5m ago" / "2h ago" / "3d ago" / "14 Mar".
String relativeTime(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${when.day} ${months[when.month - 1]}';
}

// =============================================================================
// VENDOR — a notification-center row
// =============================================================================

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.notificationId,
    required this.title,
    required this.subtitle,
    required this.message,
    required this.category,
    required this.priority,
    required this.buttonText,
    required this.redirectScreen,
    required this.deepLink,
    required this.imageUrl,
    required this.bannerImage,
    required this.icon,
    required this.pinned,
    required this.expiryDate,
    required this.sentAt,
    required this.receivedAt,
    required this.read,
    required this.opened,
    required this.senderName,
  });

  /// The RECEIPT id — the handle used for read / delete calls.
  final String id;

  /// The CAMPAIGN id — what an FCM payload carries.
  final String notificationId;

  final String title;
  final String subtitle;
  final String message;
  final String category;
  final String priority;
  final String buttonText;
  final String redirectScreen;
  final String deepLink;
  final String imageUrl;
  final String bannerImage;
  final String icon;
  final bool pinned;
  final DateTime? expiryDate;
  final DateTime? sentAt;
  final DateTime? receivedAt;
  final bool read;
  final bool opened;
  final String senderName;

  bool get isCritical => priority == 'Critical';
  bool get isHigh => priority == 'High' || priority == 'Critical';

  /// The artwork to render on the card, if any (banner takes precedence).
  String get artwork => bannerImage.isNotEmpty ? bannerImage : imageUrl;
  bool get hasArtwork => artwork.isNotEmpty;

  DateTime? get when => sentAt ?? receivedAt;
  String get timeLabel => relativeTime(when);

  Color get accent => categoryColor(category);
  IconData get iconData => resolveIcon(icon, category);

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _s(json['id']),
      notificationId: _s(json['notificationId']),
      title: _s(json['title']),
      subtitle: _s(json['subtitle']),
      message: _s(json['message']),
      category: _s(json['category']).isEmpty
          ? 'General Announcement'
          : _s(json['category']),
      priority: _s(json['priority']).isEmpty ? 'Normal' : _s(json['priority']),
      buttonText: _s(json['buttonText']),
      redirectScreen: _s(json['redirectScreen']),
      deepLink: _s(json['deepLink']),
      imageUrl: _s(json['imageUrl']),
      bannerImage: _s(json['bannerImage']),
      icon: _s(json['icon']),
      pinned: _b(json['pinned']),
      expiryDate: _d(json['expiryDate']),
      sentAt: _d(json['sentAt']),
      receivedAt: _d(json['receivedAt']),
      read: _b(json['read']),
      opened: _b(json['opened']),
      senderName: _s(json['senderName']),
    );
  }

  /// Builds a row from an FCM data payload, so a push that arrives while the
  /// app is open can be shown INSTANTLY — before the backend refresh lands.
  /// The subsequent sync replaces it with the authoritative server copy.
  factory AppNotification.fromPushData(Map<String, dynamic> data) {
    return AppNotification(
      // No receipt id yet; the campaign id is what read/open calls accept too.
      id: _s(data['notificationId']),
      notificationId: _s(data['notificationId']),
      title: _s(data['title']),
      subtitle: _s(data['subtitle']),
      message: _s(data['message']),
      category: _s(data['category']).isEmpty
          ? 'General Announcement'
          : _s(data['category']),
      priority: _s(data['priority']).isEmpty ? 'Normal' : _s(data['priority']),
      buttonText: _s(data['buttonText']),
      redirectScreen: _s(data['redirectScreen']),
      deepLink: _s(data['deepLink']),
      imageUrl: _s(data['imageUrl']),
      bannerImage: '',
      icon: _s(data['icon']),
      pinned: _b(data['pinned']),
      expiryDate: null,
      sentAt: _d(data['sentAt']) ?? DateTime.now(),
      receivedAt: DateTime.now(),
      read: false,
      opened: false,
      senderName: '',
    );
  }

  AppNotification copyWith({bool? read, bool? opened}) => AppNotification(
        id: id,
        notificationId: notificationId,
        title: title,
        subtitle: subtitle,
        message: message,
        category: category,
        priority: priority,
        buttonText: buttonText,
        redirectScreen: redirectScreen,
        deepLink: deepLink,
        imageUrl: imageUrl,
        bannerImage: bannerImage,
        icon: icon,
        pinned: pinned,
        expiryDate: expiryDate,
        sentAt: sentAt,
        receivedAt: receivedAt,
        read: read ?? this.read,
        opened: opened ?? this.opened,
        senderName: senderName,
      );
}

// =============================================================================
// MARKETING — a campaign + its delivery analytics
// =============================================================================

@immutable
class CampaignStats {
  const CampaignStats({
    this.targeted = 0,
    this.tokens = 0,
    this.sent = 0,
    this.failed = 0,
    this.delivered = 0,
    this.read = 0,
    this.opened = 0,
    this.retryCount = 0,
    this.pushPending = 0,
    this.pushSkipped = 0,
  });

  /// Eligible vendors resolved at send time.
  final int targeted;

  /// Device tokens attempted.
  final int tokens;

  /// Vendors FCM accepted the push for.
  final int sent;

  /// Vendors whose push was rejected after retries.
  final int failed;

  /// Vendors whose device confirmed arrival.
  final int delivered;

  /// Vendors who marked it read.
  final int read;

  /// Vendors who tapped it open.
  final int opened;

  final int retryCount;
  final int pushPending;

  /// Vendors reached in-app only (no device registered / push off).
  final int pushSkipped;

  double get openRate => sent == 0 ? 0 : opened / sent;
  double get readRate => sent == 0 ? 0 : read / sent;
  double get deliveryRate => sent == 0 ? 0 : delivered / sent;

  factory CampaignStats.fromJson(Map<String, dynamic> json) => CampaignStats(
        targeted: _i(json['targeted']),
        tokens: _i(json['tokens']),
        sent: _i(json['sent']),
        failed: _i(json['failed']),
        delivered: _i(json['delivered']),
        read: _i(json['read']),
        opened: _i(json['opened']),
        retryCount: _i(json['retryCount']),
        pushPending: _i(json['pushPending']),
        pushSkipped: _i(json['pushSkipped']),
      );
}

@immutable
class Campaign {
  const Campaign({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.message,
    required this.category,
    required this.priority,
    required this.buttonText,
    required this.redirectScreen,
    required this.deepLink,
    required this.imageUrl,
    required this.bannerImage,
    required this.icon,
    required this.expiryDate,
    required this.pinned,
    required this.status,
    required this.scheduledAt,
    required this.sentAt,
    required this.createdAt,
    required this.senderName,
    required this.lastError,
    required this.stats,
  });

  final String id;
  final String title;
  final String subtitle;
  final String message;
  final String category;
  final String priority;
  final String buttonText;
  final String redirectScreen;
  final String deepLink;
  final String imageUrl;
  final String bannerImage;
  final String icon;
  final DateTime? expiryDate;
  final bool pinned;

  /// draft | scheduled | sending | sent | failed
  final String status;

  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final String senderName;
  final String lastError;
  final CampaignStats stats;

  bool get isDraft => status == 'draft';
  bool get isScheduled => status == 'scheduled';
  bool get isSending => status == 'sending';
  bool get isSent => status == 'sent';
  bool get isFailed => status == 'failed';

  /// Only unsent campaigns can be edited (matches the backend guard).
  bool get editable => isDraft || isScheduled;

  String get artwork => bannerImage.isNotEmpty ? bannerImage : imageUrl;
  bool get hasArtwork => artwork.isNotEmpty;

  Color get accent => categoryColor(category);
  IconData get iconData => resolveIcon(icon, category);

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'scheduled':
        return 'Scheduled';
      case 'sending':
        return 'Sending…';
      case 'sent':
        return 'Sent';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'draft':
        return const Color(0xFF757575);
      case 'scheduled':
        return const Color(0xFF0288D1);
      case 'sending':
        return const Color(0xFFEF6C00);
      case 'sent':
        return const Color(0xFF2E7D5E);
      case 'failed':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF757575);
    }
  }

  factory Campaign.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    return Campaign(
      id: _s(json['id']),
      title: _s(json['title']),
      subtitle: _s(json['subtitle']),
      message: _s(json['message']),
      category: _s(json['category']).isEmpty
          ? 'General Announcement'
          : _s(json['category']),
      priority: _s(json['priority']).isEmpty ? 'Normal' : _s(json['priority']),
      buttonText: _s(json['buttonText']),
      redirectScreen: _s(json['redirectScreen']),
      deepLink: _s(json['deepLink']),
      imageUrl: _s(json['imageUrl']),
      bannerImage: _s(json['bannerImage']),
      icon: _s(json['icon']),
      expiryDate: _d(json['expiryDate']),
      pinned: _b(json['pinned']),
      status: _s(json['status']).isEmpty ? 'draft' : _s(json['status']),
      scheduledAt: _d(json['scheduledAt']),
      sentAt: _d(json['sentAt']),
      createdAt: _d(json['createdAt']),
      senderName: json['sender'] is Map
          ? _s((json['sender'] as Map)['name'])
          : '',
      lastError: _s(json['lastError']),
      stats: rawStats is Map<String, dynamic>
          ? CampaignStats.fromJson(rawStats)
          : const CampaignStats(),
    );
  }
}

/// The composer's working copy — a mutable draft the form edits before it is
/// posted. Kept separate from the immutable [Campaign] so the form never has to
/// rebuild a whole model on every keystroke.
class CampaignDraft {
  CampaignDraft({
    this.id = '',
    this.title = '',
    this.subtitle = '',
    this.message = '',
    this.category = 'General Announcement',
    this.priority = 'Normal',
    this.buttonText = '',
    this.redirectScreen = '',
    this.deepLink = '',
    this.imageUrl = '',
    this.icon = '',
    this.expiryDate,
    this.scheduledAt,
    this.pinned = false,
    this.existingBanner = '',
    this.removeBanner = false,
  });

  /// Empty for a brand-new campaign; set when editing an existing draft.
  String id;

  String title;
  String subtitle;
  String message;
  String category;
  String priority;
  String buttonText;
  String redirectScreen;
  String deepLink;
  String imageUrl;
  String icon;
  DateTime? expiryDate;
  DateTime? scheduledAt;
  bool pinned;

  /// URL of a banner already stored on the campaign (edit mode).
  String existingBanner;

  /// Set when the user cleared an existing banner.
  bool removeBanner;

  bool get isNew => id.isEmpty;

  factory CampaignDraft.from(Campaign c) => CampaignDraft(
        id: c.id,
        title: c.title,
        subtitle: c.subtitle,
        message: c.message,
        category: c.category,
        priority: c.priority,
        buttonText: c.buttonText,
        redirectScreen: c.redirectScreen,
        deepLink: c.deepLink,
        imageUrl: c.imageUrl,
        icon: c.icon,
        expiryDate: c.expiryDate,
        scheduledAt: c.scheduledAt,
        pinned: c.pinned,
        existingBanner: c.bannerImage,
      );

  /// Validation mirroring the backend's own checks, so the user gets an
  /// immediate, specific message instead of a round-trip 400.
  String? validate() {
    if (title.trim().isEmpty) return 'Add a notification title';
    if (title.trim().length > 120) return 'Title must be 120 characters or less';
    if (message.trim().isEmpty) return 'Add a notification message';
    if (message.trim().length > 2000) {
      return 'Message must be 2000 characters or less';
    }
    if (!kNotificationCategories.contains(category)) {
      return 'Choose a valid category';
    }
    if (!kNotificationPriorities.contains(priority)) {
      return 'Choose a valid priority';
    }
    if (imageUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(imageUrl.trim());
      if (uri == null || !uri.hasScheme || !uri.isAbsolute) {
        return 'Image URL must be a full link (https://…)';
      }
    }
    if (deepLink.trim().isNotEmpty) {
      final uri = Uri.tryParse(deepLink.trim());
      if (uri == null || !uri.hasScheme) {
        return 'Deep link must include a scheme (https:// or app://)';
      }
    }
    if (expiryDate != null && expiryDate!.isBefore(DateTime.now())) {
      return 'Expiry date must be in the future';
    }
    if (scheduledAt != null && scheduledAt!.isBefore(DateTime.now())) {
      return 'Schedule time must be in the future';
    }
    if (expiryDate != null &&
        scheduledAt != null &&
        expiryDate!.isBefore(scheduledAt!)) {
      return 'Expiry must come after the scheduled send time';
    }
    return null;
  }

  /// The wire payload. Empty optional fields are still sent so an edit can
  /// CLEAR a value that was previously set.
  Map<String, String> toFields() => {
        'title': title.trim(),
        'subtitle': subtitle.trim(),
        'message': message.trim(),
        'category': category,
        'priority': priority,
        'buttonText': buttonText.trim(),
        'redirectScreen': redirectScreen.trim(),
        'deepLink': deepLink.trim(),
        'imageUrl': imageUrl.trim(),
        'icon': icon.trim(),
        'pinned': pinned.toString(),
        if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
        if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
        if (removeBanner) 'removeBanner': 'true',
      };

  /// A preview row rendered by the same card widget the vendor will see, so
  /// "Preview" shows the real thing rather than an approximation.
  AppNotification toPreview() => AppNotification(
        id: 'preview',
        notificationId: 'preview',
        title: title.trim().isEmpty ? 'Notification title' : title.trim(),
        subtitle: subtitle.trim(),
        message: message.trim().isEmpty
            ? 'Your message will appear here.'
            : message.trim(),
        category: category,
        priority: priority,
        buttonText: buttonText.trim(),
        redirectScreen: redirectScreen.trim(),
        deepLink: deepLink.trim(),
        imageUrl: imageUrl.trim(),
        bannerImage: removeBanner ? '' : existingBanner,
        icon: icon.trim(),
        pinned: pinned,
        expiryDate: expiryDate,
        sentAt: DateTime.now(),
        receivedAt: DateTime.now(),
        read: false,
        opened: false,
        senderName: '',
      );
}

/// Audience size the composer shows before sending (GET /notifications/audience).
@immutable
class AudienceSummary {
  const AudienceSummary({
    required this.eligibleVendors,
    required this.reachableVendors,
    required this.pushConfigured,
    required this.warning,
  });

  /// Approved vendors with notifications switched on.
  final int eligibleVendors;

  /// Of those, how many have at least one registered device.
  final int reachableVendors;

  /// False when the server has no Firebase credentials — push is skipped and
  /// only the in-app notification center is filled.
  final bool pushConfigured;

  final String warning;

  static const empty = AudienceSummary(
    eligibleVendors: 0,
    reachableVendors: 0,
    pushConfigured: true,
    warning: '',
  );

  factory AudienceSummary.fromJson(Map<String, dynamic> json) => AudienceSummary(
        eligibleVendors: _i(json['eligibleVendors']),
        reachableVendors: _i(json['reachableVendors']),
        pushConfigured: json['pushConfigured'] != false,
        warning: _s(json['warning']),
      );
}
