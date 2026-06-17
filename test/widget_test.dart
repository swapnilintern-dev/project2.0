// Basic smoke test for the MediCaPlus app entry point (Sign In screen).

import 'package:flutter_test/flutter_test.dart';

import 'package:self/main.dart';

void main() {
  testWidgets('Sign In screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MediCaPlusApp());

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Sign In →'), findsOneWidget);
    expect(find.text('New Vendor Registration'), findsOneWidget);
  });
}
