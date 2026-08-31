// Smoke test for the Outlet Stock screen — the entry point of the manual-order
// flow. It builds the real screen against the real repository (which, with no
// signed-in outlet, resolves to the demo datasource) so the whole widget tree is
// exercised end-to-end.
//
// What it pins:
//   • the DISTRICT option is gone — not hidden, gone. The list states its single
//     scope ("Only outlet stock") and offers no way to browse another outlet;
//   • every row exposes "+ Add", which starts the batch-selection step rather
//     than dropping the medicine straight into the cart;
//   • nothing is added to the cart until a batch has been chosen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self/outlet/outlet_cart.dart';
import 'package:self/outlet/outlet_session.dart';
import 'package:self/outlet/screens/outlet_stock_screen.dart';

void main() {
  setUp(() {
    OutletSession.instance.clear();
    OutletCart.instance.clear();
  });

  testWidgets('shows only outlet stock — the district option does not exist',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OutletStockScreen(onAddToCart: (_, _) {}),
      ),
    ));

    // Let the datasource's simulated latency elapse.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Only outlet stock'), findsOneWidget);
    expect(find.text('District'), findsNothing);
    expect(find.text('My outlet'), findsNothing);
    expect(find.text('Read-only'), findsNothing);

    // The search and category filters stay.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Medicine'), findsOneWidget);

    // Rows are addable, and adding starts with the batch step — so nothing has
    // reached the cart yet.
    expect(find.text('Add'), findsWidgets);
    expect(OutletCart.instance.isEmpty, isTrue);
  });

  testWidgets('tapping Add opens the batch picker instead of adding directly',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OutletStockScreen(onAddToCart: (_, _) {}),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Add').first);
    await tester.pump();

    expect(find.text('Select batch'), findsOneWidget);
    // Still nothing in the cart: a lot has to be chosen first.
    expect(OutletCart.instance.isEmpty, isTrue);

    // Let the picker's own (demo-session) batch read resolve.
    await tester.pump(const Duration(milliseconds: 600));
  });
}
