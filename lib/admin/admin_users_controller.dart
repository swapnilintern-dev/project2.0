// =============================================================================
// MediCaPlus — Admin · Users store
//
// A mutable, observable copy of the platform-user directory so the Admin can
// remove a Vendor or Delivery Agent and have the Users screen update live.
// Seeded from the static `kUsers` dummy data (admin_models.dart).
//
// TODO(backend): replace the seed with GET /api/admin/users, and make `remove`
// call DELETE /api/admin/users/:id so the account is removed from MongoDB too.
// =============================================================================

import 'package:flutter/foundation.dart';

import 'admin_models.dart';

class AdminUsersController extends ChangeNotifier {
  AdminUsersController._();
  static final AdminUsersController instance = AdminUsersController._();

  // Modifiable copy — kUsers itself is a const list.
  final List<PlatformUser> _users = List.of(kUsers);

  List<PlatformUser> get users => List.unmodifiable(_users);

  List<PlatformUser> byKind(UserKind kind) =>
      _users.where((u) => u.kind == kind).toList();

  /// Removes a specific user (by identity, falling back to name).
  /// TODO(backend): DELETE /api/admin/users/:id — also deletes from MongoDB.
  void remove(PlatformUser user) {
    final before = _users.length;
    _users.removeWhere((u) => identical(u, user) || u.name == user.name);
    if (_users.length != before) notifyListeners();
  }

  /// Removes whichever user matches [name] — used when the admin approves a
  /// deletion request. No-op if the directory has no such user.
  void removeByName(String name) {
    final before = _users.length;
    _users.removeWhere((u) => u.name == name);
    if (_users.length != before) notifyListeners();
  }
}
