// Pins the wire contracts of the newly-lived endpoints against the EXACT JSON
// server/controller/rolePaymentController.js and userController.js return:
//
//   • Outlet payment  — /outlet/orders/:id/{razorpay|verify|payment|status}
//   • Delivery doorstep payment — /delivery/{payment-link|payment-status}/:id
//   • Customer address book     — /addresses CRUD
//
// If a server response shape drifts, these fail before the app does.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:self/customer/customer_api.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/delivery/delivery_api.dart';
import 'package:self/outlet/outlet_api.dart';
import 'package:self/outlet/outlet_enums.dart';
import 'package:self/outlet/outlet_session.dart';

void main() {
  setUp(() => OutletSession.instance.clear());

  // ---------------------------------------------------------------------------
  // OUTLET PAYMENT
  // ---------------------------------------------------------------------------

  group('OutletApi payment', () {
    test('createRazorpayOrder parses the checkout-sheet fields', () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/vsArogya/outlet/orders/ord1/razorpay'));
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'payment created',
            'razorpayOrderId': 'order_Nxxxx',
            'amount': 21000,
            'currency': 'INR',
            'orderId': 'ord1',
            'razorpayKeyId': 'rzp_live_xxxx',
          }),
          200,
        );
      });

      final (pay, error) =
          await OutletApi(client: client).createRazorpayOrder('ord1');

      expect(error, isNull);
      expect(pay!.razorpayOrderId, 'order_Nxxxx');
      expect(pay.amount, 21000); // paise
      expect(pay.currency, 'INR');
      expect(pay.keyId, 'rzp_live_xxxx');
    });

    test('verifyPayment sends the razorpay_* field names the server checks',
        () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/vsArogya/outlet/orders/ord1/verify'));
        expect(jsonDecode(req.body), {
          'razorpay_order_id': 'order_Nxxxx',
          'razorpay_payment_id': 'pay_123',
          'razorpay_signature': 'sig-abc',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'verified': true,
            'status': 'PAID',
            'message': 'Payment verified successfully',
          }),
          200,
        );
      });

      final (verified, error) = await OutletApi(client: client).verifyPayment(
        orderId: 'ord1',
        razorpayOrderId: 'order_Nxxxx',
        paymentId: 'pay_123',
        signature: 'sig-abc',
      );

      expect(error, isNull);
      expect(verified, isTrue);
    });

    test('verifyPayment surfaces a failed signature as an error', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'success': false,
              'message': 'Payment verification failed',
            }),
            400,
          ));

      final (verified, error) = await OutletApi(client: client).verifyPayment(
        orderId: 'ord1',
        razorpayOrderId: 'order_Nxxxx',
        paymentId: 'pay_123',
        signature: 'forged',
      );

      expect(verified, isNull);
      expect(error, 'Payment verification failed');
    });

    test('createPaymentSession sends the method and parses the link session',
        () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/vsArogya/outlet/orders/ord1/payment'));
        expect(jsonDecode(req.body), {'method': 'QR'});
        return http.Response(
          jsonEncode({
            'success': true,
            'orderId': 'ord1',
            'amount': 210,
            'status': 'AWAITING_PAYMENT',
            'qrImageData': 'https://rzp.io/i/abc123',
            'paymentLink': 'https://rzp.io/i/abc123',
            'expiresAt': '2026-07-19T10:12:00.000Z',
          }),
          200,
        );
      });

      final (info, error) = await OutletApi(client: client)
          .createPaymentSession('ord1', OutletPaymentMethod.qr);

      expect(error, isNull);
      expect(info!.orderId, 'ord1');
      expect(info.amount, 210);
      expect(info.status, OutletOrderStatus.awaitingPayment);
      expect(info.qrImageData, 'https://rzp.io/i/abc123');
      expect(info.paymentLink, 'https://rzp.io/i/abc123');
      expect(info.expiresAt, isNotNull);
    });

    test('fetchOrderStatus maps the wire status', () async {
      final client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, endsWith('/vsArogya/outlet/orders/ord1/status'));
        return http.Response(
          jsonEncode({'success': true, 'status': 'PAID', 'paid': true}),
          200,
        );
      });

      final (status, error) =
          await OutletApi(client: client).fetchOrderStatus('ord1');

      expect(error, isNull);
      expect(status, OutletOrderStatus.paid);
    });
  });

  // ---------------------------------------------------------------------------
  // DELIVERY DOORSTEP PAYMENT
  // ---------------------------------------------------------------------------

  group('DeliveryApi doorstep payment', () {
    test('createDoorstepPaymentLink sends the agent token and parses the link',
        () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/vsArogya/delivery/payment-link/ord9'));
        expect(req.headers['Authorization'], 'Bearer agent-jwt');
        return http.Response(
          jsonEncode({
            'success': true,
            'paid': false,
            'paymentLink': 'https://rzp.io/i/door123',
            'amount': 480,
            'expiresAt': '2026-07-19T10:42:00.000Z',
          }),
          200,
        );
      });

      final (link, alreadyPaid, error) = await DeliveryApi(client: client)
          .createDoorstepPaymentLink('ord9', token: 'agent-jwt');

      expect(error, isNull);
      expect(alreadyPaid, isFalse);
      expect(link, 'https://rzp.io/i/door123');
    });

    test('createDoorstepPaymentLink reports an already-paid order', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'success': true,
              'paid': true,
              'paymentLink': null,
              'amount': 480,
              'expiresAt': null,
            }),
            200,
          ));

      final (link, alreadyPaid, error) = await DeliveryApi(client: client)
          .createDoorstepPaymentLink('ord9', token: 'agent-jwt');

      expect(error, isNull);
      expect(alreadyPaid, isTrue);
      expect(link, isNull);
    });

    test('doorstepPaymentPaid returns the server truth, null on outage',
        () async {
      final paidClient = MockClient((req) async {
        expect(req.url.path,
            endsWith('/vsArogya/delivery/payment-status/ord9'));
        return http.Response(
            jsonEncode({'success': true, 'paid': true}), 200);
      });
      expect(
        await DeliveryApi(client: paidClient)
            .doorstepPaymentPaid('ord9', token: 'agent-jwt'),
        isTrue,
      );

      final unpaidClient = MockClient((_) async =>
          http.Response(jsonEncode({'success': true, 'paid': false}), 200));
      expect(
        await DeliveryApi(client: unpaidClient)
            .doorstepPaymentPaid('ord9', token: 'agent-jwt'),
        isFalse,
      );

      // An outage must NOT read as "unpaid" — the caller keeps polling.
      final downClient =
          MockClient((_) async => http.Response('oops', 500));
      expect(
        await DeliveryApi(client: downClient)
            .doorstepPaymentPaid('ord9', token: 'agent-jwt'),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CUSTOMER ADDRESS BOOK
  // ---------------------------------------------------------------------------

  group('CustomerApi address book', () {
    final serverAddress = {
      '_id': '665addr1',
      'label': 'Home',
      'fullName': 'Apollo Pharmacy',
      'phone': '9876543210',
      'line1': 'Shop 14, Link Road',
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'pincode': '400053',
      'isDefault': true,
    };

    test('getAddresses maps the Mongo subdocuments', () async {
      final client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, endsWith('/vsArogya/addresses'));
        return http.Response(
          jsonEncode({
            'success': true,
            'addresses': [serverAddress]
          }),
          200,
        );
      });

      final list = await CustomerApi(client: client).getAddresses();

      expect(list, hasLength(1));
      expect(list!.first.id, '665addr1');
      expect(list.first.line1, 'Shop 14, Link Road');
      expect(list.first.isDefault, isTrue);
    });

    test('addAddress posts the fields and returns the full updated list',
        () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/vsArogya/addresses'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['line1'], '12 MG Road');
        expect(body['pincode'], '411001');
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Address saved',
            'address': serverAddress,
            'addresses': [serverAddress],
          }),
          201,
        );
      });

      final list = await CustomerApi(client: client).addAddress(const Address(
        id: '',
        label: 'Work',
        fullName: 'Sri Sai Medicals',
        phone: '9876500011',
        line1: '12 MG Road',
        city: 'Pune',
        state: 'Maharashtra',
        pincode: '411001',
      ));

      expect(list, hasLength(1));
      expect(list!.first.id, '665addr1');
    });

    test('setDefaultAddress PUTs isDefault to the subdocument route', () async {
      final client = MockClient((req) async {
        expect(req.method, 'PUT');
        expect(req.url.path, endsWith('/vsArogya/addresses/665addr1'));
        expect(jsonDecode(req.body), {'isDefault': true});
        return http.Response(
          jsonEncode({
            'success': true,
            'addresses': [serverAddress]
          }),
          200,
        );
      });

      final list =
          await CustomerApi(client: client).setDefaultAddress('665addr1');
      expect(list!.first.isDefault, isTrue);
    });

    test('deleteAddress removes and returns the remaining list', () async {
      final client = MockClient((req) async {
        expect(req.method, 'DELETE');
        expect(req.url.path, endsWith('/vsArogya/addresses/665addr1'));
        return http.Response(
          jsonEncode({'success': true, 'addresses': []}),
          200,
        );
      });

      final list = await CustomerApi(client: client).deleteAddress('665addr1');
      expect(list, isEmpty);
    });

    test('a failed call returns null so the controller keeps its list',
        () async {
      final client = MockClient((_) async => http.Response('oops', 500));
      expect(await CustomerApi(client: client).getAddresses(), isNull);
    });
  });
}
