// Email-OTP guest (no account yet, or a vendor not yet approved) → browse-only.
//
// The server answers such a sign-in with role "guest" and approvalStatus
// "Not Registered" / "Pending" / "Rejected". The catalogue cards must then show
// a blurred placeholder instead of the price, and nothing may reach the cart.
// An approved vendor is unaffected.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:self/customer/catalog.dart';
import 'package:self/customer/customer_controllers.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/customer/price_gate.dart';
import 'package:self/customer/product_card.dart';
import 'package:self/services/vendor_approval.dart';

void main() {
  const product = Product(
    id: 'p1',
    title: 'Paracetamol 650 mg Tablet',
    brand: 'VS Arogya',
    description: 'Fever and pain relief.',
    price: 720,
    mrp: 900,
    category: 'tablets',
    stockCount: 40,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Catalog.setProducts([product]);
    VendorApproval.instance.clear();
    CartController.instance.clear();
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 280,
              child: ProductCard(product: product),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final status in ['Not Registered', 'Pending', 'Rejected']) {
    testWidgets('guest ($status): card shows a blurred price, no real amount', (
      tester,
    ) async {
      VendorApproval.instance.adoptFromAuthResponse({'approvalStatus': status});
      await pumpCard(tester);

      expect(find.byType(LockedPrice), findsOneWidget);
      expect(find.textContaining('720'), findsNothing);
      expect(find.textContaining('900'), findsNothing);
    });
  }

  testWidgets('guest: tapping + adds nothing and offers registration', (
    tester,
  ) async {
    VendorApproval.instance.adoptFromAuthResponse({
      'approvalStatus': 'Not Registered',
    });
    await pumpCard(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(CartController.instance.isEmpty, isTrue);
    expect(find.text('REGISTER'), findsOneWidget);
  });

  test('guest: the cart refuses items even if a screen forgets to ask', () {
    VendorApproval.instance.adoptFromAuthResponse({
      'approvalStatus': 'Not Registered',
    });

    expect(CartController.instance.add(product), 0);
    expect(CartController.instance.isEmpty, isTrue);
  });

  testWidgets('approved vendor: card shows the real price', (tester) async {
    VendorApproval.instance.adoptFromAuthResponse({
      'approvalStatus': 'Approved',
    });
    await pumpCard(tester);

    expect(find.byType(LockedPrice), findsNothing);
    expect(find.textContaining('720'), findsOneWidget);
  });
}
