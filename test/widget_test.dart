// Basic smoke test for the Sign In screen.
//
// The app itself boots into the SplashScreen (which navigates to Sign In on a
// timer), so this test pumps the SignInScreen directly — pumping the full app
// would only ever render the splash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self/sign_in_screen.dart';
import 'package:self/theme/app_theme.dart';

void main() {
  testWidgets('Sign In screen opens on OTP login (the primary method)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
    );

    expect(find.text('Welcome Back! 👋'), findsOneWidget);
    expect(find.textContaining('Vendor Registration'), findsOneWidget);

    // Both methods are offered; OTP is the one that is open.
    expect(find.text('OTP Login'), findsOneWidget);
    expect(find.text('Password Login'), findsOneWidget);
    expect(find.text('Send OTP →'), findsOneWidget);
    expect(find.text('Sign In →'), findsNothing);

    // No role picker on the login screen — the role comes from the account.
    expect(find.text('Vendor'), findsNothing);
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Marketing'), findsNothing);
    expect(find.text('Delivery'), findsNothing);
  });

  testWidgets('Password login stays available as the secondary method',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
    );

    await tester.tap(find.text('Password Login'));
    await tester.pumpAndSettle();

    expect(find.text('User ID (Mobile Number / Email)'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In →'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Send OTP →'), findsNothing);

    // ...and back to OTP.
    await tester.tap(find.text('OTP Login'));
    await tester.pumpAndSettle();
    expect(find.text('Send OTP →'), findsOneWidget);
  });
}
