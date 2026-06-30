// =============================================================================
// MediCaPlus — Marketing Head App State
//
// Global state using Flutter's built-in ChangeNotifier (matching the customer
// module's approach — no extra packages). Screens observe these singletons with
// ListenableBuilder. Seed data lives here so the screens are fully functional
// without a backend; swap the seeds for an API repository later.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../customer/customer_models.dart' show PromoBanner;
import 'marketing_api.dart';
import 'marketing_models.dart';

/// Incoming orders + the fulfilment pipeline.
class MarketingOrdersController extends ChangeNotifier {
  MarketingOrdersController._();
  static final MarketingOrdersController instance = MarketingOrdersController._();

  final MarketingOrdersApi _api = MarketingOrdersApi();

  final List<MarketingOrder> _orders = _seed();

  List<MarketingOrder> get orders => List.unmodifiable(_orders);

  /// Loads incoming orders from the backend (GET /all-orders). Keeps the seed
  /// on failure so the screen is never empty offline.
  Future<void> refresh() async {
    final backend = await _api.getOrders();
    if (backend != null) {
      _orders
        ..clear()
        ..addAll(backend);
      notifyListeners();
    }
  }

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

  /// Advances an order to the next pipeline stage (Accept -> Packing, etc.) and
  /// persists it to the backend where a matching status update exists.
  /// "Ready" (Pack) is a UI-only step with no backend equivalent.
  void advance(String id) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i < 0) return;
    final next = _orders[i].status.next;
    if (next == null) return;
    _orders[i] = _orders[i].copyWith(status: next);
    notifyListeners();
    switch (next) {
      case MarketingOrderStatus.packing:
        unawaited(_api.confirmOrder(id));
        break;
      case MarketingOrderStatus.shipped:
        unawaited(_api.shipOrder(id));
        break;
      case MarketingOrderStatus.done:
        unawaited(_api.deliverOrder(id));
        break;
      default:
        break; // "ready" — no backend stage
    }
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

  final MarketingApi _api = MarketingApi();

  final List<InventoryProduct> _products = _seed();

  List<InventoryProduct> get products => List.unmodifiable(_products);

  /// Loads the live inventory from the backend (GET /all-products) and replaces
  /// the local seed. On failure (offline) the seed is kept so the screen is
  /// never empty. Call from the products screen on init / after adding.
  Future<void> refresh() async {
    final backend = await _api.getProducts();
    if (backend != null) {
      _products
        ..clear()
        ..addAll(backend);
      notifyListeners();
    }
  }

  /// Adds a product to the backend (with its image), then refreshes the list so
  /// the new product (and its server id + image url) shows. Returns true on
  /// success; false lets the caller surface an error.
  Future<bool> addRemote(InventoryProduct product, XFile image) async {
    final ok = await _api.addProduct(product, image);
    if (ok) await refresh();
    return ok;
  }

  /// Updates a product on the backend (optionally with a new image), then
  /// refreshes. Falls back to a local update if the backend is unreachable.
  Future<bool> updateRemote(InventoryProduct product, {XFile? image}) async {
    final ok = await _api.updateProduct(product, image: image);
    if (ok) {
      await refresh();
    } else {
      update(product);
    }
    return ok;
  }

  /// Deletes a product on the backend, then refreshes. Offline-safe.
  Future<bool> deleteRemote(String id) async {
    final ok = await _api.deleteProduct(id);
    if (ok) await refresh();
    return ok;
  }

  /// The products the customer shop should display: only those the marketing
  /// head has marked active. Out-of-stock-but-active items stay in the list so
  /// the shop can show an "Out of Stock" state rather than hiding them.
  List<InventoryProduct> get activeProducts =>
      _products.where((p) => p.active).toList();

  InventoryProduct? byId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

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
    // Persist the active flag to the backend (offline-safe).
    unawaited(_api.setActive(id, becomingActive));
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

  /// Reduces stock when a customer order is confirmed. [quantitiesById] maps a
  /// product id to the ordered quantity. Stock never goes below zero. A single
  /// notify after applying every line keeps the marketing + customer screens in
  /// sync in one frame.
  ///
  /// TODO(backend): the server becomes the source of truth here — POST the
  /// confirmed order and let it decrement stock atomically, then refresh this
  /// store from the response so two buyers can't oversell the same unit.
  void decrementForOrder(Map<String, int> quantitiesById) {
    var changed = false;
    quantitiesById.forEach((id, qty) {
      final i = _products.indexWhere((p) => p.id == id);
      if (i < 0 || qty <= 0) return;
      final current = _products[i].stock;
      final next = current - qty < 0 ? 0 : current - qty;
      if (next != current) {
        _products[i] = _products[i].copyWith(stock: next);
        changed = true;
      }
    });
    if (changed) notifyListeners();
  }

  // Single source of truth for the whole app's catalogue. The marketing head
  // edits these records; the customer shop reads a live, mapped view of the
  // active ones (see lib/customer/catalog.dart). Stock decrements here when a
  // customer order is confirmed, so every screen reflects the same number.
  //
  // NOTE: this MUST be a modifiable (non-const) list — add / update / toggle /
  // decrement all mutate it in place. A `const [...]` here throws at runtime.
  static List<InventoryProduct> _seed() => [
        InventoryProduct(
          id: 'p1',
          name: 'Paracetamol 650mg',
          brand: 'Calpol · Strip of 15',
          code: 'PCM-650-15',
          category: 'Medicine',
          description:
              'Effective relief from fever and mild-to-moderate pain. Each '
              'tablet contains 650mg paracetamol IP.',
          price: 36,
          mrp: 42,
          stock: 500,
          active: true,
          packOf: 15,
          icon: Icons.medication,
          rating: 4.6,
          reviewCount: 1240,
          badge: 'BEST SELLER',
          packInfo: 'Strip of 15 tablets',
        ),
        InventoryProduct(
          id: 'p2',
          name: 'Amoxicillin 500mg',
          brand: 'Mox · 10 caps',
          code: 'AMX-500-10',
          category: 'Medicine',
          description:
              'Broad-spectrum antibiotic used to treat a wide range of '
              'bacterial infections. Take only as prescribed.',
          price: 84,
          mrp: 96,
          stock: 320,
          active: true,
          prescriptionRequired: true,
          packOf: 10,
          icon: Icons.medical_services,
          rating: 4.4,
          reviewCount: 860,
          badge: 'NEW',
          packInfo: 'Strip of 10 capsules',
        ),
        InventoryProduct(
          id: 'p3',
          name: 'Insulin Glargine',
          brand: 'Lantus · 3ml pen',
          code: 'INS-GLR-3',
          category: 'Lifesaving Injections',
          description:
              'Long-acting insulin for the management of diabetes mellitus. '
              'Refrigerate between 2°C and 8°C. Do not freeze.',
          price: 845,
          mrp: 980,
          stock: 8,
          active: true,
          prescriptionRequired: true,
          lowThreshold: 10,
          icon: Icons.vaccines,
          rating: 4.8,
          reviewCount: 410,
          badge: 'LOW STOCK',
          packInfo: '3ml prefilled pen',
        ),
        InventoryProduct(
          id: 'p4',
          name: 'Cough Syrup 100ml',
          brand: 'Benadryl',
          code: 'CGH-SYP-10',
          category: 'Medicine',
          description:
              'Soothes dry cough and throat irritation. Non-drowsy formula '
              'suitable for adults and children above 6 years.',
          price: 118,
          mrp: 135,
          stock: 0,
          active: false,
          inactiveReason: 'Expired batch withdrawn',
          icon: Icons.science,
          rating: 4.3,
          reviewCount: 690,
          packInfo: '100ml bottle',
        ),
        InventoryProduct(
          id: 'p5',
          name: 'Azithromycin 250mg',
          brand: 'Azee · 6 caps',
          code: 'AZI-250-6',
          category: 'Medicine',
          description:
              'Macrolide antibiotic capsule used for respiratory, skin and ENT '
              'infections. Complete the full course as prescribed.',
          price: 112,
          mrp: 130,
          stock: 260,
          active: true,
          prescriptionRequired: true,
          packOf: 6,
          icon: Icons.medication_outlined,
          rating: 4.5,
          reviewCount: 740,
          badge: 'BEST SELLER',
          packInfo: 'Strip of 6 capsules',
        ),
        InventoryProduct(
          id: 'p6',
          name: 'Omeprazole 20mg',
          brand: 'Omez · 15 caps',
          code: 'OMP-20-15',
          category: 'Medicine',
          description:
              'Proton-pump inhibitor capsule for acidity, heartburn and acid '
              'reflux. Take before meals or as advised.',
          price: 58,
          mrp: 72,
          stock: 340,
          active: true,
          packOf: 15,
          icon: Icons.medication_outlined,
          rating: 4.4,
          reviewCount: 530,
          packInfo: 'Strip of 15 capsules',
        ),
        InventoryProduct(
          id: 'p7',
          name: 'Antiseptic Cream 20g',
          brand: 'Burnol · Tube',
          code: 'BRN-CRM-20',
          category: 'Medicine',
          description:
              'Soothing antiseptic ointment for minor burns, cuts and '
              'abrasions. For external use only.',
          price: 75,
          mrp: 90,
          stock: 180,
          active: true,
          icon: Icons.healing,
          rating: 4.6,
          reviewCount: 910,
          badge: 'NEW',
          packInfo: '20g tube',
        ),
        InventoryProduct(
          id: 'p8',
          name: 'Pain Relief Gel 30g',
          brand: 'Volini · Tube',
          code: 'VOL-GEL-30',
          category: 'Medicine',
          description:
              'Fast-acting topical gel for muscle, joint and back pain relief. '
              'Apply gently up to thrice daily.',
          price: 145,
          mrp: 170,
          stock: 220,
          active: true,
          icon: Icons.healing,
          rating: 4.5,
          reviewCount: 1320,
          packInfo: '30g tube',
        ),
        InventoryProduct(
          id: 'p9',
          name: 'Covishield Vaccine',
          brand: 'Serum Inst · 0.5ml',
          code: 'COV-VAC-1',
          category: 'Vaccines',
          description:
              'COVID-19 viral vector vaccine, 0.5ml single dose. Stored and '
              'administered under cold-chain conditions.',
          price: 280,
          mrp: 320,
          stock: 60,
          active: true,
          prescriptionRequired: true,
          icon: Icons.vaccines,
          rating: 4.7,
          reviewCount: 205,
          packInfo: '0.5ml single dose',
        ),
      ];
}

/// The promo coupons / campaigns.
class MarketingCouponsController extends ChangeNotifier {
  MarketingCouponsController._();
  static final MarketingCouponsController instance =
      MarketingCouponsController._();

  final CouponApi _api = CouponApi();

  final List<MarketingCoupon> _coupons = _seed();

  List<MarketingCoupon> get coupons => List.unmodifiable(_coupons);

  int get activeCount => _coupons.where((c) => c.active && !c.expired).length;

  /// Loads coupons from the backend, replacing the local seed (kept on failure).
  Future<void> refresh() async {
    final backend = await _api.getCoupons();
    if (backend != null) {
      _coupons
        ..clear()
        ..addAll(backend);
      notifyListeners();
    }
  }

  void toggleActive(String code) {
    final i = _coupons.indexWhere((c) => c.code == code);
    if (i < 0 || _coupons[i].expired) return;
    _coupons[i] = _coupons[i].copyWith(active: !_coupons[i].active);
    notifyListeners();
    unawaited(_api.toggleCoupon(code)); // persist (offline-safe)
  }

  /// Creates a coupon on the backend, then refreshes. Returns null on success,
  /// or a user-facing error message (e.g. "Coupon code already exists").
  Future<String?> addRemote({
    required String code,
    String description = '',
    required double percentOff,
    double? maxDiscount,
  }) async {
    final err = await _api.addCoupon(
      code: code,
      description: description,
      percentOff: percentOff,
      maxDiscount: maxDiscount,
    );
    if (err == null) await refresh();
    return err;
  }

  /// Deletes a coupon on the backend, then refreshes.
  Future<bool> removeRemote(String code) async {
    final ok = await _api.deleteCoupon(code);
    if (ok) await refresh();
    return ok;
  }

  /// Adds a coupon to the local list (used by the campaign flow / fallback).
  void add(MarketingCoupon coupon) {
    _coupons.insert(0, coupon);
    notifyListeners();
  }

  // Modifiable (non-const) — add / toggleActive mutate it in place.
  static List<MarketingCoupon> _seed() => [
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

/// Promo banners shown on the customer home carousel. Backed by the backend
/// (GET/POST/DELETE /promo-banners) so marketing edits reach the shop.
class MarketingBannersController extends ChangeNotifier {
  MarketingBannersController._();
  static final MarketingBannersController instance =
      MarketingBannersController._();

  final BannerApi _api = BannerApi();

  List<PromoBanner> _banners = const [];
  List<PromoBanner> get banners => List.unmodifiable(_banners);

  bool _loading = false;
  bool get loading => _loading;

  /// Loads banners from the backend.
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    final fetched = await _api.getBanners();
    if (fetched != null) _banners = fetched;
    _loading = false;
    notifyListeners();
  }

  /// Creates a banner on the backend, then refreshes. Returns true on success.
  Future<bool> add(PromoBanner banner) async {
    final ok = await _api.addBanner(banner);
    if (ok) await refresh();
    return ok;
  }

  /// Deletes a banner on the backend, then refreshes.
  Future<bool> remove(String id) async {
    final ok = await _api.deleteBanner(id);
    if (ok) await refresh();
    return ok;
  }
}
