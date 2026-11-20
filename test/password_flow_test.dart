// =============================================================================
// VS Arogya — Password flows test
//
// Drives the REAL screens:
//   1. Forgot Password: Email → OTP → New Password
//   2. Change Password (signed in): New + Confirm
//
// WHAT CHANGED AND WHY: both screens used to be stubs that waited ~700ms and
// then always showed a success page. They now call the backend
// (POST /eotp, /eotp-verify, PUT /update-password), so "it reached the success
// screen" is no longer something a test can assert without a server — and
// asserting it anyway is exactly the bug these tests exist to catch.
//
// These tests therefore cover what is verifiable offline, and what matters most:
//   • client-side validation rejects bad input BEFORE any network call;
//   • a failed call reports the failure instead of showing a success screen.
//
// The end-to-end path (real OTP → password actually written to MongoDB) is
// covered by test/password_live_test.dart, which runs against a live server.
//
// The Forgot Password screen runs a 30s resend Timer.periodic, so we step with
// explicit pump(duration) instead of pumpAndSettle (which would hang on it).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self/auth/change_password_screen.dart';
import 'package:self/auth/forgot_password_screen.dart';
import 'package:self/services/auth_service.dart';

void main() {
  testWidgets('Forgot Password: the first step asks for an EMAIL, not a mobile',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.pump();

    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    // Mobile OTP needs a DLT registration that is still pending, so the screen
    // must not be asking for a phone number.
    expect(find.text('Mobile Number'), findsNothing);
  });

  testWidgets('Forgot Password: a mobile number is rejected before any request',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    // Validation fires locally — the screen never advances to the OTP step.
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Verify'), findsNothing);
  });

  testWidgets('Change Password: a mismatch is rejected locally',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), 'newpass123');
    await tester.enterText(fields.at(1), 'different99');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(find.text('Password Updated Successfully'), findsNothing);
  });

  testWidgets('Change Password: without a session it reports failure, '
      'never a fake success', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // No token → AccountApi refuses before it reaches the network, so this test
    // stays offline and deterministic.
    AuthService.clearSession();

    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'newpass123');
    await tester.enterText(fields.at(1), 'newpass123');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    // The whole point: the old stub showed success here regardless.
    expect(find.text('Could not update password'), findsOneWidget);
    expect(find.text('Password Updated Successfully'), findsNothing);
  });
}
