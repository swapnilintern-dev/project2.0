// =============================================================================
// MediCaPlus — Notification State
//
// Two ChangeNotifier singletons, matching the app's existing controller style
// (no state-management package):
//
//   NotificationController      the VENDOR's notification center + unread badge
//   MarketingCampaignsController the MARKETING history list + filters
//
// The backend is always the source of truth. A push that arrives while the app
// is open is shown OPTIMISTICALLY (so it feels instant) and then reconciled by
// the very next sync — an id-keyed merge means the optimistic row is replaced,
// never duplicated.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_api.dart';
import 'notification_models.dart';

/// A push that just arrived and should be shown as an in-app banner.
/// The overlay listens to this and animates the newest value in.
final ValueNotifier<AppNotification?> incomingPush =
    ValueNotifier<AppNotification?>(null);

// =============================================================================
// VENDOR
// =============================================================================

class NotificationController extends ChangeNotifier {
  NotificationController._();
  static final NotificationController instance = NotificationController._();

  final NotificationApi _api = NotificationApi();

  static const int _pageSize = 30;

  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  int _unread = 0;
  int get unread => _unread;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  bool _hasMore = false;
  bool get hasMore => _hasMore;

  int _page = 1;

  /// True once a fetch has succeeded at least once — lets the UI tell "empty
  /// inbox" apart from "not loaded yet".
  bool _loadedOnce = false;
  bool get loadedOnce => _loadedOnce;

  /// Set when the last sync failed, so the screen can show an offline note
  /// while still displaying the cached rows.
  bool _offline = false;
  bool get offline => _offline;

  String _categoryFilter = 'All';
  String get categoryFilter => _categoryFilter;

  bool _unreadOnly = false;
  bool get unreadOnly => _unreadOnly;

  /// Campaign ids already surfaced this session. This is the client half of the
  /// no-duplicates guarantee: FCM can legitimately redeliver a message (retry,
  /// app restart with a queued message, a foreground + tap pair), and this set
  /// keeps the banner and the optimistic insert from firing twice.
  final Set<String> _seenPushIds = <String>{};

  bool get isEmpty => _items.isEmpty;

  List<AppNotification> get visibleItems {
    Iterable<AppNotification> out = _items;
    if (_unreadOnly) out = out.where((n) => !n.read);
    if (_categoryFilter != 'All') {
      out = out.where((n) => n.category == _categoryFilter);
    }
    return out.toList();
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Full refresh of page 1 + the unread badge. Offline-safe: on failure the
  /// current list is kept and [offline] flips true.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final page = await _api.getInbox(page: 1, limit: _pageSize);

    if (page.ok) {
      _items
        ..clear()
        ..addAll(page.items);
      _unread = page.unread;
      _hasMore = page.hasMore;
      _page = 1;
      _loadedOnce = true;
      _offline = false;
      // Anything the server already knows about must not re-trigger a banner.
      _seenPushIds.addAll(page.items.map((n) => n.notificationId));
    } else {
      _offline = true;
    }

    _loading = false;
    notifyListeners();
  }

  /// Appends the next page (infinite scroll).
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();

    final next = await _api.getInbox(page: _page + 1, limit: _pageSize);
    if (next.ok) {
      final existing = _items.map((n) => n.id).toSet();
      _items.addAll(next.items.where((n) => !existing.contains(n.id)));
      _hasMore = next.hasMore;
      _page += 1;
      _unread = next.unread;
      _offline = false;
    } else {
      _offline = true;
    }

    _loadingMore = false;
    notifyListeners();
  }

  /// Badge-only sync — a fraction of the cost of a full inbox fetch, so it can
  /// be polled from the home screen without a care.
  Future<void> syncUnread() async {
    final count = await _api.getUnreadCount();
    if (count == null) return; // keep the last known value when offline
    if (count == _unread) return;
    _unread = count;
    notifyListeners();
  }

  /// Called by [PushService] when a message arrives in ANY app state.
  ///
  /// Shows the row immediately, acknowledges delivery to the backend (which is
  /// what turns "sent" into "delivered" in the marketing analytics), and then
  /// re-syncs so the optimistic row is replaced by the server's copy.
  Future<void> onPushReceived(
    Map<String, dynamic> data, {
    bool showBanner = true,
  }) async {
    final id = (data['notificationId'] ?? '').toString();
    if (id.isEmpty) return;

    // Deduplicate: FCM may deliver the same campaign more than once.
    final firstTime = _seenPushIds.add(id);

    if (firstTime) {
      final optimistic = AppNotification.fromPushData(data);
      _items.insert(0, optimistic);
      _unread += 1;
      notifyListeners();

      if (showBanner) incomingPush.value = optimistic;
    }

    // Confirm receipt for the delivery analytics (idempotent server-side).
    unawaited(_api.markDelivered(id));

    // Reconcile with the backend — the source of truth.
    unawaited(refresh());
  }

  /// Called when the vendor taps a push (foreground tap, background tap or the
  /// launch message of a terminated app).
  Future<void> onPushOpened(Map<String, dynamic> data) async {
    final id = (data['notificationId'] ?? '').toString();
    if (id.isEmpty) return;

    _seenPushIds.add(id);

    final idx = _items.indexWhere((n) => n.notificationId == id);
    if (idx >= 0 && !_items[idx].read) {
      _items[idx] = _items[idx].copyWith(read: true, opened: true);
      if (_unread > 0) _unread -= 1;
      notifyListeners();
    }

    await _api.markOpened(id);
    unawaited(refresh());
  }

  // ---------------------------------------------------------------------------
  // Mutations (optimistic, then confirmed by the server)
  // ---------------------------------------------------------------------------

  Future<bool> markRead(AppNotification n) async {
    if (n.read) return true;

    final idx = _items.indexWhere((x) => x.id == n.id);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(read: true);
      if (_unread > 0) _unread -= 1;
      notifyListeners();
    }

    final res = await _api.markRead(n.id);
    if (!res.ok) {
      // Roll the optimistic change back and re-sync from the server.
      if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(read: false);
        _unread += 1;
        notifyListeners();
      }
      return false;
    }
    unawaited(syncUnread());
    return true;
  }

  /// Marks read AND records the open (used when the detail screen is opened).
  Future<void> markOpened(AppNotification n) async {
    final idx = _items.indexWhere((x) => x.id == n.id);
    if (idx >= 0 && !_items[idx].read) {
      _items[idx] = _items[idx].copyWith(read: true, opened: true);
      if (_unread > 0) _unread -= 1;
      notifyListeners();
    }
    await _api.markOpened(n.id);
    unawaited(syncUnread());
  }

  Future<bool> markAllRead() async {
    if (_items.every((n) => n.read)) return true;

    final previous = List<AppNotification>.from(_items);
    final previousUnread = _unread;

    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) _items[i] = _items[i].copyWith(read: true);
    }
    _unread = 0;
    notifyListeners();

    final res = await _api.markAllRead();
    if (!res.ok) {
      _items
        ..clear()
        ..addAll(previous);
      _unread = previousUnread;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> remove(AppNotification n) async {
    final idx = _items.indexWhere((x) => x.id == n.id);
    if (idx < 0) return false;

    final removed = _items.removeAt(idx);
    if (!removed.read && _unread > 0) _unread -= 1;
    notifyListeners();

    final res = await _api.deleteNotification(removed.id);
    if (!res.ok) {
      _items.insert(idx, removed);
      if (!removed.read) _unread += 1;
      notifyListeners();
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  void setCategoryFilter(String category) {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    notifyListeners();
  }

  void setUnreadOnly(bool value) {
    if (_unreadOnly == value) return;
    _unreadOnly = value;
    notifyListeners();
  }

  /// Wipes every trace of the previous account. Called from logout so the next
  /// user on this device never sees someone else's notifications.
  void clear() {
    _items.clear();
    _unread = 0;
    _page = 1;
    _hasMore = false;
    _loadedOnce = false;
    _offline = false;
    _unreadOnly = false;
    _categoryFilter = 'All';
    _seenPushIds.clear();
    incomingPush.value = null;
    notifyListeners();
  }
}

// =============================================================================
// MARKETING
// =============================================================================

class MarketingCampaignsController extends ChangeNotifier {
  MarketingCampaignsController._();
  static final MarketingCampaignsController instance =
      MarketingCampaignsController._();

  final NotificationApi _api = NotificationApi();

  static const int _pageSize = 20;

  final List<Campaign> _items = [];
  List<Campaign> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  bool _hasMore = false;
  bool get hasMore => _hasMore;

  bool _loadedOnce = false;
  bool get loadedOnce => _loadedOnce;

  bool _offline = false;
  bool get offline => _offline;

  int _total = 0;
  int get total => _total;

  int _page = 1;

  /// False when the server has no Firebase credentials. The panel surfaces this
  /// so a marketing user is never left thinking a push went out when only the
  /// in-app center was filled.
  bool _pushConfigured = true;
  bool get pushConfigured => _pushConfigured;

  AudienceSummary _audience = AudienceSummary.empty;
  AudienceSummary get audience => _audience;

  // --- filters ---------------------------------------------------------------
  String _query = '';
  String get query => _query;

  String _status = 'all';
  String get status => _status;

  String _category = 'all';
  String get category => _category;

  String _priority = 'all';
  String get priority => _priority;

  bool get hasFilters =>
      _query.isNotEmpty ||
      _status != 'all' ||
      _category != 'all' ||
      _priority != 'all';

  Timer? _searchDebounce;

  /// Server-provided vocabularies (fall back to the compile-time constants).
  List<String> _categories = kNotificationCategories;
  List<String> get categories => _categories;

  List<String> _priorities = kNotificationPriorities;
  List<String> get priorities => _priorities;

  Future<void> loadMeta() async {
    final meta = await _api.getMeta();
    if (meta == null) return;
    _categories = meta.categories;
    _priorities = meta.priorities;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final page = await _api.listCampaigns(
      query: _query,
      status: _status,
      category: _category,
      priority: _priority,
      page: 1,
      limit: _pageSize,
    );

    if (page.ok) {
      _items
        ..clear()
        ..addAll(page.items);
      _total = page.total;
      _hasMore = page.hasMore;
      _pushConfigured = page.pushConfigured;
      _page = 1;
      _loadedOnce = true;
      _offline = false;
    } else {
      _offline = true;
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();

    final next = await _api.listCampaigns(
      query: _query,
      status: _status,
      category: _category,
      priority: _priority,
      page: _page + 1,
      limit: _pageSize,
    );

    if (next.ok) {
      final existing = _items.map((c) => c.id).toSet();
      _items.addAll(next.items.where((c) => !existing.contains(c.id)));
      _hasMore = next.hasMore;
      _page += 1;
      _offline = false;
    } else {
      _offline = true;
    }

    _loadingMore = false;
    notifyListeners();
  }

  /// Refreshes the audience counters shown in the composer's preview.
  Future<void> loadAudience() async {
    final summary = await _api.getAudience();
    if (summary == null) return;
    _audience = summary;
    _pushConfigured = summary.pushConfigured;
    notifyListeners();
  }

  /// Search box: debounced so typing doesn't fire a request per keystroke.
  void search(String value) {
    _query = value;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  void setStatus(String value) {
    if (_status == value) return;
    _status = value;
    unawaited(refresh());
  }

  void setCategory(String value) {
    if (_category == value) return;
    _category = value;
    unawaited(refresh());
  }

  void setPriority(String value) {
    if (_priority == value) return;
    _priority = value;
    unawaited(refresh());
  }

  void clearFilters() {
    if (!hasFilters) return;
    _query = '';
    _status = 'all';
    _category = 'all';
    _priority = 'all';
    unawaited(refresh());
  }

  // ---------------------------------------------------------------------------
  // Write-through actions. Each re-syncs from the backend so the list always
  // reflects the server's state rather than a guess.
  // ---------------------------------------------------------------------------

  Future<ApiResult> send(Campaign c) async {
    _patchStatus(c.id, 'sending');
    final res = await _api.sendCampaign(c.id);
    await refresh();
    return res;
  }

  Future<ApiResult> retry(Campaign c) async {
    final res = await _api.retryCampaign(c.id);
    await refresh();
    return res;
  }

  Future<ApiResult> duplicate(Campaign c) async {
    final res = await _api.duplicateCampaign(c.id);
    await refresh();
    return res;
  }

  Future<ApiResult> delete(Campaign c) async {
    final res = await _api.deleteCampaign(c.id);
    if (res.ok) {
      _items.removeWhere((x) => x.id == c.id);
      notifyListeners();
    }
    await refresh();
    return res;
  }

  /// Optimistic status flip so the card shows "Sending…" the instant the button
  /// is pressed; the following refresh replaces it with the server's truth.
  void _patchStatus(String id, String status) {
    final idx = _items.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final c = _items[idx];
    _items[idx] = Campaign(
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
      bannerImage: c.bannerImage,
      icon: c.icon,
      expiryDate: c.expiryDate,
      pinned: c.pinned,
      status: status,
      scheduledAt: c.scheduledAt,
      sentAt: c.sentAt,
      createdAt: c.createdAt,
      senderName: c.senderName,
      lastError: c.lastError,
      stats: c.stats,
    );
    notifyListeners();
  }

  void clear() {
    _searchDebounce?.cancel();
    _items.clear();
    _total = 0;
    _page = 1;
    _hasMore = false;
    _loadedOnce = false;
    _offline = false;
    _query = '';
    _status = 'all';
    _category = 'all';
    _priority = 'all';
    _audience = AudienceSummary.empty;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
