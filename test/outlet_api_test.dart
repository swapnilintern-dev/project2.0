// Verifies OutletApi against the EXACT JSON shapes server/controller/
// outletController.js returns — outlet_login and getOutletProducts.
//
// These are the two calls the whole Outlet role stands on: login must yield an
// outlet id (without it nothing can be scoped), and stock must map the
// populated product rows.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:self/outlet/outlet_api.dart';
import 'package:self/outlet/outlet_enums.dart';
import 'package:self/outlet/outlet_models.dart';
import 'package:self/outlet/outlet_session.dart';

void main() {
  setUp(() => OutletSession.instance.clear());

  group('OutletApi.login', () {
    test('parses the outlet, captures token + cookie, populates the session',
        () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/outlet-login'));
        expect(jsonDecode(req.body), {
          'mobileNo': '9876500011',
          'password': 'secret123',
        });
        return http.Response(
          jsonEncode({
            'message': 'Outlet Login success ',
            'success': true,
            'role': 'outlet',
            'token': 'jwt-token-here',
            'outlet': {
              '_id': '665outlet',
              'outletName': 'VS Arogya Ballari',
              'ownerName': 'Ravi Kumar',
              'mobileNo': '9876500011',
              'city': 'Ballari',
              'state': 'Karnataka',
              'pincode': '583101',
              'status': 'Active',
              'role': 'outlet',
            },
          }),
          200,
          headers: {'set-cookie': 'token=jwt-token-here; Path=/; HttpOnly'},
        );
      });

      final (outlet, error) = await OutletApi(client: client)
          .login(mobileNo: '9876500011', password: 'secret123');

      expect(error, isNull);
      expect(outlet!.id, '665outlet');
      expect(outlet.outletName, 'VS Arogya Ballari');
      expect(outlet.isActive, isTrue);

      // Without outletId the stock call cannot be scoped — this is the field
      // the entire role depends on.
      final session = OutletSession.instance;
      expect(session.outletId, '665outlet');
      expect(session.isLive, isTrue);
      expect(session.isSignedIn, isTrue);
      expect(session.token, 'jwt-token-here');
      expect(session.cookie, 'token=jwt-token-here');
      expect(session.outletName, 'VS Arogya Ballari');
    });

    test('maps the server\'s "Data mismatch" to a showable message', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'message': 'Data mismatch', 'success': false}), 400));

      final (outlet, error) = await OutletApi(client: client)
          .login(mobileNo: '9999999999', password: 'wrong');

      expect(outlet, isNull);
      expect(error, 'Incorrect mobile number or password');
      expect(OutletSession.instance.isSignedIn, isFalse);
    });

    test('flags a 200 that carries no outlet instead of signing in', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'message': 'Outlet Login success ', 'success': true}),
          200));

      final (outlet, error) = await OutletApi(client: client)
          .login(mobileNo: '9876500011', password: 'secret123');

      expect(outlet, isNull);
      expect(error, contains('did not return the outlet'));
      expect(OutletSession.instance.isLive, isFalse);
    });

    test('reports an inactive outlet so sign-in can block it', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'success': true,
              'token': 't',
              'outlet': {
                '_id': '665outlet',
                'outletName': 'Closed Shop',
                'ownerName': 'X',
                'status': 'Inactive',
              },
            }),
            200,
          ));

      final (outlet, error) = await OutletApi(client: client)
          .login(mobileNo: '9876500011', password: 'secret123');

      expect(error, isNull);
      expect(outlet!.isActive, isFalse);
    });
  });

  group('OutletApi.fetchProfile', () {
    test('parses the full outlet document the server returns', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/outlet-profile/665outlet'));
        return http.Response(
          jsonEncode({
            'success': true,
            'outlet': {
              '_id': '665outlet',
              'outletName': 'VS Arogya Ballari',
              'ownerName': 'Ravi Kumar',
              'mobileNo': '9876500011',
              'email': 'ravi@vsarogya.in',
              'address': 'Gandhi Nagar',
              'city': 'Ballari',
              'state': 'Karnataka',
              'pincode': '583101',
              'gstNumber': '29ABCDE1234F1Z5',
              'status': 'Active',
            },
          }),
          200,
        );
      });

      final (profile, error) =
          await OutletApi(client: client).fetchProfile('665outlet');

      expect(error, isNull);
      expect(profile!.id, '665outlet');
      expect(profile.email, 'ravi@vsarogya.in');
      expect(profile.gstNumber, '29ABCDE1234F1Z5');
      expect(profile.isActive, isTrue);
      expect(profile.fullAddress, 'Gandhi Nagar, Ballari, Karnataka — 583101');
    });

    test('surfaces an HTTP failure instead of a blank profile', () async {
      final client = MockClient((_) async => http.Response('down', 503));
      final (profile, error) =
          await OutletApi(client: client).fetchProfile('665outlet');
      expect(profile, isNull);
      expect(error, contains('503'));
    });
  });

  group('OutletApi.fetchStock', () {
    test('maps populated product rows and skips deleted products', () async {
      OutletSession.instance.signIn(
        outletId: '665outlet',
        outlet: 'VS Arogya Ballari',
        district: 'Ballari',
      );

      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/outlet-products/665outlet'));
        return http.Response(
          jsonEncode({
            'success': true,
            'count': 3,
            'products': [
              {
                '_id': 'row1',
                'quantity': 40,
                'product': {
                  '_id': 'p1',
                  'title': 'Paracetamol 500mg',
                  'packInfo': '10 tablets',
                  'category': 'medicine',
                  'price': 25,
                },
              },
              // Product deleted from the catalog — must not render a blank row.
              {'_id': 'row2', 'quantity': 5, 'product': null},
              {
                '_id': 'row3',
                'quantity': 0,
                'product': {
                  '_id': 'p3',
                  'title': 'Cough Syrup',
                  'packInfo': '100 ml',
                  'category': 'medicine',
                  'price': 85.5,
                },
              },
            ],
          }),
          200,
        );
      });

      final (items, error) = await OutletApi(client: client)
          .fetchStock('665outlet');

      expect(error, isNull);
      expect(items!.length, 2, reason: 'the null-product row must be skipped');

      final first = items.first;
      expect(first.id, 'p1');
      expect(first.name, 'Paracetamol 500mg');
      expect(first.packSize, '10 tablets');
      expect(first.price, 25);
      expect(first.qtyAvailable, 40);
      expect(first.isOwnOutlet, isTrue);
      expect(first.outletName, 'VS Arogya Ballari');
      expect(first.inStock, isTrue);

      // A zero-qty row still belongs in the list, just not sellable.
      expect(items[1].qtyAvailable, 0);
      expect(items[1].inStock, isFalse);
      expect(items[1].price, 85.5);
    });

    test('surfaces an HTTP failure instead of returning empty stock', () async {
      final client =
          MockClient((_) async => http.Response('gateway blew up', 502));

      final (items, error) =
          await OutletApi(client: client).fetchStock('665outlet');

      expect(items, isNull);
      expect(error, contains('502'));
    });
  });

  // The Stock → Medicine Details screen. Everything it renders comes from this
  // ONE call, so the mapping is pinned against the exact shape
  // getOutletAvailableBatches returns for `?all=1`.
  group('OutletApi.fetchMedicineDetail', () {
    /// A product holding four lots that between them cover every batch state
    /// the screen has to render: healthy, expiring, expired and emptied.
    Map<String, dynamic> detailBody() => {
          'success': true,
          'product': {
            '_id': 'p1',
            'title': 'Paracetamol 650 mg Tablet',
            'description': 'Antipyretic and analgesic.',
            'category': 'medicine',
            'brand': 'Calpol',
            'manufacturer': 'Micro Labs',
            'marketedBy': 'VS Arogya',
            'code': 'PAR650',
            'packInfo': '15 tablets',
            'packOf': 15,
            'hsnCode': '30049099',
            'gstPercent': 12,
            'discountPercent': 5,
            'price': 31,
            'mrp': 38.5,
            'cold_stored': '',
            'prescriptionRequired': false,
            'image': [
              {'url': 'https://cdn/para.png', 'publicId': 'para'}
            ],
            'createdAt': '2026-01-04T10:00:00.000Z',
            'updatedAt': '2026-07-20T08:30:00.000Z',
          },
          'stock': 794,
          'total_stock': 794,
          'batch_count': 4,
          'batches': [
            {
              '_id': 'b-expired',
              'batch_number': 'PAR650A2401',
              'expiry_date': '2026-02-01T00:00:00.000Z',
              'manufacturing_date': '2024-02-01T00:00:00.000Z',
              'available_quantity': 12,
              'purchase_price': 24,
              'selling_price': 31,
              'supplier': 'Kaveri Distributors',
              'isExpiringSoon': true,
              'created_at': '2026-01-10T00:00:00.000Z',
              'updated_at': '2026-03-01T00:00:00.000Z',
            },
            {
              '_id': 'b-empty',
              'batch_number': 'PAR650A2502',
              'expiry_date': '2027-11-01T00:00:00.000Z',
              'manufacturing_date': null,
              'available_quantity': 0,
              'purchase_price': 25,
              'selling_price': 31,
              'supplier': '',
              'isExpiringSoon': false,
              'created_at': '2026-04-10T00:00:00.000Z',
              'updated_at': '2026-07-01T00:00:00.000Z',
            },
            {
              '_id': 'b-soon',
              'batch_number': 'PAR650A2507',
              'expiry_date': '2026-09-15T00:00:00.000Z',
              'manufacturing_date': '2025-09-15T00:00:00.000Z',
              'available_quantity': 282,
              'purchase_price': 26,
              'selling_price': 31,
              'supplier': 'Kaveri Distributors',
              'isExpiringSoon': true,
              'created_at': '2026-05-02T00:00:00.000Z',
              'updated_at': '2026-07-25T00:00:00.000Z',
            },
            {
              '_id': 'b-healthy',
              'batch_number': 'PAR650A2601',
              'expiry_date': '2028-06-30T00:00:00.000Z',
              'manufacturing_date': '2026-06-30T00:00:00.000Z',
              'available_quantity': 500,
              'purchase_price': 27,
              'selling_price': 31,
              'supplier': 'Sri Balaji Agencies',
              'isExpiringSoon': false,
              'created_at': '2026-07-01T00:00:00.000Z',
              'updated_at': '2026-07-26T00:00:00.000Z',
            },
          ],
        };

    test('asks the outlet-scoped endpoint for ALL lots, not just sellable ones',
        () async {
      late Uri called;
      final client = MockClient((req) async {
        called = req.url;
        return http.Response(jsonEncode(detailBody()), 200);
      });

      final (detail, error) =
          await OutletApi(client: client).fetchMedicineDetail('p1');

      expect(error, isNull);
      expect(detail, isNotNull);
      expect(
        called.path,
        endsWith('/vsArogya/outlet/product/p1/available-batches'),
        reason: 'must reuse the existing endpoint, not a new one',
      );
      expect(called.queryParameters['all'], '1',
          reason: 'without ?all=1 the server hides expired and emptied lots');
    });

    test('maps the product, the outlet totals and every batch', () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode(detailBody()), 200));

      final (detail, error) =
          await OutletApi(client: client).fetchMedicineDetail('p1');

      expect(error, isNull);
      final d = detail!;

      expect(d.productId, 'p1');
      expect(d.name, 'Paracetamol 650 mg Tablet');
      expect(d.manufacturer, 'Micro Labs');
      expect(d.marketedBy, 'VS Arogya');
      expect(d.hsnCode, '30049099');
      expect(d.gstPercent, 12);
      expect(d.packOf, 15);
      expect(d.price, 31);
      expect(d.mrp, 38.5);
      expect(d.mrpSaving, closeTo(7.5, 0.001));
      expect(d.imageUrl, 'https://cdn/para.png');
      expect(d.createdAt, isNotNull);
      expect(d.updatedAt, isNotNull);

      // Stock is the SERVER's arithmetic — never recomputed on the client.
      expect(d.totalStock, 794);
      expect(d.stockMirror, 794);
      expect(d.batchCount, 4);

      // Order is preserved exactly as the server sent it (FEFO is its policy).
      expect(d.batches.map((b) => b.batchNumber).toList(), [
        'PAR650A2401',
        'PAR650A2502',
        'PAR650A2507',
        'PAR650A2601',
      ]);

      final soon = d.batches[2];
      expect(soon.available, 282);
      expect(soon.expiry, DateTime.parse('2026-09-15T00:00:00.000Z'));
      expect(soon.manufacturingDate,
          DateTime.parse('2025-09-15T00:00:00.000Z'));
      expect(soon.purchasePrice, 26);
      expect(soon.sellingPrice, 31);
      expect(soon.supplier, 'Kaveri Distributors');
      expect(soon.isExpiringSoon, isTrue);
      expect(soon.purchaseDate, isNotNull);
      expect(soon.updatedAt, isNotNull);

      // A lot with no printed manufacturing date stays null — not "today".
      expect(d.batches[1].manufacturingDate, isNull);
      expect(d.batches[1].available, 0);
      expect(d.batches[1].supplier, isEmpty);
    });

    test('counts only lots that are in stock AND unexpired as sellable',
        () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode(detailBody()), 200));

      final (detail, _) =
          await OutletApi(client: client).fetchMedicineDetail('p1');

      // b-expired is past, b-empty holds nothing → 2 of the 4 can be issued.
      expect(detail!.batches.length, 4);
      expect(detail.sellableBatchCount, 2);
    });

    // A server that hasn't been redeployed yet ignores `?all=1` and answers
    // with the sellable lots and NO product. The screen must still work off
    // live data rather than dead-ending.
    test('falls back to /all-products when the server predates ?all=1',
        () async {
      final paths = <String>[];
      final client = MockClient((req) async {
        paths.add(req.url.path);
        if (req.url.path.endsWith('/available-batches')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'batches': [
                {
                  '_id': 'b-soon',
                  'batch_number': 'PAR650A2507',
                  'expiry_date': '2026-09-15T00:00:00.000Z',
                  'available_quantity': 282,
                  'created_at': '2026-05-02T00:00:00.000Z',
                  'isExpiringSoon': true,
                },
                {
                  '_id': 'b-healthy',
                  'batch_number': 'PAR650A2601',
                  'expiry_date': '2028-06-30T00:00:00.000Z',
                  'available_quantity': 500,
                  'created_at': '2026-07-01T00:00:00.000Z',
                  'isExpiringSoon': false,
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'products': [
              {'_id': 'other', 'title': 'Something else', 'price': 10},
              {
                '_id': 'p1',
                'title': 'Paracetamol 650 mg Tablet',
                'manufacturer': 'Micro Labs',
                'hsnCode': '30049099',
                'gstPercent': 12,
                'price': 31,
                'mrp': 38.5,
                'createdAt': '2026-01-04T10:00:00.000Z',
                'updatedAt': '2026-07-20T08:30:00.000Z',
              },
            ],
          }),
          200,
        );
      });

      final (detail, error) =
          await OutletApi(client: client).fetchMedicineDetail('p1');

      expect(error, isNull);
      final d = detail!;

      // The product came from the deployed catalog endpoint — live, not faked.
      expect(paths.last, endsWith('/vsArogya/all-products'));
      expect(d.name, 'Paracetamol 650 mg Tablet');
      expect(d.manufacturer, 'Micro Labs');
      expect(d.hsnCode, '30049099');

      // Totals are summed from the server's own per-lot quantities.
      expect(d.batches.length, 2);
      expect(d.batchCount, 2);
      expect(d.totalStock, 782);

      // …and the screen is told the expired/emptied lots are missing.
      expect(d.showsAllLots, isFalse);
    });

    test('the full response is never treated as a fallback', () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode(detailBody()), 200));

      final (detail, _) =
          await OutletApi(client: client).fetchMedicineDetail('p1');

      expect(detail!.showsAllLots, isTrue);
    });

    test('reports a deleted medicine instead of an empty batch list', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'success': false, 'message': 'Product not found'}),
            404,
          ));

      final (detail, error) =
          await OutletApi(client: client).fetchMedicineDetail('gone');

      expect(detail, isNull);
      expect(error, 'Product not found');
    });

    test('reports an expired session rather than a blank screen', () async {
      final client = MockClient((_) async => http.Response('Unauthorized', 401));

      final (detail, error) =
          await OutletApi(client: client).fetchMedicineDetail('p1');

      expect(detail, isNull);
      expect(error, contains('session has expired'));
    });

    test('survives a non-JSON gateway error', () async {
      final client =
          MockClient((_) async => http.Response('<html>502</html>', 502));

      final (detail, error) =
          await OutletApi(client: client).fetchMedicineDetail('p1');

      expect(detail, isNull);
      expect(error, contains('502'));
    });
  });

  group('OutletApi.fetchVendors', () {
    test('keeps only approved buyers — drops staff and unapproved', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/all-vendors'));
        return http.Response(
          jsonEncode({
            'success': true,
            'all_vendors': [
              {
                '_id': 'v1',
                'role': 'vendor',
                'approvalStatus': 'Approved',
                'store_name': 'Sri Sai Medicals',
                'contact_person_name': 'Sai',
                'mobile_no': '9876500011',
                'full_address': 'Gandhi Nagar',
                'city': 'Ballari',
                'state': 'Karnataka',
                'pin_code': '583101',
              },
              // staff — must not be orderable for
              {'_id': 'v2', 'role': 'marketing', 'approvalStatus': 'Approved'},
              {'_id': 'v3', 'role': 'delivery', 'approvalStatus': 'Approved'},
              {'_id': 'v4', 'role': 'outlet', 'approvalStatus': 'Approved'},
              // not approved yet
              {'_id': 'v5', 'role': 'vendor', 'approvalStatus': 'Pending'},
            ],
          }),
          200,
        );
      });

      final (vendors, error) = await OutletApi(client: client).fetchVendors();

      expect(error, isNull);
      expect(vendors!.map((v) => v.id), ['v1']);
      final v = vendors.single;
      expect(v.displayName, 'Sri Sai Medicals');
      expect(v.phone, '9876500011');
      expect(v.hasAddress, isTrue);
      expect(v.fullAddress, contains('583101'));
    });
  });

  group('OutletApi.createManualOrder', () {
    CreateOrderRequest requestWith({int qty = 3, String vendorId = 'v1'}) =>
        CreateOrderRequest(
          type: OutletOrderType.counter,
          paymentMethod: OutletPaymentMethod.qr,
          lines: [
            OutletCartLine(
              productId: 'p1',
              name: 'Paracetamol 500mg',
              price: 25,
              qty: qty,
              packSize: '10 tablets',
            ),
          ],
          customer: OutletCustomerInfo(
            name: 'Sri Sai Medicals',
            phone: '9876500011',
            vendorId: vendorId,
          ),
          idempotencyKey: 'outlet-123-abc',
        );

    test('adds ONE unit per call (qty times), then places the order', () async {
      final calls = <String>[];
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.url.path.contains('/manual-order/')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Order placed successfully',
              'Order': {
                '_id': '665order',
                'orderNo': 'ORD-2026123456',
                'totalAmount': 75,
                'orderStatus': 'Pending',
                'createdAt': '2026-07-17T09:12:00.000Z',
              },
            }),
            201,
          );
        }
        return http.Response(jsonEncode({'success': true}), 201);
      });

      final (order, error) =
          await OutletApi(client: client).createManualOrder(requestWith(qty: 3));

      expect(error, isNull);

      // qty 3 => exactly 3 cart calls, then 1 order call.
      expect(
        calls.where((c) => c.contains('/manual-cart/v1/p1')).length,
        3,
        reason: 'the server adds ONE unit per manual-cart call',
      );
      expect(calls.last, contains('/manual-order/v1'));

      expect(order!.id, '665order');
      expect(order.total, 75);
      expect(order.lines.single.name, 'Paracetamol 500mg');
      expect(order.lines.single.qty, 3);
      expect(order.customer.vendorId, 'v1');
      expect(order.createdAt.toUtc().year, 2026);
      expect(order.teamFulfilled, isTrue);
      expect(order.serverStatusLabel, 'Pending');
    });

    test('tags the order with the signed-in outlet so it is traceable',
        () async {
      OutletSession.instance.signIn(outletId: '665outlet', outlet: 'Ballari');

      Map<String, dynamic>? orderBody;
      final client = MockClient((req) async {
        if (req.url.path.contains('/manual-order/')) {
          orderBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'Order': {'_id': 'o1', 'totalAmount': 25},
            }),
            201,
          );
        }
        return http.Response(jsonEncode({'success': true}), 201);
      });

      await OutletApi(client: client).createManualOrder(requestWith(qty: 1));

      // order.user is the VENDOR — without this the order could never be found
      // again from the outlet's side.
      expect(orderBody?['outletId'], '665outlet');
    });

    test('refuses to call the server with no vendor selected', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });

      final (order, error) = await OutletApi(client: client)
          .createManualOrder(requestWith(vendorId: ''));

      expect(order, isNull);
      expect(error, contains('Pick a vendor'));
      expect(called, isFalse);
    });

    test('surfaces "Vendor not found" from the cart step and stops', () async {
      var orderPlaced = false;
      final client = MockClient((req) async {
        if (req.url.path.contains('/manual-order/')) orderPlaced = true;
        return http.Response(
            jsonEncode({'success': false, 'message': 'Vendor not found '}), 404);
      });

      final (order, error) =
          await OutletApi(client: client).createManualOrder(requestWith());

      expect(order, isNull);
      expect(error, 'Vendor not found ');
      expect(orderPlaced, isFalse,
          reason: 'a failed cart step must not go on to place the order');
    });

    test('surfaces "Cart is empty" from the order step', () async {
      final client = MockClient((req) async {
        if (req.url.path.contains('/manual-order/')) {
          return http.Response(
              jsonEncode({'success': false, 'message': 'Cart is empty '}), 404);
        }
        return http.Response(jsonEncode({'success': true}), 201);
      });

      final (order, error) =
          await OutletApi(client: client).createManualOrder(requestWith(qty: 1));

      expect(order, isNull);
      expect(error, 'Cart is empty ');
    });
  });

  group('OutletApi.fetchOrders', () {
    http.Response ordersWith(String orderStatus) => http.Response(
          jsonEncode({
            'success': true,
            'count': 1,
            'orders': [
              {
                '_id': 'o1',
                'orderStatus': orderStatus,
                'totalAmount': 75,
                'createdAt': '2026-07-17T09:12:00.000Z',
                'orderItems': [
                  {
                    'quantity': 3,
                    'orderPrice': 25,
                    'product': {
                      '_id': 'p1',
                      'title': 'Paracetamol 500mg',
                      'packInfo': '10 tablets',
                      'price': 25,
                    },
                  },
                ],
                'user': {
                  '_id': 'v1',
                  'store_name': 'Sri Sai Medicals',
                  'mobile_no': '9876500011',
                },
                'shippingAddress': {
                  'address': 'Gandhi Nagar',
                  'city': 'Ballari',
                  'state': 'Karnataka',
                  'pincode': '583101',
                  'phoneNo': '9876500011',
                },
              },
            ],
          }),
          200,
        );

    test('maps the populated order, vendor and address', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/outlet-orders/665outlet'));
        return ordersWith('Pending');
      });

      final (orders, error) =
          await OutletApi(client: client).fetchOrders('665outlet');

      expect(error, isNull);
      final o = orders!.single;
      expect(o.id, 'o1');
      expect(o.total, 75);
      expect(o.lines.single.name, 'Paracetamol 500mg');
      expect(o.lines.single.qty, 3);
      expect(o.lines.single.price, 25);
      expect(o.itemCount, 3);
      expect(o.customer.name, 'Sri Sai Medicals');
      expect(o.customer.vendorId, 'v1');
      expect(o.customer.address, contains('583101'));
      // Always true for these — the team fulfils them, so the detail screen
      // must not offer "collect payment" / "mark handed over".
      expect(o.teamFulfilled, isTrue);
    });

    test('maps every server status onto the outlet vocabulary', () async {
      final cases = {
        'Pending': OutletOrderStatus.awaitingPayment,
        'Confirm Order': OutletOrderStatus.paid,
        'Shipped': OutletOrderStatus.readyForPickup,
        'Out for Delivery': OutletOrderStatus.outForDelivery,
        'Delivered': OutletOrderStatus.delivered,
        'Cancelled': OutletOrderStatus.cancelled,
      };

      for (final entry in cases.entries) {
        final client = MockClient((_) async => ordersWith(entry.key));
        final (orders, _) =
            await OutletApi(client: client).fetchOrders('665outlet');
        expect(orders!.single.status, entry.value,
            reason: '"${entry.key}" should map to ${entry.value}');
        // The raw server word is preserved for display.
        expect(orders.single.serverStatusLabel, entry.key);
      }
    });

    test('an unknown server status degrades to awaiting payment', () async {
      final client = MockClient((_) async => ordersWith('Something New'));
      final (orders, _) =
          await OutletApi(client: client).fetchOrders('665outlet');
      expect(orders!.single.status, OutletOrderStatus.awaitingPayment);
      expect(orders.single.serverStatusLabel, 'Something New');
    });

    test('surfaces an HTTP failure rather than an empty order list', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final (orders, error) =
          await OutletApi(client: client).fetchOrders('665outlet');
      expect(orders, isNull);
      expect(error, contains('500'));
    });
  });

  // Outlet Billing → vendor registration request (JSON, NO uploads). Pins the
  // wire contract of POST /vsArogya/outlet/register-vendor: snake_case body with
  // the GST + drug-license NUMBERS (no multipart, no store photo), and how the
  // client reads the server's success / duplicate responses.
  group('OutletApi.registerOutletVendor', () {
    Map<String, dynamic> payload() => {
          'vendor_type': 'Shop / Pharmacy',
          'shop_type': 'Retail Pharmacy',
          'store_name': 'Sri Medical',
          'contact_person_name': 'Ravi Kumar',
          'mobile_no': '9876500011',
          'email': 'ravi@example.com',
          'full_address': '12 MG Road',
          'city': 'Ballari',
          'state': 'Karnataka',
          'pin_code': '583101',
          'gst_status': 'yes',
          'gst_no': '29ABCDE1234F1Z5',
          'drug_lic_no': 'KA-B21-123456',
        };

    test('POSTs the JSON body (no multipart, no store photo) and reports success',
        () async {
      OutletSession.instance.signIn(outletId: '665outlet', outlet: 'Ballari');

      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/vsArogya/outlet/register-vendor'));
        expect(req.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        // Certificate NUMBERS are sent; no file/photo keys ever appear.
        expect(body['gst_no'], '29ABCDE1234F1Z5');
        expect(body['drug_lic_no'], 'KA-B21-123456');
        expect(body.containsKey('store_pic'), isFalse);
        expect(body.containsKey('gst_pdf'), isFalse);
        expect(body.containsKey('drug_lic_copy'), isFalse);
        return http.Response(
          jsonEncode({
            'success': true,
            'message':
                'Registration submitted for admin approval. Login details will be emailed once approved.',
            'vendor': {
              '_id': '900vendor',
              'approvalStatus': 'Pending',
              'registrationSource': 'outlet',
            },
          }),
          201,
        );
      });

      final (ok, message) =
          await OutletApi(client: client).registerOutletVendor(payload());
      expect(ok, isTrue);
      expect(message, contains('admin approval'));
    });

    test('surfaces the server\'s duplicate (409) message verbatim', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'success': false,
              'message': 'A vendor with this mobile number already exists.',
            }),
            409,
          ));
      final (ok, message) =
          await OutletApi(client: client).registerOutletVendor(payload());
      expect(ok, isFalse);
      expect(message, contains('already exists'));
    });
  });
}