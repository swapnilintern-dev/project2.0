// =============================================================================
// MediCaPlus — Catalog/stock sync test
//
// Drives the REAL customer Search screen (ProductListScreen) and the shared
// store to prove the two behaviours the feature is about:
//   1. A medicine the Marketing Head adds shows up live on the customer portal.
//   2. Confirming a customer order decrements stock in the one shared store,
//      so both the shop and the marketing inventory see the same number.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self/customer/catalog.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/customer/product_list_screen.dart';
import 'package:self/marketing/marketing_controllers.dart';
import 'package:self/marketing/marketing_models.dart';

void main() {
  testWidgets('Marketing add reflects live on the customer catalogue',
      (tester) async {
    // The real customer Search/catalogue screen.
    await tester.pumpWidget(const MaterialApp(home: ProductListScreen()));
    await tester.pumpAndSettle();

    // A seeded medicine is already visible to the customer…
    expect(find.text('Paracetamol 650mg'), findsWidgets);
    // …and a medicine that isn't in inventory yet is absent.
    expect(find.text('Test Cardiac Injection'), findsNothing);

    // The Marketing Head adds a new ACTIVE medicine (same call the Add
    // Medicine form makes).
    MarketingProductsController.instance.add(const InventoryProduct(
      id: 'test-sync-injection',
      name: 'Test Cardiac Injection',
      brand: 'DemoPharma',
      category: 'Lifesaving Injections',
      price: 499,
      mrp: 560,
      stock: 25,
      active: true,
    ));
    await tester.pumpAndSettle();

    // It now appears on the customer screen — live, with no reload.
    expect(find.text('Test Cardiac Injection'), findsWidgets);

    // Cleanup so the shared singleton doesn't leak into other tests.
    addTearDown(() {
      MarketingProductsController.instance
          .toggleActive('test-sync-injection'); // hides it again
    });
  });

  test('Confirming an order decrements the shared stock everywhere', () {
    final before = Catalog.byId('p1')!.stockCount;

    // Exactly what checkout does on order confirmation:
    final p1 = Catalog.byId('p1')!;
    Catalog.decrementForOrder([CartItem(product: p1, quantity: 5)]);

    // The shop sees the reduced number…
    expect(Catalog.byId('p1')!.stockCount, before - 5);
    // …and so does the marketing inventory (same record, one store).
    expect(MarketingProductsController.instance.byId('p1')!.stock, before - 5);
  });
}
