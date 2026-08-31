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
  testWidgets('Sign In screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
    );

    expect(find.text('Welcome Back! 👋'), findsOneWidget);
    expect(find.text('Sign In →'), findsOneWidget);
    expect(find.textContaining('Vendor Registration'), findsOneWidget);
  });
}
