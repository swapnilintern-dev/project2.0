// Smoke test: the Marketing Reports screen builds, cards select, the live
// reports show the file row, and the Stock report (no backend endpoint yet)
// shows its "coming soon" sheet without errors.
//
// Note: widget tests can't reach the real server (flutter_test's HttpClient
// returns HTTP 400 for everything), so the Order/Vendor download path is
// expected to surface an error SnackBar here — that still exercises the full
// generate flow without needing a network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self/marketing/reports_screen.dart';

void main() {
  testWidgets('reports screen renders and stock shows coming-soon sheet',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: MarketingReportsScreen()));

    expect(find.text('Vendor Report'), findsOneWidget);
    expect(find.text('Stock Report'), findsOneWidget);
    expect(find.text('Order Report'), findsOneWidget);
    expect(find.text('Select a report'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget); // stock badge

    // Pick the Order report → file info row appears.
    await tester.tap(find.text('Order Report'));
    await tester.pumpAndSettle();
    expect(find.text('Excel spreadsheet (.xlsx)'), findsOneWidget);

    // Generate with no reachable server → error SnackBar (not a crash).
    await tester.tap(find.text('Generate Order Report'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    // Stock report → "coming soon" bottom sheet instead of a download.
    await tester.tap(find.text('Stock Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Stock Report'));
    await tester.pumpAndSettle();
    expect(find.text('Stock Report — coming soon'), findsOneWidget);
  });
}
