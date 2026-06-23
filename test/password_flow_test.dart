// =============================================================================
// MediCaPlus — Password flows test
//
// Drives the REAL screens:
//   1. Forgot Password: Mobile → OTP → New Password → "Password Changed
//      Successfully".
//   2. Change Password (logged in, no OTP): New + Confirm → "Password Updated
//      Successfully".
//
// The Forgot Password screen runs a 30s resend Timer.periodic, so we step with
// explicit pump(duration) instead of pumpAndSettle (which would hang on it).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self/auth/change_password_screen.dart';
import 'package:self/auth/forgot_password_screen.dart';

void main() {
  testWidgets('Forgot Password: mobile → OTP → new password → success',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.pump();

    // Step 1 — mobile number.
    expect(find.text('Send OTP'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pump(); // busy state
    await tester.pump(const Duration(milliseconds: 800)); // finish + go to OTP

    // Step 2 — OTP (6 boxes).
    expect(find.text('Verify'), findsOneWidget);
    final boxes = find.byType(TextField);
    expect(boxes, findsNWidgets(6));
    for (int i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
      await tester.pump();
    }
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // → new password

    // Step 3 — new password.
    expect(find.text('Change Password'), findsOneWidget);
    final passFields = find.byType(TextFormField);
    expect(passFields, findsNWidgets(2));
    await tester.enterText(passFields.at(0), 'newpass123');
    await tester.enterText(passFields.at(1), 'newpass123');
    await tester.tap(find.text('Change Password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // → success

    // Step 4 — success (resend timer is cancelled here).
    await tester.pumpAndSettle();
    expect(find.text('Password Changed Successfully'), findsOneWidget);
    expect(find.text('Back To Login'), findsOneWidget);
  });

  testWidgets('Change Password (logged in): rejects mismatch, then succeeds',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));

    // Mismatched passwords are rejected.
    await tester.enterText(fields.at(0), 'newpass123');
    await tester.enterText(fields.at(1), 'different99');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(find.text('Password Updated Successfully'), findsNothing);

    // Matching passwords succeed.
    await tester.enterText(fields.at(1), 'newpass123');
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Password Updated Successfully'), findsOneWidget);
  });
}
