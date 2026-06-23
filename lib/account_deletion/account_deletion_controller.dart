// =============================================================================
// MediCaPlus — Account Deletion (Play Store data-safety requirement)
//
// In-app account-deletion REQUEST flow. A Vendor or Delivery Partner submits a
// request with a reason; it lands here and the Admin reviews it (approve /
// reject). This is the client-side store only — no backend.
//
// Why a request (not an instant self-delete): Google Play accepts an in-app
// path to *initiate* deletion, and VS Arogya wants the admin team to action it
// (B2B accounts have outstanding orders / dues). Admin can also delete a user
// directly from the Users screen (see lib/admin/admin_users_controller.dart).
//
// TODO(backend): wire these methods to the server (POST a request, PATCH its
// status) and let the server perform the actual MongoDB deletion. Keep the
// signatures — the screens won't need to change.
// =============================================================================

import 'package:flutter/foundation.dart';

/// Which kind of account asked to be deleted. Only these two roles can — Admin
/// and Marketing are internal staff and never see the Delete Account option.
enum DeletionRole { vendor, delivery }

extension DeletionRoleX on DeletionRole {
  String get label => switch (this) {
        DeletionRole.vendor => 'Vendor',
        DeletionRole.delivery => 'Delivery Partner',
      };
}

enum DeletionStatus { pending, approved, rejected }

extension DeletionStatusX on DeletionStatus {
  String get label => switch (this) {
        DeletionStatus.pending => 'Pending',
        DeletionStatus.approved => 'Approved',
        DeletionStatus.rejected => 'Rejected',
      };
}

@immutable
class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.userName,
    required this.role,
    required this.reason,
    required this.requestedAt,
    this.contact = '',
    this.status = DeletionStatus.pending,
  });

  final String id;
  final String userName;
  final DeletionRole role;
  final String reason;
  final DateTime requestedAt;
  final String contact;
  final DeletionStatus status;

  AccountDeletionRequest copyWith({DeletionStatus? status}) =>
      AccountDeletionRequest(
        id: id,
        userName: userName,
        role: role,
        reason: reason,
        requestedAt: requestedAt,
        contact: contact,
        status: status ?? this.status,
      );
}

/// Single in-memory store of deletion requests, shared by the requester
/// screens (vendor/delivery) and the admin review screen.
class AccountDeletionController extends ChangeNotifier {
  AccountDeletionController._();
  static final AccountDeletionController instance =
      AccountDeletionController._();

  final List<AccountDeletionRequest> _requests = [];

  /// Newest first.
  List<AccountDeletionRequest> get requests =>
      List.unmodifiable(_requests.reversed);

  List<AccountDeletionRequest> byStatus(DeletionStatus status) =>
      requests.where((r) => r.status == status).toList();

  int get pendingCount =>
      _requests.where((r) => r.status == DeletionStatus.pending).length;

  /// True when this user already has a request awaiting review — used to stop
  /// duplicate submissions.
  bool hasPendingFor(String userName) => _requests.any(
      (r) => r.userName == userName && r.status == DeletionStatus.pending);

  AccountDeletionRequest? latestFor(String userName) {
    for (final r in requests) {
      if (r.userName == userName) return r;
    }
    return null;
  }

  /// Files a new request. Returns it so the caller can show a reference id.
  /// TODO(backend): POST /api/account/deletion-request.
  AccountDeletionRequest submit({
    required String userName,
    required DeletionRole role,
    required String reason,
    String contact = '',
  }) {
    final req = AccountDeletionRequest(
      id: 'DEL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      userName: userName,
      role: role,
      reason: reason.trim(),
      requestedAt: DateTime.now(),
      contact: contact,
    );
    _requests.add(req);
    notifyListeners();
    return req;
  }

  /// Admin approves — the account should now be deleted server-side.
  /// TODO(backend): PATCH /api/admin/deletion-requests/:id { status: approved }
  /// then DELETE the user document.
  void approve(String id) => _setStatus(id, DeletionStatus.approved);

  /// Admin rejects the request (account is kept).
  /// TODO(backend): PATCH /api/admin/deletion-requests/:id { status: rejected }
  void reject(String id) => _setStatus(id, DeletionStatus.rejected);

  void _setStatus(String id, DeletionStatus status) {
    final i = _requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    _requests[i] = _requests[i].copyWith(status: status);
    notifyListeners();
  }
}
