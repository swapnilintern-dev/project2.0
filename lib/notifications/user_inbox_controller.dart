// =============================================================================
// VS Arogya — per-user inbox state
//
// A ChangeNotifier singleton matching the app's existing controller style
// (CartController.instance, VendorApproval.instance), so screens observe it
// with ListenableBuilder and the unread badge updates everywhere at once.
//
// THE BACKEND IS THE SOURCE OF TRUTH. Marking something read updates the row
// locally first so the UI responds instantly, then reconciles with the server —
// and REVERTS if the server refused, rather than leaving the app showing a
// state the database does not have.
// =============================================================================

import 'package:flutter/foundation.dart';

import 'user_inbox_api.dart';

class UserInboxController extends ChangeNotifier {
  UserInboxController._();

  static final UserInboxController instance = UserInboxController._();

  final UserInboxApi _api = const UserInboxApi();

  List<UserNotification> _items = const [];
  int _unread = 0;
  bool _loading = false;
  bool _loadedOnce = false;

  List<UserNotification> get items => List.unmodifiable(_items);
  int get unread => _unread;
  bool get loading => _loading;

  /// True once a fetch has completed, so a screen can tell "nothing yet"
  /// apart from "genuinely empty" and show the right empty state.
  bool get loadedOnce => _loadedOnce;

  bool get isEmpty => _loadedOnce && _items.isEmpty;

  /// Pulls the list and the unread count together.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final results = await Future.wait([
      _api.list(),
      _api.unreadCount(),
    ]);

    _items = results[0] as List<UserNotification>;

    // Prefer the server's own count; fall back to counting the rows we have, so
    // the badge is still right if only that one call failed.
    final counted = results[1] as int?;
    _unread = counted ?? _items.where((n) => !n.isRead).length;

    _loading = false;
    _loadedOnce = true;
    notifyListeners();
  }

  /// Refreshes only the badge — cheap enough to call on app resume or after an
  /// order action without re-fetching the whole list.
  Future<void> refreshUnread() async {
    final c = await _api.unreadCount();
    if (c == null || c == _unread) return; // leave it alone on failure
    _unread = c;
    notifyListeners();
  }

  /// Marks one notification read, optimistically.
  Future<void> markRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0 || _items[index].isRead) return;

    final previous = _items[index];
    _items = [..._items]..[index] = previous.copyWith(isRead: true);
    _unread = (_unread - 1).clamp(0, 1 << 30);
    notifyListeners();

    if (await _api.markRead(id)) return;

    // The server refused — put it back rather than showing it as read.
    _items = [..._items]..[index] = previous;
    _unread += 1;
    notifyListeners();
  }

  /// Marks everything read.
  Future<void> markAllRead() async {
    if (_items.every((n) => n.isRead)) return;

    final previousItems = _items;
    final previousUnread = _unread;

    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    _unread = 0;
    notifyListeners();

    if (await _api.markAllRead()) return;

    _items = previousItems;
    _unread = previousUnread;
    notifyListeners();
  }

  /// Drops everything. Call on logout so one account's notifications can never
  /// be shown to the next.
  void reset() {
    _items = const [];
    _unread = 0;
    _loading = false;
    _loadedOnce = false;
    notifyListeners();
  }
}
