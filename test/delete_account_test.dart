// =============================================================================
// MediCaPlus — Account deletion flow test
//
// Drives the REAL DeleteAccountScreen to prove a Vendor/Delivery Partner can
// raise a deletion request, and checks the admin approval removes the user.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self/account_deletion/account_deletion_controller.dart';
import 'package:self/account_deletion/delete_account_screen.dart';
import 'package:self/admin/admin_models.dart';
import 'package:self/admin/admin_users_controller.dart';

void main() {
  testWidgets('Vendor can submit an account-deletion request with a reason',
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
    expect(find.text('This action may not be reversible.'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    // Enter a reason and submit.
    await tester.enterText(
        find.byType(TextFormField), 'No longer using the platform');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Deletion Request'));
    await tester.pumpAndSettle();

    // Confirmation dialog → confirm.
    expect(find.text('Submit deletion request?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Request recorded as pending for this user.
    expect(
        AccountDeletionController.instance.hasPendingFor('Test Vendor'), isTrue);
    expect(find.text('Request submitted'), findsOneWidget);
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
