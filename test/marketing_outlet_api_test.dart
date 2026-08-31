// Verifies the marketing-side OutletApi against the EXACT JSON shapes
// server/controller/outletController.js returns — getOutlets, addOutletStock
// and outletRegister.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:self/marketing/marketing_api.dart';

void main() {
  group('OutletApi.getOutlets', () {
    test('maps the Outlet document and passes the pincode filter', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/outlets'));
        expect(req.url.queryParameters['pincode'], '583101');
        return http.Response(
          jsonEncode({
            'success': true,
            'count': 1,
            'outlets': [
              {
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
            ],
          }),
          200,
        );
      });

      final outlets =
          await OutletApi(client: client).getOutlets(pincode: '583101');

      expect(outlets, isNotNull);
      expect(outlets!.length, 1);
      expect(outlets.first.id, '665outlet');
      expect(outlets.first.name, 'VS Arogya Ballari');
      expect(outlets.first.pin, '583101');
      expect(outlets.first.isActive, isTrue);
      expect(outlets.first.dropdownLabel, contains('583101'));
    });

    test('an empty pincode returns an empty list, not an error', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'success': true, 'count': 0, 'outlets': []}), 200));

      final outlets = await OutletApi(client: client).getOutlets(pincode: '999999');

      expect(outlets, isNotNull);
      expect(outlets, isEmpty);
    });

    test('returns null on failure so the caller can retry', () async {
      final client = MockClient((_) async => http.Response('boom', 500));
      expect(await OutletApi(client: client).getOutlets(), isNull);
    });

    test('flags an inactive outlet so it can be filtered out', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'success': true,
              'outlets': [
                {
                  '_id': 'o2',
                  'outletName': 'Closed Shop',
                  'pincode': '583101',
                  'status': 'Inactive',
                },
              ],
            }),
            200,
          ));

      final outlets = await OutletApi(client: client).getOutlets();
      expect(outlets!.single.isActive, isFalse);
    });
  });

  group('OutletApi.assignStock', () {
    test('posts outletId/productId/quantity and succeeds on 201', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/outlet-stock'));
        expect(jsonDecode(req.body), {
          'outletId': '665outlet',
          'productId': '665product',
          'quantity': 50,
        });
        return http.Response(
          jsonEncode({'success': true, 'message': 'Stock added successfully'}),
          201,
        );
      });

      final error = await OutletApi(client: client).assignStock(
        outletId: '665outlet',
        productId: '665product',
        quantity: 50,
      );

      expect(error, isNull);
    });

    test('surfaces "Insufficient stock available" verbatim', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'success': false,
              'message': 'Insufficient stock available',
            }),
            400,
          ));

      final error = await OutletApi(client: client).assignStock(
        outletId: '665outlet',
        productId: '665product',
        quantity: 9999,
      );

      expect(error, 'Insufficient stock available');
    });

    test('surfaces "Product not found"', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Product not found'}), 404));

      final error = await OutletApi(client: client).assignStock(
        outletId: '665outlet',
        productId: 'bogus',
        quantity: 5,
      );

      expect(error, 'Product not found');
    });
  });

  group('OutletApi.registerOutlet', () {
    test('sends every field the server requires, incl. gstNumber', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/outlet-register'));
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'Outlet registered successfully '}),
          201,
        );
      });

      final error = await OutletApi(client: client).registerOutlet(
        outletName: 'VS Arogya Ballari',
        ownerName: 'Ravi Kumar',
        mobileNo: '9876500011',
        email: 'a@b.com',
        address: 'Main Road',
        city: 'Ballari',
        state: 'Karnataka',
        pincode: '583101',
        gstNumber: '29ABCDE1234F1Z5',
        password: 'secret123',
      );

      expect(error, isNull);
      // The controller rejects the whole call if ANY of these is falsy.
      for (final key in [
        'outletName', 'ownerName', 'mobileNo', 'email', 'address',
        'city', 'state', 'pincode', 'gstNumber', 'password',
      ]) {
        expect(sent[key], isNotNull, reason: '$key must be sent');
        expect('${sent[key]}', isNotEmpty, reason: '$key must not be blank');
      }
    });

    test('surfaces the server\'s "Missing fields" message', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Missing fields '}), 400));

      final error = await OutletApi(client: client).registerOutlet(
        outletName: 'x', ownerName: 'x', mobileNo: '9876500011',
        email: 'a@b.com', address: 'x', city: 'x', state: 'x',
        pincode: '583101', gstNumber: '', password: 'secret123',
      );

      expect(error, 'Missing fields ');
    });
  });
}