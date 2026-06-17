// =============================================================================
// MediCaPlus — Marketing Head App State
//
// Global state using Flutter's built-in ChangeNotifier (matching the customer
// module's approach — no extra packages). Screens observe these singletons with
// ListenableBuilder. Seed data lives here so the screens are fully functional
// without a backend; swap the seeds for an API repository later.
// =============================================================================

import 'package:flutter/material.dart';

import 'marketing_models.dart';

/// Incoming orders + the fulfilment pipeline.
class MarketingOrdersController extends ChangeNotifier {
  MarketingOrdersController._();
  static final MarketingOrdersController instance = MarketingOrdersController._();

  final List<MarketingOrder> _orders = _seed();

  List<MarketingOrder> get orders => List.unmodifiable(_orders);

  List<MarketingOrder> byStatus(MarketingOrderStatus status) =>
      _orders.where((o) => o.status == status).toList();

  int countByStatus(MarketingOrderStatus status) =>
      _orders.where((o) => o.status == status).length;

  MarketingOrder? byId(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Advances an order to the next pipeline stage (Accept -> Packing, etc.).
  void advance(String id) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i < 0) return;
    final next = _orders[i].status.next;
    if (next == null) return;
    _orders[i] = _orders[i].copyWith(status: next);
    notifyListeners();
  }

  static List<MarketingOrder> _seed() {
    final now = DateTime.now();
    return [
      MarketingOrder(
        id: 'MCP-48210',
        buyer: 'Apollo Pharmacy',
        placedAt: now.subtract(const Duration(minutes: 5)),
        amount: 1519,
        status: MarketingOrderStatus.pending,
        urgent: true,
        isNew: true,
        phone: '+91 98200 11223',
        address: 'Shop 14, MG Road, Bengaluru, KA 560001',
        items: const [
          MarketingOrderLine(
              name: 'Paracetamol 650mg', brand: 'Medico', quantity: 10, price: 36),
          MarketingOrderLine(
              name: 'ORS Powder', brand: 'Health Inc', quantity: 12, price: 22.23),
          MarketingOrderLine(
              name: 'Digital Thermometer',
              brand: 'CarePlus',
              quantity: 4,
              price: 199,
              icon: Icons.device_thermostat_outlined),
          MarketingOrderLine(
              name: 'Zincovit Tablets',
              brand: 'Wellness Labs',
              quantity: 5,
              price: 110),
        ],
      ),
      MarketingOrder(
        id: 'MCP-48198',
        buyer: 'HealthFirst Dist.',
        placedAt: now.subtract(const Duration(minutes: 22)),
        amount: 14280,
        status: MarketingOrderStatus.pending,
        isNew: true,
        phone: '+91 99300 44556',
        address: 'Plot 8, Industrial Area, Pune, MH 411019',
        items: const [
          MarketingOrderLine(
              name: 'Amoxicillin 500mg',
              brand: 'Cipla',
              quantity: 40,
              price: 84,
              icon: Icons.medication_outlined),
          MarketingOrderLine(
              name: 'Insulin Glargine',
              brand: 'NovoMed',
              quantity: 6,
              price: 845,
              icon: Icons.vaccines_outlined),
          MarketingOrderLine(
              name: 'Surgical Gloves (L)',
              brand: 'SafeHands',
              quantity: 30,
              price: 320,
              icon: Icons.shield_outlined),
        ],
      ),
      MarketingOrder(
        id: 'MCP-48180',
        buyer: 'CarePlus Wholesale',
        placedAt: now.subtract(const Duration(hours: 1)),
        amount: 8400,
        status: MarketingOrderStatus.packing,
        phone: '+91 90040 77889',
        address: 'No 5, Anna Salai, Chennai, TN 600002',
        items: const [
          MarketingOrderLine(
              name: 'Cough Syrup', brand: 'CarePlus', quantity: 30, price: 95),
          MarketingOrderLine(
              name: 'Burnol Cream',
              brand: 'Life Co.',
              quantity: 20,
              price: 75,
              icon: Icons.healing_outlined),
          MarketingOrderLine(
              name: 'Vitamin C 1000', brand: 'Wellness Labs', quantity: 10, price: 150),
        ],
      ),
      MarketingOrder(
        id: 'MCP-48155',
        buyer: 'MediTrust Stores',
        placedAt: now.subtract(const Duration(hours: 2)),
        amount: 6750,
        status: MarketingOrderStatus.ready,
        phone: '+91 98765 22110',
        address: '22 Park Street, Kolkata, WB 700016',
        items: const [
          MarketingOrderLine(
              name: 'Paracetamol 650mg', brand: 'Medico', quantity: 60, price: 36),
          MarketingOrderLine(
              name: 'ORS Powder', brand: 'Health Inc', quantity: 35, price: 22.23),
        ],
      ),
      MarketingOrder(
        id: 'MCP-48130',
        buyer: 'Wellness Mart',
        placedAt: now.subtract(const Duration(hours: 5)),
        amount: 3990,
        status: MarketingOrderStatus.shipped,
        phone: '+91 97000 55443',
        address: '11 Residency Rd, Hyderabad, TS 500003',
        items: const [
          MarketingOrderLine(
              name: 'Zincovit Tablets',
              brand: 'Wellness Labs',
              quantity: 24,
              price: 110),
          MarketingOrderLine(
              name: 'Vitamin C 1000', brand: 'Wellness Labs', quantity: 8, price: 150),
        ],
      ),
      MarketingOrder(
        id: 'MCP-48090',
        buyer: 'City Medicos',
        placedAt: now.subtract(const Duration(days: 1)),
        amount: 2120,
        status: MarketingOrderStatus.done,
        phone: '+91 96500 33221',
        address: '7 Civil Lines, Jaipur, RJ 302006',
        items: const [
          MarketingOrderLine(
              name: 'Digital Thermometer',
              brand: 'CarePlus',
              quantity: 8,
              price: 199,
              icon: Icons.device_thermostat_outlined),
          MarketingOrderLine(
              name: 'ORS Powder', brand: 'Health Inc', quantity: 24, price: 22.23),
        ],
      ),
    ];
  }
}

/// The medicine inventory.
class MarketingProductsController extends ChangeNotifier {
  MarketingProductsController._();
  static final MarketingProductsController instance =
      MarketingProductsController._();

  final List<InventoryProduct> _products = _seed();

  List<InventoryProduct> get products => List.unmodifiable(_products);

  int get total => _products.length;
  int get activeCount => _products.where((p) => p.active).length;
  int get inactiveCount => _products.where((p) => !p.active).length;
  int get lowCount =>
      _products.where((p) => p.stockStatus == StockStatus.low).length;
  int get outCount =>
      _products.where((p) => p.stockStatus == StockStatus.out).length;

  /// Toggles a medicine's listing. Re-activating clears any inactive reason.
  void toggleActive(String id) {
    final i = _products.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final becomingActive = !_products[i].active;
    _products[i] = _products[i].copyWith(
      active: becomingActive,
      inactiveReason: becomingActive ? null : 'Manually deactivated',
      clearInactiveReason: becomingActive,
    );
    notifyListeners();
  }

  /// Adds a freshly created medicine to the top of the inventory.
  void add(InventoryProduct product) {
    _products.insert(0, product);
    notifyListeners();
  }

  /// Replaces an existing medicine (used by the Edit form).
  void update(InventoryProduct product) {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i < 0) return;
    _products[i] = product;
    notifyListeners();
  }

  static List<InventoryProduct> _seed() => const [
        InventoryProduct(
          id: 'm1',
          name: 'Burnol',
          brand: 'Life Co.',
          code: 'BRN-CRM-20',
          category: 'Cream / Ointment',
          price: 75.00,
          mrp: 90,
          stock: 350,
          active: false,
          inactiveReason: 'Out of stock',
          icon: Icons.healing_outlined,
        ),
        InventoryProduct(
          id: 'm2',
          name: 'ORS',
          brand: 'Health Inc',
          code: 'ORS-PWD-21',
          category: 'Powder',
          price: 22.23,
          mrp: 25,
          stock: 500,
          active: true,
        ),
        InventoryProduct(
          id: 'm3',
          name: 'Zincovit',
          brand: 'Wellness Labs',
          code: 'ZNC-TAB-30',
          category: 'Tablets',
          price: 110.00,
          mrp: 130,
          stock: 8,
          active: true,
          icon: Icons.medication_outlined,
        ),
        InventoryProduct(
          id: 'm4',
          name: 'Paracetamol 650',
          brand: 'Medico',
          code: 'PCM-650-15',
          category: 'Tablets',
          price: 36.00,
          mrp: 42,
          stock: 500,
          active: true,
          prescriptionRequired: false,
          icon: Icons.medication_outlined,
        ),
        InventoryProduct(
          id: 'm5',
          name: 'Cough Syrup',
          brand: 'CarePlus',
          code: 'CGH-SYP-10',
          category: 'Syrup',
          price: 95.00,
          mrp: 115,
          stock: 0,
          active: false,
          inactiveReason: 'Expired batch withdrawn',
          icon: Icons.medication_liquid_outlined,
        ),
      ];
}

/// The promo coupons / campaigns.
class MarketingCouponsController extends ChangeNotifier {
  MarketingCouponsController._();
  static final MarketingCouponsController instance =
      MarketingCouponsController._();

  final List<MarketingCoupon> _coupons = _seed();

  List<MarketingCoupon> get coupons => List.unmodifiable(_coupons);

  int get activeCount => _coupons.where((c) => c.active && !c.expired).length;

  void toggleActive(String code) {
    final i = _coupons.indexWhere((c) => c.code == code);
    if (i < 0 || _coupons[i].expired) return;
    _coupons[i] = _coupons[i].copyWith(active: !_coupons[i].active);
    notifyListeners();
  }

  /// Adds a coupon created from a campaign to the top of the list.
  void add(MarketingCoupon coupon) {
    _coupons.insert(0, coupon);
    notifyListeners();
  }

  static List<MarketingCoupon> _seed() => const [
        MarketingCoupon(
          code: 'BULK20',
          description: '20% off above ₹5,000',
          redemptions: 3840,
        ),
        MarketingCoupon(
          code: 'FIRST100',
          description: '₹100 off first order',
          redemptions: 1204,
        ),
        MarketingCoupon(
          code: 'MONSOON15',
          description: '15% off health range',
          redemptions: 890,
        ),
        MarketingCoupon(
          code: 'WELCOME50',
          description: '₹50 off · expired',
          redemptions: 5210,
          active: false,
          expired: true,
        ),
      ];
}
