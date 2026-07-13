// =============================================================================
// MediCaPlus — Delivery Partner API Service
//
// Wires the delivery role to the LIVE backend using only the endpoints the
// server already exposes (the server folder is intentionally untouched):
//
//   POST /vsArogya/agent-login   { mobile, password }      -> { success, message }
//   GET  /vsArogya/all-orders                              -> every order (public)
//   PUT  /vsArogya/outof-delivery/:id   Shipped          -> Out for Delivery
//   PUT  /vsArogya/delivered-prder/:id  Out for Delivery -> Delivered
//
// A delivery agent's "tasks" are the orders currently Shipped (ready to pick
// up) or Out for Delivery (ready to complete). The backend has no per-agent
// order assignment field yet, so every agent sees the same live dispatch
// queue — see the notes in delivery_models.dart.
//
// Every method is offline-safe: it never throws and degrades to null / false so
// the UI keeps its current state instead of crashing.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import 'delivery_models.dart';

class DeliveryApi {
  DeliveryApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);

  static String get baseUrl => ApiConfig.baseUrl;

  /// Signs a delivery agent in (POST /agent-login). Agents live in their own
  /// backend collection (not the Vendor users), so this is a separate login
  /// from the staff/vendor `/login`. Returns the decoded body — inspect
  /// `body['success']`. Never throws.
  Future<Map<String, dynamic>> agentLogin(String mobile, String password) async {
    final url = '$baseUrl/vsArogya/agent-login';
    debugPrint('[Agent] POST $url mobile=$mobile');
    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mobile': mobile, 'password': password}),
          )
          .timeout(_timeout);
      debugPrint('[Agent] status=${res.statusCode} body=${res.body}');
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Unexpected server response'};
    } catch (e) {
      debugPrint('[Agent] login failed: $e');
      return {
        'success': false,
        'message': 'Could not reach the server. Check your connection.',
      };
    }
  }

  /// The live dispatch queue = orders currently Shipped or Out for Delivery
  /// (GET /all-orders, newest first). Returns null on failure so the caller
  /// keeps its current list. Orders with no items are skipped.
  Future<List<DeliveryTask>?> getTasks() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-orders'))
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['allOrders'] as List?) ?? const [];
      final tasks = <DeliveryTask>[];
      for (final j in list.whereType<Map<String, dynamic>>()) {
        final status = (j['orderStatus'] ?? '').toString();
        if (status == 'Shipped' || status == 'Out for Delivery') {
          final task = DeliveryTask.fromOrderJson(j);
          if (task.items.isNotEmpty) tasks.add(task);
        }
      }
      return tasks;
    } catch (_) {
      return null;
    }
  }

  /// The agent's completed deliveries = all orders currently "Delivered"
  /// (GET /all-orders), newest first. Returns null on failure.
  ///
  /// NOTE: the backend order has no per-agent field yet, so this returns EVERY
  /// delivered order (platform-wide), not just this agent's. Once the server
  /// stamps `deliveredBy` on delivery, filter by it here.
  Future<List<DeliveredRecord>?> getDeliveredOrders() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/vsArogya/all-orders'))
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['allOrders'] as List?) ?? const [];
      final out = <DeliveredRecord>[];
      for (final j in list.whereType<Map<String, dynamic>>()) {
        if ((j['orderStatus'] ?? '').toString() == 'Delivered') {
          out.add(DeliveredRecord.fromOrderJson(j));
        }
      }
      out.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Shipped -> Out for Delivery (agent accepts / picks up the order).
  Future<bool> pickUp(String orderId) =>
      _put('/vsArogya/outof-delivery/$orderId');

  /// Out for Delivery -> Delivered (agent completes the order).
  Future<bool> markDelivered(String orderId) =>
      _put('/vsArogya/delivered-prder/$orderId');

  Future<bool> _put(String path) async {
    try {
      final res =
          await _client.put(Uri.parse('$baseUrl$path')).timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _client.close();
}
