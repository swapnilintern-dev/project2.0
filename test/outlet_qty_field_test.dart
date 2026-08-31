// Regression pin for the Outlet quantity field.
//
// The app-wide inputDecorationTheme sets `filled: true` with a WHITE fillColor
// (lib/theme/app_theme.dart). The filled variant of this control draws white
// text on the brand gradient, so if it ever stops overriding `filled` the theme
// paints a white box behind the number and the typed quantity becomes invisible.
// That happened once; this test is what stops it happening again.
//
// It is pumped under the REAL app theme, because the bug only exists under it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self/outlet/outlet_qty_field.dart';
import 'package:self/theme/app_theme.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  TextField fieldOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  testWidgets('the typed quantity is never hidden behind the theme fill',
      (tester) async {
    await tester.pumpWidget(host(OutletQtyField(
      qty: 10,
      max: 41,
      onSet: (_) {},
      onRemove: () {},
    )));

    final field = fieldOf(tester);

    // The whole point: no theme-supplied white box over the gradient.
    expect(field.decoration!.filled, isFalse);

    // And the number itself is white + heavy, so it reads on the gradient.
    expect(field.style!.color, Colors.white);
    expect(field.style!.fontWeight, FontWeight.w900);

    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('typing a quantity above the batch ceiling is corrected on screen',
      (tester) async {
    var qty = 10;
    const max = 41;

    await tester.pumpWidget(host(
      StatefulBuilder(
        builder: (context, setState) => OutletQtyField(
          qty: qty,
          max: max,
          // Mirrors OutletCart's clamp, which is what the real owner does.
          onSet: (v) => setState(() => qty = v > max ? max : v),
          onRemove: () {},
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '99');
    await tester.pump();

    expect(qty, max, reason: 'the owner clamped it');
    // The field must show the clamped value, not the rejected one.
    expect(find.text('41'), findsOneWidget);
    expect(find.text('99'), findsNothing);
  });

  testWidgets('an empty field never deletes the line mid-edit', (tester) async {
    var qty = 7;
    var removed = false;

    await tester.pumpWidget(host(
      StatefulBuilder(
        builder: (context, setState) => OutletQtyField(
          qty: qty,
          max: 20,
          onSet: (v) => setState(() => qty = v),
          onRemove: () => removed = true,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(qty, 7, reason: 'a blank box is mid-edit, not a request for zero');
    expect(removed, isFalse);
  });
}
