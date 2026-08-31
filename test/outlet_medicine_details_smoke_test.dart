// Smoke test for the Outlet Stock → Medicine Details screen.
//
// It builds the real screen against the real repository, so the whole widget
// tree (header, shimmer, error state) is exercised end-to-end. With no signed-in
// outlet the live datasource has nothing to scope a batch read to, so it must
// say so and offer a retry — NOT render an empty batch list, which would read as
// "this medicine has no stock" to someone standing at the counter.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self/outlet/outlet_models.dart';
import 'package:self/outlet/outlet_session.dart';
import 'package:self/outlet/screens/outlet_medicine_details_screen.dart';

void main() {
  const item = OutletStockItem(
    id: 'p1',
    name: 'Paracetamol 650 mg Tablet',
    price: 31,
    qtyAvailable: 794,
    isOwnOutlet: true,
    packSize: '15 tablets',
    batch: 'PAR650A2507',
    batchCount: 2,
  );

  setUp(() => OutletSession.instance.clear());

  testWidgets('renders the tapped medicine while the live detail loads',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OutletMedicineDetailsScreen(item: item),
    ));
    await tester.pump();

    // The name is on screen immediately — the header never waits on the fetch.
    expect(find.text('Paracetamol 650 mg Tablet'), findsOneWidget);
    expect(find.text('Batch-wise stock in your outlet'), findsOneWidget);

    // Let the fetch resolve so the shimmer's repeating ticker is disposed
    // before the test ends.
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('surfaces the failure with a retry instead of an empty list',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OutletMedicineDetailsScreen(item: item),
    ));

    // Let the datasource's simulated latency elapse (no pumpAndSettle: the
    // loading shimmer animates forever by design).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Could not load this medicine'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

    // Nothing may imply the outlet holds no stock when the read simply failed.
    expect(find.text('No Batch Available'), findsNothing);
    expect(find.text('Available Batches'), findsNothing);
  });
}
