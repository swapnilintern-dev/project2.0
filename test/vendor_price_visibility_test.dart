// Vendor approval → distributor price visibility on the Product Details screen.
//
// An unapproved vendor must never see the price — not in the price block, not
// in the Add to Cart button. An approved vendor sees exactly what the screen
// always showed. The approval state itself comes from the backend's
// `approvalStatus` field (VendorApproval.adoptFromAuthResponse); nothing here
// approves anyone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:self/customer/catalog.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/customer/product_details_screen.dart';
import 'package:self/services/vendor_approval.dart';
import 'package:self/vendor_registration_screen.dart';
import 'package:self/vendor_status_screen.dart';

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
    // Seed the catalogue so the screen doesn't try to fetch products.
    Catalog.setProducts([product]);
    VendorApproval.instance.clear();
  });

  Future<void> pumpDetails(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductDetailsScreen(product: product)),
    );
    await tester.pump();
  }

  testWidgets('unapproved vendor sees no price, only the registration CTA',
      (tester) async {
    VendorApproval.instance
        .adoptFromAuthResponse({'approvalStatus': 'Pending'});
    await pumpDetails(tester);

    // The price appears nowhere on the screen.
    expect(find.textContaining('720'), findsNothing);
    expect(find.textContaining('900'), findsNothing);

    expect(find.text('Distributor Price'), findsOneWidget);
    expect(find.text('Available after vendor verification'), findsOneWidget);
    // Pending registration → the status screen, not a second registration form.
    expect(find.text('View Registration Status'), findsWidgets);
    expect(find.textContaining('Add to Cart'), findsNothing);
  });

  testWidgets('a vendor with no registration is sent to the existing '
      'VendorRegistrationScreen', (tester) async {
    VendorApproval.instance
        .adoptFromAuthResponse({'approvalStatus': 'Not registered'});
    await pumpDetails(tester);

    expect(find.text('Complete Vendor Registration'), findsWidgets);
    await tester.tap(find.text('Complete Vendor Registration').last);
    await tester.pumpAndSettle();

    expect(find.byType(VendorRegistrationScreen), findsOneWidget);
  });

  testWidgets('a rejected vendor can reach the resubmit path', (tester) async {
    VendorApproval.instance
        .adoptFromAuthResponse({'approvalStatus': 'Rejected'});
    await pumpDetails(tester);

    expect(find.text('Update & Resubmit'), findsWidgets);
    await tester.tap(find.text('Update & Resubmit').last);
    await tester.pumpAndSettle();

    expect(find.byType(VendorStatusScreen), findsOneWidget);
    expect(find.text('Registration Rejected'), findsOneWidget);

    // ...and from there back into the EXISTING registration flow.
    await tester.tap(find.text('Update & Resubmit'));
    await tester.pumpAndSettle();
    expect(find.byType(VendorRegistrationScreen), findsOneWidget);
  });

  testWidgets('approved vendor sees the price and can still add to cart',
      (tester) async {
    VendorApproval.instance
        .adoptFromAuthResponse({'approvalStatus': 'Approved'});
    await pumpDetails(tester);

    expect(find.text('₹720'), findsOneWidget);
    expect(find.textContaining('Add to Cart'), findsOneWidget);
    expect(find.text('Available after vendor verification'), findsNothing);
  });

  test('an absent backend field leaves the status unknown', () {
    VendorApproval.instance.adoptFromAuthResponse({'success': true});
    expect(VendorApproval.instance.status, VendorApprovalStatus.unknown);
    // Fail closed: "no field" must never unlock prices.
    expect(VendorApproval.instance.canSeePrices, isFalse);
  });
}
