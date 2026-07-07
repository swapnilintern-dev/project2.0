// =============================================================================
// MediCaPlus — Admin · Users store
//
// The live platform-user directory for the Admin "User Management" screen.
// Vendors and delivery agents are fetched from the backend
// (GET /vsArogya/all-vendors via AdminApi.getAllPlatformUsers) — there is no
// dummy/seed data. The Admin can remove a user locally and the screen updates
// live; a pull-to-refresh re-fetches from the server.
// =============================================================================

import 'package:flutter/foundation.dart';

import 'admin_api.dart';
import 'admin_models.dart';

class AdminUsersController extends ChangeNotifier {
  AdminUsersController._();
  static final AdminUsersController instance = AdminUsersController._();

  final AdminApi _api = AdminApi();

  final List<PlatformUser> _users = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<PlatformUser> get users => List.unmodifiable(_users);

  /// True while the first (or a forced) fetch is in flight.
  bool get isLoading => _loading;

  /// True once a fetch has succeeded at least once.
  bool get isLoaded => _loaded;

  /// A user-facing error message when the last fetch failed, else null.
  String? get error => _error;

  List<PlatformUser> byKind(UserKind kind) =>
      _users.where((u) => u.kind == kind).toList();

  /// How many users of [kind] are currently in the directory.
  int countOf(UserKind kind) => _users.where((u) => u.kind == kind).length;

  /// Fetches the directory from the backend. No-ops if already loaded unless
  /// [force] is set (pull-to-refresh). Keeps whatever it has on failure and
  /// exposes [error] so the screen can offer a retry.
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final fetched = await _api.getAllPlatformUsers();

    _loading = false;
    if (fetched == null) {
      _error = 'Could not load users. Check your connection and retry.';
    } else {
      _users
        ..clear()
        ..addAll(fetched);
      _loaded = true;
    }
    notifyListeners();
  }

  /// Removes a specific user (by backend id, falling back to name). Local-only:
  /// the backend exposes no delete endpoint yet.
  void remove(PlatformUser user) {
    final before = _users.length;
    _users.removeWhere((u) =>
        identical(u, user) ||
        (user.id.isNotEmpty && u.id == user.id) ||
        u.name == user.name);
    if (_users.length != before) notifyListeners();
  }

  /// Removes whichever user matches [name] — used when the admin approves a
  /// deletion request. No-op if the directory has no such user.
  void removeByName(String name) {
    final before = _users.length;
    _users.removeWhere((u) => u.name == name);
    if (_users.length != before) notifyListeners();
  }

  /// Test-only seam: replaces the directory with a known list so widget/unit
  /// tests can drive removal logic without a backend.
  @visibleForTesting
  void debugSeed(List<PlatformUser> users) {
    _users
      ..clear()
      ..addAll(users);
    _loaded = true;
    _error = null;
    notifyListeners();
  }
}
