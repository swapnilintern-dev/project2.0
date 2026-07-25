// =============================================================================
// VS Arogya — Area Agent · MOCK data
//
// UI-only placeholder data for the Agent role. The agent sees the orders whose
// DELIVERY ADDRESS falls in their assigned pincode, and can open one to view its
// status (pending → confirmed → out for delivery → delivered) and its line items
// (which medicine, how much quantity).
//
// Filtering is by the order's [deliveryPincode] — derived from the customer's
// delivery address — matching the agent's pincode. Stands in for a future
// backend endpoint (e.g. GET /agent/orders?pincode=XXXXXX); swap [AgentOrderMock]
// for a repository call at integration time.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;

/// The lifecycle status an agent monitors on an order. These mirror the
/// backend order vocabulary one-to-one (see getPincodeOrders): the agent feed
/// only carries the in-flight states — Pending, Confirm Order, Shipped,
/// Out for Delivery — and drops an order once it's Delivered. Ordered so
/// [index] can drive the detail-screen timeline (0 = earliest … 4 = delivered).
enum AgentOrderStatus {
  pending,
  confirmed,
  shipped,
  outForDelivery,
  delivered;

  String get label => switch (this) {
        AgentOrderStatus.pending => 'Pending',
        AgentOrderStatus.confirmed => 'Confirmed',
        AgentOrderStatus.shipped => 'Shipped',
        AgentOrderStatus.outForDelivery => 'Out for Delivery',
        AgentOrderStatus.delivered => 'Delivered',
      };

  Color get color => switch (this) {
        AgentOrderStatus.pending => Colors.orange,
        AgentOrderStatus.confirmed => Colors.blue,
        AgentOrderStatus.shipped => Colors.indigo,
        AgentOrderStatus.outForDelivery => Colors.deepPurple,
        AgentOrderStatus.delivered => AppColors.darkGreen,
      };
}

/// One line inside an order — a medicine and the quantity ordered.
class AgentOrderLine {
  const AgentOrderLine({
    required this.name,
    required this.qty,
    required this.price,
    this.packSize = '',
  });

  final String name;
  final String packSize;
  final int qty;
  final double price;

  double get lineTotal => price * qty;
}

/// One order shown to the agent. [deliveryPincode] is the pincode of the
/// customer's delivery address — the field the agent's order list filters on.
class AgentOrder {
  const AgentOrder({
    required this.id,
    required this.customerName,
    required this.deliveryAddress,
    required this.deliveryPincode,
    required this.status,
    required this.placedAgo,
    required this.lines,
  });

  final String id;
  final String customerName;
  final String deliveryAddress;
  final String deliveryPincode;
  final AgentOrderStatus status;
  final String placedAgo;
  final List<AgentOrderLine> lines;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);
  double get amount => lines.fold(0.0, (sum, l) => sum + l.lineTotal);
}

/// Mock order book. A flat list of orders across pincodes; the agent view
/// filters it by delivery pincode. Replace with a backend call.
class AgentOrderMock {
  const AgentOrderMock._();

  static const List<AgentOrder> _all = [
    AgentOrder(
      id: 'A1043',
      customerName: 'Rahul Sharma',
      deliveryAddress: '12 MG Road, Shivajinagar, Pune',
      deliveryPincode: '411001',
      status: AgentOrderStatus.pending,
      placedAgo: '12 min ago',
      lines: [
        AgentOrderLine(
            name: 'Paracetamol 500mg', qty: 3, price: 25, packSize: '10 tablets'),
        AgentOrderLine(
            name: 'Cough Syrup', qty: 1, price: 85, packSize: '100 ml'),
        AgentOrderLine(
            name: 'ORS Powder', qty: 2, price: 20, packSize: '21.8 g'),
      ],
    ),
    AgentOrder(
      id: 'A1042',
      customerName: 'Sneha Patil',
      deliveryAddress: '4 FC Road, Deccan, Pune',
      deliveryPincode: '411001',
      status: AgentOrderStatus.confirmed,
      placedAgo: '48 min ago',
      lines: [
        AgentOrderLine(
            name: 'Amoxicillin 250mg', qty: 2, price: 60, packSize: '10 capsules'),
        AgentOrderLine(
            name: 'Vitamin C', qty: 1, price: 120, packSize: '30 tablets'),
      ],
    ),
    AgentOrder(
      id: 'A1039',
      customerName: 'Imran Khan',
      deliveryAddress: '88 JM Road, Pune',
      deliveryPincode: '411001',
      status: AgentOrderStatus.outForDelivery,
      placedAgo: '2 hr ago',
      lines: [
        AgentOrderLine(
            name: 'Antacid Gel', qty: 2, price: 95, packSize: '170 ml'),
        AgentOrderLine(
            name: 'Paracetamol 500mg', qty: 5, price: 25, packSize: '10 tablets'),
      ],
    ),
    AgentOrder(
      id: 'A1035',
      customerName: 'Meera Joshi',
      deliveryAddress: '21 Laxmi Road, Pune',
      deliveryPincode: '411001',
      status: AgentOrderStatus.delivered,
      placedAgo: '5 hr ago',
      lines: [
        AgentOrderLine(
            name: 'Vitamin C', qty: 4, price: 120, packSize: '30 tablets'),
      ],
    ),
    // Different pincode — must NOT appear for a 411001 agent.
    AgentOrder(
      id: 'A1050',
      customerName: 'Anil Verma',
      deliveryAddress: '7 Model Colony, Pune',
      deliveryPincode: '411002',
      status: AgentOrderStatus.pending,
      placedAgo: '20 min ago',
      lines: [
        AgentOrderLine(
            name: 'Cough Syrup', qty: 2, price: 85, packSize: '100 ml'),
      ],
    ),
  ];

  /// Orders whose DELIVERY pincode matches [pincode] (empty if none).
  static List<AgentOrder> ordersForPincode(String pincode) =>
      _all.where((o) => o.deliveryPincode == pincode).toList();
}
