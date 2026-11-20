// "Doctor" as a vendor type on the registration form.
//
// The value is sent to POST /register-vendor exactly as picked (vendor_type is
// a free string on the server), and every pricing check maps it to the doctor
// rate — the same rate a Hospital / Clinic gets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:self/services/buyer_pricing.dart';
import 'package:self/vendor_registration_screen.dart';

void main() {
  testWidgets('the Vendor Type dropdown offers Doctor and it can be picked',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: VendorRegistrationScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select vendor type'));
    await tester.pumpAndSettle();

    // All three options are in the open menu, in this order.
    final shop = tester.getTopLeft(find.text('Shop / Pharmacy').last).dy;
    final hospital = tester.getTopLeft(find.text('Hospital / Clinic').last).dy;
    final doctor = tester.getTopLeft(find.text('Doctor').last).dy;
    expect(hospital, greaterThan(shop));
    expect(doctor, greaterThan(hospital));

    await tester.tap(find.text('Doctor').last);
    await tester.pumpAndSettle();

    expect(find.text('Select vendor type'), findsNothing);
    expect(find.text('Doctor'), findsOneWidget);
  });

  test('a Doctor account gets the doctor rate whatever the shop type', () {
    BuyerPricingTier t(String s) =>
        BuyerPricing.tierFrom(vendorType: 'Doctor', shopType: s);
    expect(t('Retail Pharmacy'), BuyerPricingTier.doctor);
    expect(t('Wholesale Pharmacy'), BuyerPricingTier.doctor);
    expect(t('Hospital Pharmacy'), BuyerPricingTier.doctor);
    expect(t(''), BuyerPricingTier.doctor);
  });
}
