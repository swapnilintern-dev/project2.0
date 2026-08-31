// Pins the Outlet manual-order BATCH contract end-to-end.
//
// Two things must hold, or an outlet sale can hand over stock from a lot nobody
// chose:
//   1. OutletApi.createManualOrder sends each line's pinned lot as the
//      `allocations` the backend reads (manualOrderController.manualCart →
//      normalizeAllocations → allocateOutletFEFO), with the line's FINAL
//      quantity, plus `outletId` on the placement call so the deduction comes
//      out of THIS outlet's batches.
//   2. OutletCart never lets a line exceed the pinned lot's available units,
//      and re-clamps when the line is re-pinned to a smaller lot.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:self/outlet/outlet_api.dart';
import 'package:self/outlet/outlet_cart.dart';
import 'package:self/outlet/outlet_enums.dart';
import 'package:self/outlet/outlet_models.dart';
import 'package:self/outlet/outlet_session.dart';

const _item = OutletStockItem(
  id: 'p1',
  name: 'Paracetamol 500mg',
  packSize: '10 tablets',
  category: 'medicine',
  price: 25,
  qtyAvailable: 40,
  isOwnOutlet: true,
  batch: 'CATALOG-FRONT',
  batchCount: 3,
);

OutletBatch _batch({
  required String id,
  required String number,
  required int available,
}) =>
    OutletBatch(
      id: id,
      batchNumber: number,
      available: available,
      expiry: DateTime(2030, 6, 30),
    );

void main() {
  setUp(() {
    OutletSession.instance.clear();
    OutletCart.instance.clear();
  });

  group('OutletApi.createManualOrder — batch pin', () {
    test('sends the chosen lot as allocations, then tags the order with the outlet',
        () async {
      OutletSession.instance.signIn(
        outletId: '665outlet',
        outlet: 'VS Arogya Ballari',
        district: 'Ballari',
      );

      final cartBodies = <Map<String, dynamic>>[];
      Map<String, dynamic>? orderBody;

      final client = MockClient((req) async {
        if (req.url.path.contains('/manual-cart/')) {
          // One call per unit — the server adds a single unit each time.
          expect(req.url.path, endsWith('/manual-cart/ven1/p1'));
          cartBodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({'success': true, 'message': 'Product added'}),
            201,
          );
        }
        expect(req.url.path, endsWith('/manual-order/ven1'));
        orderBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Order placed successfully',
            'Order': {
              '_id': 'ord1',
              'orderStatus': 'Pending',
              'totalAmount': 75,
              'createdAt': '2026-07-30T09:00:00.000Z',
            },
          }),
          201,
        );
      });

      final line = OutletCartLine.fromStock(
        _item,
        qty: 3,
        batch: _batch(id: 'b1', number: 'BN-001', available: 12),
      );

      final (order, error) = await OutletApi(client: client).createManualOrder(
        CreateOrderRequest(
          type: OutletOrderType.counter,
          paymentMethod: OutletPaymentMethod.qr,
          lines: [line],
          customer: const OutletCustomerInfo(
            name: 'Sri Sai Medicals',
            phone: '9876500011',
            vendorId: 'ven1',
          ),
          idempotencyKey: 'outlet-test-key',
        ),
      );

      expect(error, isNull);
      expect(order!.id, 'ord1');

      // Three units → three cart calls, each carrying the SAME pin describing
      // the whole line (the server replaces allocations on every call, so the
      // quantity sent is the line total, not one unit).
      expect(cartBodies.length, 3);
      for (final body in cartBodies) {
        expect(body['allocations'], [
          {'batch': 'b1', 'batch_number': 'BN-001', 'quantity': 3},
        ]);
      }

      // `outletId` is what makes the server deduct the OUTLET's batches.
      expect(orderBody, {'outletId': '665outlet'});
    });

    test('omits allocations when no lot is pinned, leaving pure FEFO', () async {
      OutletSession.instance.signIn(outletId: '665outlet');

      final bodies = <String>[];
      final client = MockClient((req) async {
        if (req.url.path.contains('/manual-cart/')) {
          bodies.add(req.body);
          return http.Response(jsonEncode({'success': true}), 201);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'Order': {'_id': 'ord2', 'orderStatus': 'Pending', 'totalAmount': 25},
          }),
          201,
        );
      });

      final (order, error) = await OutletApi(client: client).createManualOrder(
        CreateOrderRequest(
          type: OutletOrderType.counter,
          paymentMethod: OutletPaymentMethod.qr,
          // No batch → the pre-existing behaviour must be untouched.
          lines: [OutletCartLine.fromStock(_item)],
          customer: const OutletCustomerInfo(
            name: 'Sri Sai Medicals',
            phone: '9876500011',
            vendorId: 'ven1',
          ),
          idempotencyKey: 'outlet-test-key-2',
        ),
      );

      expect(error, isNull);
      expect(order!.id, 'ord2');
      expect(bodies, ['']);
    });
  });

  group('OutletCart — batch pin + quantity cap', () {
    test('pins the chosen lot on the line', () {
      final cart = OutletCart.instance;
      cart.add(_item, batch: _batch(id: 'b1', number: 'BN-001', available: 12));

      final line = cart.lineOf('p1')!;
      expect(line.batchId, 'b1');
      expect(line.batch, 'BN-001');
      expect(line.batchAvailable, 12);
      expect(line.hasBatch, isTrue);
      expect(cart.allLinesHaveBatch, isTrue);
      expect(cart.linesWithoutBatch, isEmpty);
      // The catalog's front lot must NOT leak in as the pinned batch.
      expect(line.batch, isNot('CATALOG-FRONT'));
    });

    test('clamps a typed quantity to the lot, never above it', () {
      final cart = OutletCart.instance;
      cart.add(_item, batch: _batch(id: 'b1', number: 'BN-001', available: 4));

      cart.setQty('p1', 99);
      expect(cart.quantityOf('p1'), 4, reason: 'capped at the lot, not stock');

      cart.setQty('p1', 3);
      expect(cart.quantityOf('p1'), 3);

      // Increment stops at the ceiling rather than overshooting it.
      cart.increment('p1');
      cart.increment('p1');
      expect(cart.quantityOf('p1'), 4);

      // Negative / zero can never survive as a quantity: zero removes the line.
      cart.setQty('p1', -5);
      expect(cart.quantityOf('p1'), 0);
      expect(cart.isEmpty, isTrue);
    });

    test('re-pinning to a smaller lot re-clamps the quantity', () {
      final cart = OutletCart.instance;
      cart.add(_item, batch: _batch(id: 'b1', number: 'BN-001', available: 10));
      cart.setQty('p1', 9);
      expect(cart.quantityOf('p1'), 9);

      cart.setBatch('p1', _batch(id: 'b2', number: 'BN-002', available: 2));

      final line = cart.lineOf('p1')!;
      expect(line.batchId, 'b2');
      expect(line.batchAvailable, 2);
      expect(line.qty, 2, reason: 'a 9-unit line cannot come from a 2-unit lot');
      expect(line.allocation.quantity, 2);
      expect(line.allocation.batchId, 'b2');
    });

    test('a repeat add bumps the one line instead of duplicating it', () {
      final cart = OutletCart.instance;
      final b = _batch(id: 'b1', number: 'BN-001', available: 10);
      cart.add(_item, batch: b);
      cart.add(_item, batch: b);

      expect(cart.distinctCount, 1);
      expect(cart.quantityOf('p1'), 2);
      expect(cart.total, 50);
    });
  });
}
