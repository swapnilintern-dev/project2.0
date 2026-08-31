// Verifies AgentApi against the JSON shapes server/controller/agentController.js
// returns — getPincodeOrders and getAgentProfile.
//
// The agent role is read-only: it must render the SERVER's order vocabulary
// (Pending / Confirm Order / Shipped / Out for Delivery) faithfully, and show
// the agent's own profile.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:self/agent/agent_api.dart';
import 'package:self/agent/agent_mock.dart';

void main() {
  group('AgentApi.fetchOrders', () {
    http.Response ordersWith(String orderStatus) => http.Response(
          jsonEncode({
            'success': true,
            'orders': [
              {
                '_id': '665order',
                'orderNo': 'ORD-2026123456',
                'orderStatus': orderStatus,
                'createdAt': '2026-07-17T09:12:00.000Z',
                'orderItems': [
                  {
                    'quantity': 3,
                    'orderPrice': 25,
                    'product': {'title': 'Paracetamol 500mg', 'packInfo': '10 tablets'},
                  },
                ],
                'user': {'store_name': 'Sri Sai Medicals'},
                'shippingAddress': {
                  'address': 'Gandhi Nagar',
                  'city': 'Ballari',
                  'state': 'Karnataka',
                  'pincode': '583101',
                },
              },
            ],
          }),
          200,
        );

    test('maps each in-flight server status one-to-one', () async {
      final cases = {
        'Pending': AgentOrderStatus.pending,
        'Confirm Order': AgentOrderStatus.confirmed,
        'Shipped': AgentOrderStatus.shipped,
        'Out for Delivery': AgentOrderStatus.outForDelivery,
        'Delivered': AgentOrderStatus.delivered,
      };

      for (final entry in cases.entries) {
        final client = MockClient((_) async => ordersWith(entry.key));
        final (orders, error) =
            await AgentApi(client: client).fetchOrders('agent1');
        expect(error, isNull);
        expect(orders!.single.status, entry.value,
            reason: '"${entry.key}" should map to ${entry.value}');
      }
    });

    test('maps the populated order line, customer and address', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/pin-orders/agent1'));
        return ordersWith('Confirm Order');
      });

      final (orders, error) =
          await AgentApi(client: client).fetchOrders('agent1');

      expect(error, isNull);
      final o = orders!.single;
      expect(o.id, 'ORD-2026123456');
      expect(o.customerName, 'Sri Sai Medicals');
      expect(o.deliveryPincode, '583101');
      expect(o.lines.single.name, 'Paracetamol 500mg');
      expect(o.lines.single.qty, 3);
    });
  });

  group('AgentApi.fetchProfile', () {
    test('maps the agent Vendor document onto AgentProfile', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/vsArogya/agent-profile/agent1'));
        return http.Response(
          jsonEncode({
            'success': true,
            'agent': {
              '_id': 'agent1',
              'role': 'agent',
              'contact_person_name': 'Anil Verma',
              'mobile_no': '9000000001',
              'email': 'anil@vsarogya.in',
              'full_address': 'Model Colony',
              'city': 'Pune',
              'state': 'Maharashtra',
              'pin_code': '411001',
              'approvalStatus': 'Approved',
            },
          }),
          200,
        );
      });

      final (profile, error) =
          await AgentApi(client: client).fetchProfile('agent1');

      expect(error, isNull);
      expect(profile!.id, 'agent1');
      expect(profile.name, 'Anil Verma');
      expect(profile.mobileNo, '9000000001');
      expect(profile.pincode, '411001');
      expect(profile.isApproved, isTrue);
      expect(profile.fullAddress, 'Model Colony, Pune, Maharashtra — 411001');
    });

    test('surfaces an HTTP failure instead of a blank profile', () async {
      final client = MockClient((_) async => http.Response('down', 500));
      final (profile, error) =
          await AgentApi(client: client).fetchProfile('agent1');
      expect(profile, isNull);
      expect(error, contains('500'));
    });
  });
}
