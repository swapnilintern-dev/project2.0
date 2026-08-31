// =============================================================================
// MediCaPlus — Notification API Service
//
// Thin repository over the notification routes (server/routes/notificationRoute.js):
//
//   Shared    POST/PUT/DELETE /vsArogya/notifications/device-token
//             GET/PUT         /vsArogya/notifications/settings | preferences
//             GET             /vsArogya/notifications/meta
//
//   Vendor    GET    /vsArogya/notifications/inbox
//             GET    /vsArogya/notifications/inbox/unread-count
//             POST   /vsArogya/notifications/inbox/:id/read | delivered | opened
//             POST   /vsArogya/notifications/inbox/read-all
//             DELETE /vsArogya/notifications/inbox/:id
//
//   Marketing GET    /vsArogya/notifications              (history + search)
//             POST   /vsArogya/notifications              (create / send now)
//             PUT    /vsArogya/notifications/:id          (edit a draft)
//             DELETE /vsArogya/notifications/:id
//             POST   /vsArogya/notifications/:id/send | retry | duplicate
//             GET    /vsArogya/notifications/:id | :id/stats | audience
//
// Every method is offline-safe: it returns a failed [ApiResult] or an empty
// page instead of throwing, matching the rest of the app's services.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'notification_models.dart';

/// The outcome of a write call — success plus the server's message, so the UI
/// can surface the real reason a send was refused.
class ApiResult {
  const ApiResult(this.ok, this.message, [this.data]);

  final bool ok;
  final String message;
  final Map<String, dynamic>? data;

  static const offline = ApiResult(
    false,
    'No connection to the server. Please try again.',
  );
}

/// One page of the vendor's notification center.
class InboxPage {
  const InboxPage({
    required this.items,
    required this.total,
    required this.unread,
    required this.hasMore,
    required this.ok,
  });

  final List<AppNotification> items;
  final int total;
  final int unread;
  final bool hasMore;

  /// False when the fetch failed — lets the controller keep what it already has
  /// instead of blanking the list.
  final bool ok;

  static const failed = InboxPage(
    items: [],
    total: 0,
    unread: 0,
    hasMore: false,
    ok: false,
  );
}

/// One page of the marketing campaign history.
class CampaignPage {
  const CampaignPage({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.ok,
    required this.pushConfigured,
  });

  final List<Campaign> items;
  final int total;
  final bool hasMore;
  final bool ok;
  final bool pushConfigured;

  static const failed = CampaignPage(
    items: [],
    total: 0,
    hasMore: false,
    ok: false,
    pushConfigured: true,
  );
}

class NotificationApi {
  NotificationApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String get baseUrl => ApiConfig.baseUrl;
  static String get _root => '$baseUrl/vsArogya/notifications';

  /// Short: the badge and inbox are polled, so a hung call must not pile up.
  static const Duration _timeout = Duration(seconds: 15);

  /// Sending fans out to every vendor server-side; give it room on a cold dyno.
  static const Duration _sendTimeout = Duration(seconds: 60);

  /// Banner uploads.
  static const Duration _uploadTimeout = Duration(minutes: 2);

  /// Token auth works on web + mobile; the cookie is the mobile fallback.
  /// Identical to CustomerApi / MarketingApi so one login serves everything.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  Map<String, String> get _authOnlyHeaders => {
        if (AuthService.authToken != null)
          'Authorization': 'Bearer ${AuthService.authToken}',
        if (AuthService.sessionCookie != null)
          'Cookie': AuthService.sessionCookie!,
      };

  bool get _signedIn =>
      AuthService.authToken != null || AuthService.sessionCookie != null;

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> ? body : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  ApiResult _result(http.Response res, String fallbackError) {
    final body = _decode(res);
    final ok = res.statusCode >= 200 &&
        res.statusCode < 300 &&
        body['success'] != false;
    final message = body['message'] is String
        ? body['message'] as String
        : (ok ? '' : fallbackError);
    return ApiResult(ok, message, body);
  }

  // ===========================================================================
  // DEVICE TOKENS + PREFERENCES
  // ===========================================================================

  /// Registers/refreshes this device's FCM token. Idempotent — the app calls it
  /// on every start and on every token rotation.
  Future<ApiResult> registerDeviceToken({
    required String token,
    required String platform,
    String deviceId = '',
    String appVersion = '',
    bool enabled = true,
  }) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final res = await _client
          .post(
            Uri.parse('$_root/device-token'),
            headers: _headers,
            body: jsonEncode({
              'token': token,
              'platform': platform,
              'deviceId': deviceId,
              'appVersion': appVersion,
              'enabled': enabled,
            }),
          )
          .timeout(_timeout);
      return _result(res, 'Could not register this device');
    } catch (e) {
      debugPrint('registerDeviceToken failed: $e');
      return ApiResult.offline;
    }
  }

  /// Reports a rotated token so the old row is dropped in the same call.
  Future<ApiResult> rotateDeviceToken({
    required String oldToken,
    required String token,
    required String platform,
    String deviceId = '',
    String appVersion = '',
  }) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final res = await _client
          .put(
            Uri.parse('$_root/device-token'),
            headers: _headers,
            body: jsonEncode({
              'oldToken': oldToken,
              'token': token,
              'platform': platform,
              'deviceId': deviceId,
              'appVersion': appVersion,
              'enabled': true,
            }),
          )
          .timeout(_timeout);
      return _result(res, 'Could not update this device token');
    } catch (e) {
      debugPrint('rotateDeviceToken failed: $e');
      return ApiResult.offline;
    }
  }

  /// Unregisters the device (called on logout so the next account on this phone
  /// doesn't inherit the previous user's pushes).
  Future<ApiResult> unregisterDeviceToken({String token = ''}) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final res = await _client
          .delete(
            Uri.parse('$_root/device-token'),
            headers: _headers,
            body: jsonEncode({if (token.isNotEmpty) 'token': token}),
          )
          .timeout(_timeout);
      return _result(res, 'Could not unregister this device');
    } catch (e) {
      debugPrint('unregisterDeviceToken failed: $e');
      return ApiResult.offline;
    }
  }

  /// Account-level push opt-in/out.
  Future<ApiResult> setNotificationsEnabled(bool enabled) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final res = await _client
          .put(
            Uri.parse('$_root/preferences'),
            headers: _headers,
            body: jsonEncode({'enabled': enabled}),
          )
          .timeout(_timeout);
      return _result(res, 'Could not update your preference');
    } catch (e) {
      debugPrint('setNotificationsEnabled failed: $e');
      return ApiResult.offline;
    }
  }

  /// Current opt-in state + how many devices are registered.
  Future<ApiResult> getSettings() async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final res = await _client
          .get(Uri.parse('$_root/settings'), headers: _headers)
          .timeout(_timeout);
      return _result(res, 'Could not load your notification settings');
    } catch (e) {
      debugPrint('getSettings failed: $e');
      return ApiResult.offline;
    }
  }

  /// The server's category / priority vocabularies. Returns null on failure so
  /// the caller keeps its compile-time defaults.
  Future<({List<String> categories, List<String> priorities})?> getMeta() async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_root/meta'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = _decode(res);
      final cats = (body['categories'] as List?)?.whereType<String>().toList();
      final pris = (body['priorities'] as List?)?.whereType<String>().toList();
      if (cats == null || pris == null || cats.isEmpty || pris.isEmpty) {
        return null;
      }
      return (categories: cats, priorities: pris);
    } catch (e) {
      debugPrint('getMeta failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // VENDOR NOTIFICATION CENTER
  // ===========================================================================

  Future<InboxPage> getInbox({
    int page = 1,
    int limit = 30,
    bool unreadOnly = false,
    String category = '',
  }) async {
    if (!_signedIn) return InboxPage.failed;
    try {
      final uri = Uri.parse('$_root/inbox').replace(queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (unreadOnly) 'unreadOnly': 'true',
        if (category.isNotEmpty && category != 'All') 'category': category,
      });

      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return InboxPage.failed;

      final body = _decode(res);
      if (body['success'] != true) return InboxPage.failed;

      final raw = (body['notifications'] as List?) ?? const [];
      return InboxPage(
        items: raw
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList(),
        total: (body['total'] as num?)?.toInt() ?? 0,
        unread: (body['unread'] as num?)?.toInt() ?? 0,
        hasMore: body['hasMore'] == true,
        ok: true,
      );
    } catch (e) {
      debugPrint('getInbox failed: $e');
      return InboxPage.failed;
    }
  }

  /// Unread badge count. Returns null when the call failed, so the caller keeps
  /// the last known number rather than flashing 0.
  Future<int?> getUnreadCount() async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_root/inbox/unread-count'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = _decode(res);
      if (body['success'] != true) return null;
      return (body['unread'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('getUnreadCount failed: $e');
      return null;
    }
  }

  Future<ApiResult> _inboxAction(String path, {String method = 'POST'}) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final uri = Uri.parse('$_root/inbox/$path');
      final res = await (method == 'DELETE'
              ? _client.delete(uri, headers: _headers)
              : _client.post(uri, headers: _headers))
          .timeout(_timeout);
      return _result(res, 'Could not update the notification');
    } catch (e) {
      debugPrint('inbox action $path failed: $e');
      return ApiResult.offline;
    }
  }

  /// [id] accepts either the receipt id or the campaign id — the backend
  /// resolves both, so a push handler (which only knows the campaign) can call
  /// these directly.
  Future<ApiResult> markRead(String id) => _inboxAction('$id/read');

  Future<ApiResult> markDelivered(String id) => _inboxAction('$id/delivered');

  Future<ApiResult> markOpened(String id) => _inboxAction('$id/opened');

  Future<ApiResult> markAllRead() => _inboxAction('read-all');

  Future<ApiResult> deleteNotification(String id) =>
      _inboxAction(id, method: 'DELETE');

  // ===========================================================================
  // MARKETING PANEL
  // ===========================================================================

  Future<CampaignPage> listCampaigns({
    String query = '',
    String status = 'all',
    String category = 'all',
    String priority = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    if (!_signedIn) return CampaignPage.failed;
    try {
      final uri = Uri.parse(_root).replace(queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (status != 'all') 'status': status,
        if (category != 'all') 'category': category,
        if (priority != 'all') 'priority': priority,
      });

      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return CampaignPage.failed;

      final body = _decode(res);
      if (body['success'] != true) return CampaignPage.failed;

      final raw = (body['notifications'] as List?) ?? const [];
      return CampaignPage(
        items: raw
            .whereType<Map<String, dynamic>>()
            .map(Campaign.fromJson)
            .toList(),
        total: (body['total'] as num?)?.toInt() ?? 0,
        hasMore: body['hasMore'] == true,
        ok: true,
        pushConfigured: body['pushConfigured'] != false,
      );
    } catch (e) {
      debugPrint('listCampaigns failed: $e');
      return CampaignPage.failed;
    }
  }

  /// One campaign with live analytics. Null when it could not be loaded.
  Future<Campaign?> getCampaign(String id) async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_root/$id'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = _decode(res);
      final raw = body['notification'];
      if (raw is! Map<String, dynamic>) return null;
      return Campaign.fromJson(raw);
    } catch (e) {
      debugPrint('getCampaign failed: $e');
      return null;
    }
  }

  /// Delivery analytics only — cheap enough for the stats screen to poll.
  Future<CampaignStats?> getStats(String id) async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_root/$id/stats'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = _decode(res);
      final raw = body['stats'];
      if (raw is! Map<String, dynamic>) return null;
      return CampaignStats.fromJson(raw);
    } catch (e) {
      debugPrint('getStats failed: $e');
      return null;
    }
  }

  /// How many vendors a broadcast would reach right now.
  Future<AudienceSummary?> getAudience() async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .get(Uri.parse('$_root/audience'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = _decode(res);
      if (body['success'] != true) return null;
      return AudienceSummary.fromJson(body);
    } catch (e) {
      debugPrint('getAudience failed: $e');
      return null;
    }
  }

  /// Creates a campaign. [sendNow] broadcasts it immediately; otherwise it is
  /// saved as a draft (or scheduled when the draft carries a future
  /// `scheduledAt`). Uploads [banner] as multipart when supplied.
  Future<ApiResult> createCampaign(
    CampaignDraft draft, {
    bool sendNow = false,
    XFile? banner,
  }) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');

    final invalid = draft.validate();
    if (invalid != null) return ApiResult(false, invalid);

    try {
      final fields = draft.toFields()..['sendNow'] = sendNow.toString();

      if (banner != null) {
        return await _multipart('POST', _root, fields, banner,
            timeout: sendNow ? _sendTimeout : _uploadTimeout);
      }

      final res = await _client
          .post(Uri.parse(_root), headers: _headers, body: jsonEncode(fields))
          .timeout(sendNow ? _sendTimeout : _timeout);
      return _result(res, 'Could not create the notification');
    } catch (e) {
      debugPrint('createCampaign failed: $e');
      return ApiResult.offline;
    }
  }

  /// Edits an unsent campaign (draft or scheduled).
  Future<ApiResult> updateCampaign(
    CampaignDraft draft, {
    XFile? banner,
  }) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    if (draft.id.isEmpty) return const ApiResult(false, 'Missing draft id');

    final invalid = draft.validate();
    if (invalid != null) return ApiResult(false, invalid);

    try {
      final fields = draft.toFields();
      final url = '$_root/${draft.id}';

      if (banner != null) {
        return await _multipart('PUT', url, fields, banner,
            timeout: _uploadTimeout);
      }

      final res = await _client
          .put(Uri.parse(url), headers: _headers, body: jsonEncode(fields))
          .timeout(_timeout);
      return _result(res, 'Could not update the notification');
    } catch (e) {
      debugPrint('updateCampaign failed: $e');
      return ApiResult.offline;
    }
  }

  Future<ApiResult> sendCampaign(String id) =>
      _campaignAction('$id/send', timeout: _sendTimeout);

  Future<ApiResult> retryCampaign(String id) =>
      _campaignAction('$id/retry', timeout: _sendTimeout);

  Future<ApiResult> duplicateCampaign(String id) =>
      _campaignAction('$id/duplicate');

  Future<ApiResult> deleteCampaign(String id) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final res = await _client
          .delete(Uri.parse('$_root/$id'), headers: _headers)
          .timeout(_timeout);
      return _result(res, 'Could not delete the notification');
    } catch (e) {
      debugPrint('deleteCampaign failed: $e');
      return ApiResult.offline;
    }
  }

  Future<ApiResult> _campaignAction(
    String path, {
    Duration timeout = _timeout,
  }) async {
    if (!_signedIn) return const ApiResult(false, 'Not signed in');
    try {
      final res = await _client
          .post(Uri.parse('$_root/$path'), headers: _headers)
          .timeout(timeout);
      return _result(res, 'The action could not be completed');
    } catch (e) {
      debugPrint('campaign action $path failed: $e');
      return ApiResult.offline;
    }
  }

  /// Posts the composer fields plus a banner image as multipart/form-data.
  Future<ApiResult> _multipart(
    String method,
    String url,
    Map<String, String> fields,
    XFile banner, {
    required Duration timeout,
  }) async {
    final req = http.MultipartRequest(method, Uri.parse(url));
    // Multipart sets its own Content-Type boundary — only auth headers here.
    req.headers.addAll(_authOnlyHeaders);
    req.fields.addAll(fields);

    final bytes = await banner.readAsBytes();
    final name = banner.name.toLowerCase();
    final subtype = name.endsWith('.png')
        ? 'png'
        : name.endsWith('.webp')
            ? 'webp'
            : 'jpeg';

    req.files.add(http.MultipartFile.fromBytes(
      'bannerImage',
      bytes,
      filename: banner.name.isEmpty ? 'banner.jpg' : banner.name,
      contentType: MediaType('image', subtype),
    ));

    final streamed = await _client.send(req).timeout(timeout);
    final res = await http.Response.fromStream(streamed);
    return _result(res, 'Could not upload the banner image');
  }
}
