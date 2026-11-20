// Regression tests for the bugs found while walking every role on the web
// build before launch. Each test names the bug it guards against.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:self/admin/admin_api.dart';
import 'package:self/customer/catalog.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/customer/product_card.dart';
import 'package:self/marketing/marketing_api.dart';
import 'package:self/marketing/marketing_models.dart';

void main() {
  group('Customer catalogue categories', () {
    test('Tablet / Capsule fall under the Medicine chip', () {
      // Bug: they normalised to "tablet"/"capsule", matched no chip, and were
      // only reachable through "All".
      for (final raw in ['Tablet', 'Capsule', 'Syrup', 'medicine', '']) {
        expect(Product.fromJson({'category': raw}).category, 'medicine',
            reason: raw);
      }
      expect(Product.fromJson({'category': 'Injection'}).category, 'injections');
      expect(Product.fromJson({'category': 'vaccines'}).category, 'vaccines');
    });

    test('the stored label is kept for display', () {
      final p = Product.fromJson({'category': 'Tablet'});
      expect(p.categoryLabel, 'Tablet');
      final back = Product.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.categoryLabel, 'Tablet');
      expect(back.category, 'medicine');
    });
  });

  group('Marketing edit keeps the stored category', () {
    const base = InventoryProduct(
        id: 'x', name: 'n', price: 1, stock: 0, active: true);

    test('untouched dropdown → original value ("Tablet" stays "Tablet")', () {
      final p = base.copyWith(category: 'Medicine', rawCategory: 'Tablet');
      expect(MarketingApi.categoryToSend(p), 'Tablet');
    });

    test('a different dropdown choice → the canonical id', () {
      final p = base.copyWith(
          category: 'Lifesaving Injections', rawCategory: 'Tablet');
      expect(MarketingApi.categoryToSend(p), 'injections');
    });

    test('a new product → the canonical id', () {
      expect(MarketingApi.categoryToSend(base.copyWith(category: 'Vaccines')),
          'vaccines');
    });

    test('rawCategory and packInfo come from the server', () async {
      final api = MarketingApi(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'products': [
                {
                  '_id': 'p1',
                  'title': 'Mycofit',
                  'price': 360,
                  'stock': 0,
                  'category': 'Tablet',
                  'packInfo': 'Strip of 10',
                },
              ],
            }),
            200)),
      );
      final list = await api.getProducts();
      expect(list!.single.rawCategory, 'Tablet');
      expect(list.single.category, 'Medicine');
      expect(list.single.packInfo, 'Strip of 10');
    });
  });

  test('Admin catalogue parses (quantity is a String on the server)', () async {
    // Bug: `quantity as num` threw on "1", the catch returned null, and the
    // admin Products screen showed "0 SKUs".
    final api = AdminApi(
      client: MockClient((_) async => http.Response(
          jsonEncode({
            'products': [
              {
                '_id': 'abcdef123456',
                'title': 'A',
                'price': 10,
                'stock': 7,
                'quantity': '1',
                'active': true
              },
              {
                '_id': 'abcdef654321',
                'title': 'B',
                'price': '5',
                'stock': 0,
                'quantity': '1',
                'active': false
              },
            ],
          }),
          200)),
    );
    final list = await api.getAllProducts();
    expect(list, hasLength(2));
    expect(list![0].stock, 7);
    expect(list[0].active, isTrue);
    expect(list[1].stock, 0);
    expect(list[1].active, isFalse);
    expect(list[1].price, 5);
  });

  testWidgets('a sold-out product says so on its card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const p = Product(
      id: 'p',
      title: 'Mycofit 500 Tablet',
      brand: 'Intas',
      description: '',
      price: 360,
      category: 'medicine',
      inStock: false,
    );
    Catalog.setProducts([p]);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 180, height: 260, child: ProductCard(product: p)),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('OUT OF STOCK'), findsOneWidget);
  });
}
