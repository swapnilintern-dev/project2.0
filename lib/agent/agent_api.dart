// =============================================================================
// VS Arogya — Area Agent · Backend API
//
// The agent's whole job is read-only: see every order being delivered to their
// assigned pincode. The backend scopes that on the agent's own id (a Vendor with
// role "agent" and a pin_code):
//
//   POST /vsArogya/pin-orders/:agentId   → orders in the agent's pincode
//
// Returns `(orders, error)` — the orders on success, else a user-facing message.
// The dashboard only calls this when the session is LIVE (a real backend login);
// the demo login has no agent id and stays on mock data.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import 'agent_mock.dart';

class AgentApi {
  AgentApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// A cold-started free-tier server can take a while on the first call.
  static const Duration _timeout = Duration(seconds: 45);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Orders delivering to [agentId]'s pincode, newest first.
  Future<(List<AgentOrder>?, String?)> fetchOrders(
    String agentId, {
    String? token,
  }) async {
    final url = '$baseUrl/vsArogya/pin-orders/$agentId';
    try {
      debugPrint('[Agent] POST $url');
      final res = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (null, 'Server returned HTTP ${res.statusCode} — please try again.');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        return (null, (body['message'] ?? 'Could not load orders').toString());
      }

      final rows = (body['orders'] as List?) ?? const [];
      final orders =
          rows.whereType<Map<String, dynamic>>().map(_orderFromJson).toList();
      return (orders, null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[Agent] fetchOrders failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// The signed-in agent's own profile — GET /vsArogya/agent-profile/:id.
  /// An agent is a Vendor with role "agent"; the server returns `{ success,
  /// agent }` with the Vendor document (minus password), so the Profile screen
  /// always reflects what marketing registered.
  ///
  /// Returns `(profile, error)`.
  Future<(AgentProfile?, String?)> fetchProfile(
    String agentId, {
    String? token,
  }) async {
    final url = '$baseUrl/vsArogya/agent-profile/$agentId';
    try {
      debugPrint('[Agent] GET $url');
      final res = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (null, 'Server returned HTTP ${res.statusCode} — please try again.');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        return (null, (body['message'] ?? 'Could not load profile').toString());
      }

      final agentJson = body['agent'];
      if (agentJson is! Map<String, dynamic>) {
        return (null, 'The server did not return the agent profile.');
      }

      return (AgentProfile.fromJson(agentJson), null);
    } on TimeoutException {
      return (null, 'Server is taking too long to respond — please try again.');
    } catch (e) {
      debugPrint('[Agent] fetchProfile failed: $e');
      return (null, 'Could not reach the server. Check your connection.');
    }
  }

  /// Maps one backend order (product + user populated) onto [AgentOrder].
  static AgentOrder _orderFromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    final addr =
        j['shippingAddress'] is Map ? j['shippingAddress'] as Map : const {};

    final lines = <AgentOrderLine>[];
    for (final it in ((j['orderItems'] as List?) ?? const []).whereType<Map>()) {
      final p = it['product'] is Map ? it['product'] as Map : const {};
      lines.add(AgentOrderLine(
        name: (p['title'] ?? 'Item').toString(),
        packSize: (p['packInfo'] ?? '').toString(),
        qty: _int(it['quantity'], 1),
        price: _num(it['orderPrice'] ?? p['price']),
      ));
    }

    final address = [addr['address'], addr['city'], addr['state']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(', ');

    final orderNo = (j['orderNo'] ?? '').toString();
    final id = j['_id']?.toString() ?? '';

    return AgentOrder(
      id: orderNo.isNotEmpty ? orderNo : (id.length > 6 ? id.substring(id.length - 6) : id),
      customerName:
          (user['store_name'] ?? user['contact_person_name'] ?? 'Customer')
              .toString(),
      deliveryAddress: address,
      deliveryPincode: (addr['pincode'] ?? '').toString(),
      status: _statusFromServer((j['orderStatus'] ?? 'Pending').toString()),
      placedAgo: _ago(DateTime.tryParse((j['createdAt'] ?? '').toString())),
      lines: lines,
    );
  }

  /// Maps the server's order vocabulary onto the agent states one-to-one.
  /// getPincodeOrders only sends the in-flight statuses (Pending, Confirm Order,
  /// Shipped, Out for Delivery) and drops an order once it's Delivered, so the
  /// agent naturally stops seeing it — the delivered branch is here only for
  /// completeness.
  static AgentOrderStatus _statusFromServer(String s) => switch (s) {
        'Confirm Order' => AgentOrderStatus.confirmed,
        'Shipped' => AgentOrderStatus.shipped,
        'Out for Delivery' => AgentOrderStatus.outForDelivery,
        'Delivered' => AgentOrderStatus.delivered,
        _ => AgentOrderStatus.pending,
      };

  /// A short "x min ago" label from a timestamp (the backend sends ISO dates;
  /// the app formats the relative time itself).
  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _int(Object? v, [int d = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? d;
    return d;
  }
}

/// The Area Agent's own account, from GET /vsArogya/agent-profile/:id. An agent
/// is a Vendor with role "agent", so this mirrors that document (minus the
/// password). Every field is optional — the agent record is created by
/// marketing and may not carry a full address.
class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.name,
    this.mobileNo = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.approvalStatus = '',
  });

  final String id;
  final String name;
  final String mobileNo;
  final String email;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String approvalStatus;

  bool get isApproved => approvalStatus.toLowerCase() == 'approved';

  /// "address, city, state — pincode", skipping any empty parts.
  String get fullAddress {
    final line = [address, city, state]
        .where((e) => e.trim().isNotEmpty)
        .join(', ');
    if (pincode.trim().isEmpty) return line;
    return line.isEmpty ? pincode : '$line — $pincode';
  }

  factory AgentProfile.fromJson(Map<String, dynamic> j) => AgentProfile(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        name: (j['contact_person_name'] ??
                j['store_name'] ??
                'Area Agent')
            .toString(),
        mobileNo: (j['mobile_no'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        address: (j['full_address'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        state: (j['state'] ?? '').toString(),
        pincode: (j['pin_code'] ?? '').toString(),
        approvalStatus: (j['approvalStatus'] ?? '').toString(),
      );
}
