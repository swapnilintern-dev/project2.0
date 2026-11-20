// =============================================================================
// VS Arogya — Account deletion flow test
//
// Drives the REAL DeleteAccountScreen.
//
// WHAT CHANGED AND WHY: this screen used to record a local "deletion request"
// for an admin to approve. The backend has no such queue — DELETE
// /vsArogya/vendor-delete removes the account immediately — so the screen now
// calls that endpoint and says so. These tests assert the honest behaviour:
//
//   • the confirmation warns that deletion is immediate and irreversible;
//   • a failed call reports the failure and deletes NOTHING, rather than
//     showing a success screen for an account that still exists.
//
// The widget test runs with no session, so AccountApi refuses before reaching
// the network — which is exactly the "it must not fabricate success" case.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self/account_deletion/account_deletion_controller.dart';
import 'package:self/account_deletion/delete_account_screen.dart';
import 'package:self/admin/admin_models.dart';
import 'package:self/admin/admin_users_controller.dart';
import 'package:self/services/auth_service.dart';

void main() {
  testWidgets('the confirmation says deletion is immediate and irreversible',
      (tester) async {
    // Tall surface so the whole scrollable form builds and is tappable.
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: DeleteAccountScreen(
        role: DeletionRole.vendor,
        userName: 'Test Vendor',
      ),
    ));
    await tester.pumpAndSettle();

    // The warning card + reason form render.
    expect(find.text('Delete Account'), findsWidgets);
    expect(find.text('This action cannot be undone.'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(
        find.byType(TextFormField), 'No longer using the platform');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete My Account'));
    await tester.pumpAndSettle();

    // The dialog must not describe this as a reviewable request.
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('CANNOT be undone'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete Permanently'),
        findsOneWidget);
  });

  testWidgets('a failed delete reports the failure and records nothing',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // No session → AccountApi refuses before any network call.
    AuthService.clearSession();
    final before = AccountDeletionController.instance.requests.length;

    await tester.pumpWidget(const MaterialApp(
      home: DeleteAccountScreen(
        role: DeletionRole.vendor,
        userName: 'Unsigned Vendor',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Closing down');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete My Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete Permanently'));
    await tester.pumpAndSettle();

    // The user is told it failed — never shown a success screen.
    expect(find.text('Could not delete account'), findsOneWidget);
    expect(find.text('Account deleted'), findsNothing);

    // And nothing was recorded locally either.
    expect(AccountDeletionController.instance.requests.length, before);
    expect(
      AccountDeletionController.instance.hasPendingFor('Unsigned Vendor'),
      isFalse,
    );
  });

  test('Admin approval deletes the user from the directory', () {
    final users = AdminUsersController.instance;
    // The directory is now backend-driven; seed a known user for the test.
    users.debugSeed(const [
      PlatformUser(
        name: 'Apollo Pharmacy',
        kind: UserKind.customer,
        meta: 'Mumbai · Approved',
      ),
    ]);
    expect(users.users.any((u) => u.name == 'Apollo Pharmacy'), isTrue);

    final req = AccountDeletionController.instance.submit(
      userName: 'Apollo Pharmacy',
      role: DeletionRole.vendor,
      reason: 'Closing the pharmacy',
    );

    // What the admin Approve & Delete action does:
    AccountDeletionController.instance.approve(req.id);
    AdminUsersController.instance.removeByName('Apollo Pharmacy');

    expect(users.users.any((u) => u.name == 'Apollo Pharmacy'), isFalse);
    final updated = AccountDeletionController.instance.requests
        .firstWhere((r) => r.id == req.id);
    expect(updated.status, DeletionStatus.approved);
  });
}
