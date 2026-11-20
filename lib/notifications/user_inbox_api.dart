// =============================================================================
// VS Arogya — per-user notification inbox
//
// The TRANSACTIONAL notification stream for ONE signed-in account: "your order
// shipped", "payment received", "your vendor registration was approved".
//
//   GET    /vsArogya/get-notification                      → this account's rows
//   GET    /vsArogya/unread-notification                   → { count }
//   PATCH  /vsArogya/mark-read-notification/:id            → mark one read
//   POST   /vsArogya/mark-all-read                         → mark all read
//
// NOT the same thing as NotificationApi (notification_api.dart), which drives
// the MARKETING BROADCAST system — campaigns authored for thousands of vendors,
// with FCM push and per-campaign delivery stats. The two live in separate
// collections on the server and are deliberately kept apart here too: this one
// is scoped to the account by the JWT, so it needs no ids or filters.
//
// Every route is authenticated — the server derives the recipient from the
// token, so nothing here sends a user id and no account can read another's
// inbox by changing a parameter.
//
// NEVER THROWS: failures degrade to an empty list / unchanged count so a screen
// keeps whatever it was showing instead of crashing.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import '../services/auth_service.dart';

/// One row in the account's inbox. Mirrors server/model/notificationModel.js.
class UserNotification {
  const UserNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.referenceId,
    this.createdAt,
    this.data = const {},
  });

  final String id;
  final String title;
  final String message;

  /// Backend enum: ORDER_PLACED, ORDER_SHIPPED, PAYMENT_SUCCESS,
  /// VENDOR_APPROVED, GENERAL, … Unknown values are kept as-is so a new server
  /// type never breaks the list.
  final String type;

  final bool isRead;

  /// The order/product this notification is about, when it has one.
  final String? referenceId;

  final DateTime? createdAt;
  final Map<String, dynamic> data;

  factory UserNotification.fromJson(Map<String, dynamic> j) => UserNotification(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        type: (j['type'] ?? 'GENERAL').toString(),
        isRead: j['isRead'] == true,
        referenceId: j['referenceId']?.toString(),
        createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}'),
        data: j['data'] is Map
            ? Map<String, dynamic>.from(j['data'] as Map)
            : const {},
      );

  UserNotification copyWith({bool? isRead}) => UserNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        isRead: isRead ?? this.isRead,
        referenceId: referenceId,
        createdAt: createdAt,
        data: data,
      );

  /// Whether this notification points at an order the app can open.
  bool get isOrderEvent => type.startsWith('ORDER_') ||
      type == 'OUT_FOR_DELIVERY' ||
      type.startsWith('PAYMENT_');
}

class UserInboxApi {
  const UserInboxApi();

  static const Duration _timeout = Duration(seconds: 30);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  /// This account's notifications, newest first. Empty on any failure.
  Future<List<UserNotification>> list() async {
    final body = await _get(ApiConfig.myNotifications);
    final rows = body?['notifications'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((e) => UserNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Unread count for the badge. Returns null when it could not be read, so the
  /// caller can leave the badge as it was rather than flashing it to zero.
  Future<int?> unreadCount() async {
    final body = await _get(ApiConfig.unreadNotificationCount);
    final c = body?['count'];
    return c is num ? c.toInt() : null;
  }

  /// Marks ONE notification read. Returns whether the server confirmed it.
  Future<bool> markRead(String id) async =>
      _send('PATCH', ApiConfig.markNotificationRead(id));

  /// Marks every notification read.
  Future<bool> markAllRead() async =>
      _send('POST', ApiConfig.markAllNotificationsRead);

  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _get(String url) async {
    final client = http.Client();
    try {
      final r =
          await client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      final decoded = jsonDecode(r.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return map['success'] == true ? map : null;
    } catch (_) {
      // Offline, timeout, HTML error page — the caller degrades gracefully.
      return null;
    } finally {
      client.close();
    }
  }

  Future<bool> _send(String method, String url) async {
    final client = http.Client();
    try {
      final req = http.Request(method, Uri.parse(url))
        ..headers.addAll(_headers);
      final streamed = await client.send(req).timeout(_timeout);
      final r = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(r.body);
      return decoded is Map && decoded['success'] == true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}

// =============================================================================
// Notification preferences (account-level push opt-in)
//
//   GET /vsArogya/notifications/settings     → { notificationsEnabled, … }
//   PUT /vsArogya/notifications/preferences  { enabled } → updated value
//
// Turning this OFF stops PUSH only. The in-app notification centre keeps
// filling either way — the server's broadcast skips the device, not the record
// — so the UI must not promise "you will receive nothing".
// =============================================================================

/// The account's notification settings as the server reports them.
class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    this.registeredDevices = 0,
    this.pushConfigured = true,
  });

  final bool enabled;

  /// How many of this account's devices are registered for push.
  final int registeredDevices;

  /// False when the SERVER has no push credentials configured — in that case
  /// nobody gets push regardless of this account's preference, and the UI
  /// should say so rather than implying the toggle is the reason.
  final bool pushConfigured;

  factory NotificationSettings.fromJson(Map<String, dynamic> j) =>
      NotificationSettings(
        enabled: j['notificationsEnabled'] != false,
        registeredDevices: j['registeredDevices'] is num
            ? (j['registeredDevices'] as num).toInt()
            : 0,
        pushConfigured: j['pushConfigured'] != false,
      );
}

extension NotificationPreferencesApi on UserInboxApi {
  /// Reads the account's current preference. Null when it could not be read, so
  /// the caller can show "unavailable" instead of guessing a default.
  Future<NotificationSettings?> fetchSettings() async {
    final client = http.Client();
    try {
      final r = await client
          .get(Uri.parse(ApiConfig.notificationSettings), headers: _headers)
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(r.body);
      if (decoded is! Map || decoded['success'] != true) return null;
      return NotificationSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Turns push on or off. Returns the value the SERVER ended up with, or null
  /// on failure — the caller must not assume its own value stuck.
  Future<bool?> setNotificationsEnabled(bool enabled) async {
    final client = http.Client();
    try {
      final r = await client
          .put(
            Uri.parse(ApiConfig.notificationPreferences),
            headers: _headers,
            body: jsonEncode({'enabled': enabled}),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(r.body);
      if (decoded is! Map || decoded['success'] != true) return null;
      return decoded['notificationsEnabled'] != false;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
