// Medicine information (composition, uses, storage, side effects, precautions,
// directions) — parsing from the backend and placement on the details screen.
//
// The fields are display-only and optional: a product without them must look
// exactly as it did before, and none of them may disturb pricing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:self/customer/catalog.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/customer/medicine_info_section.dart';
import 'package:self/customer/product_details_screen.dart';
import 'package:self/services/buyer_pricing.dart';
import 'package:self/services/vendor_approval.dart';

/// Shaped like a real /all-products entry after the import.
Map<String, dynamic> _backendJson() => {
      '_id': 'abc123',
      'title': 'Mycofit 500 Tablet',
      'brand': 'Intas',
      'description': 'Immunosuppressant.',
      'price': 360,
      'mrp': 450,
      'category': 'Tablet',
      'stock': 50,
      'drDisPercent': '4',
      'wholesellerPercent': '5',
      'manufacturer': 'Intas Pharmaceuticals Ltd',
      'marketedBy': 'Intas Pharmaceuticals Ltd',
      'composition': 'Mycophenolate mofetil (500mg)',
      'uses': 'Prevention of organ rejection in transplant patients',
      'storage': 'Store below 30°C',
      'precautions': 'May lead to birth defects.',
      'directions': 'Take as advised by your doctor.',
      'sideEffects': ['Diarrhea', 'Vomiting', 'Pneumonia'],
    };

void main() {
  group('Product.fromJson — medicine info', () {
    test('reads every field from a real backend payload', () {
      final p = Product.fromJson(_backendJson());
      expect(p.composition, 'Mycophenolate mofetil (500mg)');
      expect(p.uses, startsWith('Prevention of organ rejection'));
      expect(p.storage, 'Store below 30°C');
      expect(p.precautions, 'May lead to birth defects.');
      expect(p.directions, 'Take as advised by your doctor.');
      expect(p.sideEffects, ['Diarrhea', 'Vomiting', 'Pneumonia']);
      expect(p.manufacturer, 'Intas Pharmaceuticals Ltd');
      expect(p.marketedBy, 'Intas Pharmaceuticals Ltd');
    });

    test('a product that predates the fields parses to empty values', () {
      final json = _backendJson()
        ..remove('composition')
        ..remove('uses')
        ..remove('storage')
        ..remove('precautions')
        ..remove('directions')
        ..remove('sideEffects')
        ..remove('manufacturer')
        ..remove('marketedBy');
      final p = Product.fromJson(json);
      expect(p.composition, isEmpty);
      expect(p.sideEffects, isEmpty);
      expect(MedicineInfoPanel.hasAny(p), isFalse);
    });

    test('null values never become the text "null"', () {
      final p = Product.fromJson(_backendJson()
        ..['composition'] = null
        ..['sideEffects'] = null);
      expect(p.composition, '');
      expect(p.sideEffects, isEmpty);
    });

    test('side effects: blanks dropped, a newline string is accepted', () {
      expect(
        Product.fromJson(_backendJson()..['sideEffects'] = ['  Nausea ', '', ' ']).sideEffects,
        ['Nausea'],
      );
      expect(
        Product.fromJson(_backendJson()..['sideEffects'] = 'Nausea\nHeadache\n').sideEffects,
        ['Nausea', 'Headache'],
      );
    });

    test('toJson → fromJson round-trip keeps every field', () {
      final p = Product.fromJson(_backendJson());
      final back = Product.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.composition, p.composition);
      expect(back.uses, p.uses);
      expect(back.storage, p.storage);
      expect(back.precautions, p.precautions);
      expect(back.directions, p.directions);
      expect(back.sideEffects, p.sideEffects);
      expect(back.manufacturer, p.manufacturer);
      expect(back.marketedBy, p.marketedBy);
    });

    test('pricing is untouched by the new fields', () {
      final p = Product.fromJson(_backendJson());
      expect(p.price, 360);
      expect(p.priceFor(BuyerPricingTier.retail), 360);
      expect(p.priceFor(BuyerPricingTier.doctor), closeTo(345.6, 0.001));
      expect(p.priceFor(BuyerPricingTier.wholeseller), closeTo(342, 0.001));
    });

    test('copyWith keeps medicine info AND the tier discounts', () {
      final p = Product.fromJson(_backendJson()).copyWith(title: 'Renamed');
      expect(p.title, 'Renamed');
      expect(p.composition, 'Mycophenolate mofetil (500mg)');
      expect(p.sideEffects, hasLength(3));
      expect(p.doctorDiscountPercent, 4);
      expect(p.wholesellerDiscountPercent, 5);
    });
  });

  group('MedicineCompanyLine.textFor', () {
    Product with_({String m = '', String mk = '', String brand = 'Brand'}) =>
        Product(
          id: 'x',
          title: 't',
          brand: brand,
          description: '',
          price: 1,
          category: 'medicine',
          manufacturer: m,
          marketedBy: mk,
        );

    test('same company is named once', () {
      expect(MedicineCompanyLine.textFor(with_(m: 'Intas', mk: 'intas')),
          'By intas');
    });
    test('different companies show both', () {
      expect(MedicineCompanyLine.textFor(with_(m: 'Maker', mk: 'Seller')),
          'Marketed by Seller · Mfd. by Maker');
    });
    test('only one known', () {
      expect(MedicineCompanyLine.textFor(with_(m: 'Maker')), 'Mfd. by Maker');
      expect(MedicineCompanyLine.textFor(with_(mk: 'Seller')), 'By Seller');
    });
    test('neither known → the brand line the screen always showed', () {
      expect(MedicineCompanyLine.textFor(with_()), 'Brand');
    });
  });

  group('Product details screen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      VendorApproval.instance.clear();
      VendorApproval.instance
          .adoptFromAuthResponse({'approvalStatus': 'Approved'});
    });

    Future<void> pump(WidgetTester tester, Product p) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Catalog.setProducts([p]);
      await tester.pumpWidget(MaterialApp(home: ProductDetailsScreen(product: p)));
      await tester.pump();
    }

    testWidgets(
        'order: name, MRP/price, composition, marketer, storage, product '
        'information, precautions, uses, side effects, directions, quantity, '
        'disclaimer last', (tester) async {
      final p = Product.fromJson(_backendJson());
      await pump(tester, p);

      double y(Finder f) => tester.getTopLeft(f).dy;
      final order = <String, double>{
        'name': y(find.text('Mycofit 500 Tablet').last),
        'price': y(find.text('₹360').first),
        'mrp': y(find.text('₹450').first),
        'composition': y(find.text('Mycophenolate mofetil (500mg)')),
        'marketer': y(find.text('By Intas Pharmaceuticals Ltd')),
        'storage': y(find.text('Store below 30°C')),
        'product information': y(find.text('Product Information')),
        'precautions': y(find.text('Precautions')),
        'uses': y(find.text('Uses of Product')),
        'side effects': y(find.text('Side Effects (3)')),
        'directions': y(find.text('Directions of Use')),
        'quantity': y(find.text('Quantity')),
        'disclaimer': y(find.textContaining('Medical Information Disclaimer')),
      };
      // price and MRP sit on the same line; everything else strictly follows.
      const sequence = [
        'name', 'price', 'composition', 'marketer', 'storage',
        'product information', 'precautions', 'uses', 'side effects',
        'directions', 'quantity', 'disclaimer',
      ];
      for (var i = 1; i < sequence.length; i++) {
        expect(order[sequence[i]], greaterThan(order[sequence[i - 1]]!),
            reason: '${sequence[i]} should be below ${sequence[i - 1]}');
      }
      expect(order['mrp'], greaterThan(order['name']!));
      expect(order['composition'], greaterThan(order['mrp']!));
    });

    testWidgets('disclaimer is the last thing on the page', (tester) async {
      final p = Product.fromJson(_backendJson());
      final other = Product.fromJson(_backendJson()
        ..['_id'] = 'other1'
        ..['title'] = 'Mycofit 250 Tablet');
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Catalog.setProducts([p, other]);
      await tester.pumpWidget(MaterialApp(home: ProductDetailsScreen(product: p)));
      await tester.pump();

      final related = tester.getTopLeft(find.text('Related Products')).dy;
      final disclaimer = tester
          .getTopLeft(find.textContaining('Medical Information Disclaimer'))
          .dy;
      expect(disclaimer, greaterThan(related));
    });

    testWidgets('composition / storage / uses are not repeated in the description',
        (tester) async {
      // Shaped like the live data: the company import appended these lines
      // to every description.
      final p = Product.fromJson(_backendJson()
        ..['description'] = 'Mycofit is an immunosuppressant.\n\n'
            'Composition: Mycophenolate mofetil (500mg)\n'
            'Uses: Prevention of organ rejection in transplant patients\n'
            'Storage: Store below 30°C');
      await pump(tester, p);

      expect(find.text('Mycofit is an immunosuppressant.'), findsOneWidget);
      expect(find.textContaining('Mycophenolate mofetil'), findsOneWidget);
      expect(find.textContaining('Store below 30°C'), findsOneWidget);
      expect(find.textContaining('Prevention of organ rejection'),
          findsOneWidget);
      expect(find.textContaining('Composition:'), findsNothing);
    });

    testWidgets('sections: Uses open, the rest expand on tap', (tester) async {
      await pump(tester, Product.fromJson(_backendJson()));

      expect(find.text('Uses of Product'), findsOneWidget);
      expect(find.text('Prevention of organ rejection in transplant patients'),
          findsOneWidget);
      expect(find.text('Side Effects (3)'), findsOneWidget);
      expect(find.text('Precautions'), findsOneWidget);
      expect(find.text('Directions of Use'), findsOneWidget);

      // Collapsed until tapped.
      expect(find.text('Pneumonia'), findsNothing);
      await tester.tap(find.text('Side Effects (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Diarrhea'), findsOneWidget);
      expect(find.text('Pneumonia'), findsOneWidget);

      await tester.tap(find.text('Precautions'));
      await tester.pumpAndSettle();
      expect(find.text('May lead to birth defects.'), findsOneWidget);
    });

    testWidgets('a product with no medicine info looks as before',
        (tester) async {
      const plain = Product(
        id: 'p1',
        title: 'Paracetamol 650 mg Tablet',
        brand: 'VS Arogya',
        description: 'Fever and pain relief.',
        price: 720,
        category: 'tablets',
        stockCount: 40,
      );
      await pump(tester, plain);

      expect(find.text('VS Arogya'), findsOneWidget); // old brand line
      expect(find.text('Composition'), findsNothing);
      expect(find.text('Uses of Product'), findsNothing);
      expect(find.textContaining('Side Effects'), findsNothing);
      expect(find.text('Precautions'), findsNothing);
      expect(find.text('Directions of Use'), findsNothing);
      expect(find.text('₹720'), findsOneWidget);
      expect(find.text('Fever and pain relief.'), findsOneWidget);
      // The disclaimer shows on every product, info or not.
      expect(find.textContaining('Medical Information Disclaimer'),
          findsOneWidget);
    });

    testWidgets('only the sections that have data are shown', (tester) async {
      final p = Product.fromJson(_backendJson()
        ..['sideEffects'] = []
        ..['precautions'] = ''
        ..['storage'] = '');
      await pump(tester, p);

      expect(find.text('Mycophenolate mofetil (500mg)'), findsOneWidget);
      expect(find.text('Uses of Product'), findsOneWidget);
      expect(find.text('Directions of Use'), findsOneWidget);
      expect(find.textContaining('Side Effects'), findsNothing);
      expect(find.text('Precautions'), findsNothing);
      expect(find.text('Storage: '), findsNothing);
    });
  });

  group('descriptionFor', () {
    Product withDesc(String d, {String comp = 'X (1mg)', String storage = 'Cool',
            String uses = 'Pain'}) =>
        Product.fromJson(_backendJson()
          ..['description'] = d
          ..['composition'] = comp
          ..['storage'] = storage
          ..['uses'] = uses);

    test('drops the appended lines and trailing blank lines', () {
      expect(
          descriptionFor(withDesc(
              'Body text.\n\nComposition: X (1mg)\nUses: Pain\nStorage: Cool')),
          'Body text.');
    });

    test('keeps a line whose field is empty, so nothing is lost', () {
      expect(
          descriptionFor(withDesc('Body.\nComposition: X (1mg)\nStorage: Cool',
              storage: '')),
          'Body.\nStorage: Cool');
    });

    test('a plain description is untouched', () {
      expect(descriptionFor(withDesc('Fever relief: fast acting.')),
          'Fever relief: fast acting.');
    });

    test('only the labelled lines go, not text that merely mentions them', () {
      expect(
          descriptionFor(withDesc('Check the composition before use.\n'
              'Composition: X (1mg)')),
          'Check the composition before use.');
    });
  });
}
