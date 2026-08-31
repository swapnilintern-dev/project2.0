// Cart stock cap — a vendor must never be able to put more units in the cart
// than the medicine actually has. The bug this pins: stock 10, cart accepted 13.
//
// These drive CartController directly (no widgets), because the cap has to hold
// for EVERY entry point — product card, details screen, cart stepper — and the
// controller is the one place they all funnel through.

import 'package:flutter_test/flutter_test.dart';

import 'package:self/customer/catalog.dart';
import 'package:self/customer/customer_controllers.dart';
import 'package:self/customer/customer_models.dart';

Product med(String id, {required int stock, bool inStock = true}) => Product(
      id: id,
      title: 'Paracetamol 650 mg Tablet',
      brand: 'Dolo 650',
      description: '',
      price: 31.05,
      category: 'Medicine',
      inStock: inStock,
      stockCount: stock,
    );

/// A product whose payload carried no stock figure at all (older backend
/// response): stockCount 0 but still in stock — must read as UNKNOWN, not 0.
Product unknownStock(String id) => med(id, stock: 0);

void main() {
  final cart = CartController.instance;

  setUp(() {
    cart.clear();
    Catalog.setProducts(const []);
  });

  group('the reported bug', () {
    test('stock 10 — adding 13 puts only 10 in the cart', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);

      final added = cart.add(p, quantity: 13);

      expect(added, 10, reason: 'should report what actually went in');
      expect(cart.quantityOf('p1'), 10);
    });

    test('tapping + past the stock does nothing', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 10);

      for (var i = 0; i < 5; i++) {
        cart.increment('p1');
      }

      expect(cart.quantityOf('p1'), 10);
    });

    test('repeated adds cannot creep past the stock', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);

      var total = 0;
      for (var i = 0; i < 20; i++) {
        total += cart.add(p);
      }

      expect(total, 10, reason: 'only 10 units were ever granted');
      expect(cart.quantityOf('p1'), 10);
    });
  });

  group('the cap', () {
    test('a partial add reports the shortfall', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 8);

      expect(cart.add(p, quantity: 5), 2, reason: '8 in, only 2 of 5 fit');
      expect(cart.quantityOf('p1'), 10);
    });

    test('adding to a full line grants nothing', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 10);

      expect(cart.add(p, quantity: 3), 0);
      expect(cart.quantityOf('p1'), 10);
    });

    test('setQuantity is capped and reports the applied figure', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);
      cart.add(p);

      expect(cart.setQuantity('p1', 50), 10);
      expect(cart.quantityOf('p1'), 10);
    });

    test('the cap follows LIVE stock, not the copy the screen holds', () {
      final stale = med('p1', stock: 100);
      Catalog.setProducts([med('p1', stock: 4)]); // restocked down since load

      expect(cart.add(stale, quantity: 100), 4);
      expect(cart.quantityOf('p1'), 4);
    });

    test('an out-of-stock medicine cannot be added at all', () {
      final p = med('p1', stock: 0, inStock: false);
      Catalog.setProducts([p]);

      expect(cart.add(p, quantity: 3), 0);
      expect(cart.quantityOf('p1'), 0);
    });

    test('unknown stock is not treated as zero', () {
      // The regression this guards: reading "no stock field" as 0 available
      // would refuse to sell perfectly stocked medicines.
      final p = unknownStock('p1');
      Catalog.setProducts([p]);

      expect(cart.add(p, quantity: 7), 7);
      expect(cart.quantityOf('p1'), 7);
    });

    test('each medicine is capped independently', () {
      final a = med('a', stock: 10);
      final b = med('b', stock: 2);
      Catalog.setProducts([a, b]);

      expect(cart.add(a, quantity: 99), 10);
      expect(cart.add(b, quantity: 99), 2);
    });
  });

  group('lowering a line is always allowed', () {
    test('a line already over stock can still be reduced', () {
      // Stock fell to 3 after 13 were added — the vendor MUST be able to fix it.
      final p = med('p1', stock: 13);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 13);
      Catalog.setProducts([med('p1', stock: 3)]);

      expect(cart.setQuantity('p1', 3), 3);
      expect(cart.quantityOf('p1'), 3);
    });

    test('decrement works from above the cap', () {
      final p = med('p1', stock: 13);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 13);
      Catalog.setProducts([med('p1', stock: 5)]);

      cart.decrement('p1');
      expect(cart.quantityOf('p1'), 12);
    });

    test('setting 0 removes the line', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 5);

      cart.setQuantity('p1', 0);
      expect(cart.quantityOf('p1'), 0);
    });
  });

  group('checkout guard', () {
    test('a cart within stock is clear to order', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 10);

      expect(cart.overStockedLines, isEmpty);
    });

    test('stock falling under an existing line is caught', () {
      final p = med('p1', stock: 13);
      Catalog.setProducts([p]);
      cart.add(p, quantity: 13);
      Catalog.setProducts([med('p1', stock: 10)]);

      expect(cart.overStockedLines.single.product.id, 'p1');
    });

    test('unknown stock never blocks checkout', () {
      final p = unknownStock('p1');
      Catalog.setProducts([p]);
      cart.add(p, quantity: 50);

      expect(cart.overStockedLines, isEmpty);
    });
  });

  group('a saved cart repairs itself on load', () {
    // hydrateFromServer/_reconcile pull the vendor's saved cart back. It may
    // predate the cap, or its medicine may have sold out while it sat idle.
    test('an over-stock line is trimmed to the stock', () {
      final p = med('p1', stock: 10);
      Catalog.setProducts([p]);

      final repaired = cart.clampForTest([CartItem(product: p, quantity: 13)]);

      expect(repaired.single.quantity, 10);
    });

    test('a sold-out line is dropped, not left at 0', () {
      final p = med('p1', stock: 0, inStock: false);
      Catalog.setProducts([p]);

      expect(cart.clampForTest([CartItem(product: p, quantity: 5)]), isEmpty);
    });

    test('lines that fit are passed through untouched', () {
      // Guards the dangling-else trap: a normal line must NOT be dropped.
      final a = med('a', stock: 100);
      final b = med('b', stock: 50);
      Catalog.setProducts([a, b]);

      final out = cart.clampForTest([
        CartItem(product: a, quantity: 3),
        CartItem(product: b, quantity: 50),
      ]);

      expect(out.length, 2, reason: 'both lines survive');
      expect(out[0].quantity, 3);
      expect(out[1].quantity, 50);
    });

    test('unknown-stock lines are passed through untouched', () {
      final p = unknownStock('p1');
      Catalog.setProducts([p]);

      final out = cart.clampForTest([CartItem(product: p, quantity: 99)]);
      expect(out.single.quantity, 99);
    });

    test('a mixed cart keeps the good lines and fixes only the bad', () {
      final ok = med('ok', stock: 100);
      final over = med('over', stock: 2);
      final gone = med('gone', stock: 0, inStock: false);
      Catalog.setProducts([ok, over, gone]);

      final out = cart.clampForTest([
        CartItem(product: ok, quantity: 4),
        CartItem(product: over, quantity: 9),
        CartItem(product: gone, quantity: 1),
      ]);

      expect(out.map((i) => i.product.id), ['ok', 'over']);
      expect(out.map((i) => i.quantity), [4, 2]);
    });
  });

  group('low-stock flag (vendor-facing, below 30)', () {
    test('below the threshold is low', () {
      expect(med('p', stock: 10).isLowStock, isTrue);
      expect(med('p', stock: 29).isLowStock, isTrue);
    });

    test('at or above the threshold is not low', () {
      expect(med('p', stock: 30).isLowStock, isFalse);
      expect(med('p', stock: 500).isLowStock, isFalse);
    });

    test('out of stock is not "low" — it has its own treatment', () {
      expect(med('p', stock: 0, inStock: false).isLowStock, isFalse);
    });

    test('unknown stock is not reported as low', () {
      expect(unknownStock('p').isLowStock, isFalse);
    });

    test('threshold is 30', () {
      expect(kLowStockThreshold, 30);
    });
  });
}
