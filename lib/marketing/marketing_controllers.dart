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

import '../customer/customer_api.dart';
import '../customer/customer_models.dart' show PromoBanner;
import 'marketing_api.dart';
import 'marketing_models.dart';

/// Incoming orders + the fulfilment pipeline.
class MarketingOrdersController extends ChangeNotifier {
  MarketingOrdersController._();
  static final MarketingOrdersController instance = MarketingOrdersController._();

  final MarketingOrdersApi _api = MarketingOrdersApi();

  final List<MarketingOrder> _orders = [];
  bool _loaded = false;

  // Which delivery agent an order was assigned to (by order id -> agent name).
  // The backend has no field to persist this yet, so it's remembered in memory
  // for the session and survives refreshes (the map isn't cleared on reload).
  final Map<String, String> _assignedAgents = {};

  List<MarketingOrder> get orders => List.unmodifiable(_orders);
  bool get isLoaded => _loaded;

  /// The delivery agent this order was assigned to, or null if none yet.
  String? assignedAgentFor(String orderId) => _assignedAgents[orderId];

  /// Loads incoming orders from the backend (GET /all-orders). On failure the
  /// current list is kept — NO mock/dummy data is ever shown.
  Future<void> refresh() async {
    final backend = await _api.getOrders();
    if (backend != null) {
      _orders
        ..clear()
        ..addAll(backend);
    }
    _loaded = true;
    notifyListeners();
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

  /// Advances an order to the next pipeline stage and persists the new status
  /// to the backend (which drives the enum
  /// Pending -> Confirm Order -> Shipped -> Out for Delivery -> Delivered).
  ///
  /// The local status is bumped optimistically for instant feedback and the
  /// matching backend endpoint is AWAITED. Returns null on success (after
  /// reconciling with the server) or a user-facing error message — e.g. the
  /// backend's "Insufficient stock for `<product>`: available X, ordered Y" when
  /// an Accept fails the stock check — in which case the optimistic status is
  /// ROLLED BACK so the pipeline never lies about the server state.
  Future<String?> advance(String id) async {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i < 0) return null;
    final previous = _orders[i];
    final next = previous.status.next;
    if (next == null) return null;
    _orders[i] = previous.copyWith(status: next);
    notifyListeners();
    final error = await _persistStatus(id, next);
    if (error != null) {
      // Roll back the optimistic bump — the server rejected the transition.
      final j = _orders.indexWhere((o) => o.id == id);
      if (j >= 0) _orders[j] = _orders[j].copyWith(status: previous.status);
      notifyListeners();
    }
    return error;
  }

  /// Assigns [agent] to the order and advances it to Out for Delivery. The
  /// status change persists to the backend (PUT /outof-delivery/:id); the agent
  /// choice is remembered locally (no server field for it yet). Returns null
  /// on success or a user-facing error.
  Future<String?> assignAgent(String orderId, DeliveryAgent agent) {
    _assignedAgents[orderId] = agent.name;
    return advance(orderId); // Shipped -> Out for Delivery (persisted)
  }

  /// Cancels an order as staff (marketing/admin) BEFORE delivery. The backend
  /// restores any stock it deducted at accept time (see the contract in
  /// MarketingOrdersApi); on success orders + stock are re-fetched so every
  /// screen updates. Returns null on success or a user-facing error message.
  Future<String?> cancelOrder(String id) async {
    final error = await _api.cancelOrder(id);
    if (error != null) return error;
    await refresh();
    unawaited(refreshStock());
    return null;
  }

  /// Creates an order on a vendor's behalf (phone order). Same lifecycle as a
  /// vendor-placed order — it lands in the Pending pipeline on success and in
  /// the vendor's own panel (their GET /get-order). Returns `(orderId, error)`.
  Future<(String?, String?)> createManualOrder({
    required String vendorId,
    required Map<String, int> items,
    required String clientOrderId,
  }) async {
    final (orderId, error) = await _api.createManualOrder(
      vendorId: vendorId,
      items: items,
      clientOrderId: clientOrderId,
    );
    if (error == null) await refresh();
    return (orderId, error);
  }

  /// Fires the backend status endpoint for [next], then reconciles the list
  /// with the server. Returns null on success or the server's error message.
  Future<String?> _persistStatus(String id, MarketingOrderStatus next) async {
    final error = switch (next) {
      MarketingOrderStatus.confirmed => await _api.confirmOrder(id),
      MarketingOrderStatus.shipped => await _api.shipOrder(id),
      MarketingOrderStatus.outForDelivery =>
        await _api.outForDeliveryOrder(id),
      MarketingOrderStatus.delivered => await _api.deliverOrder(id),
      _ => 'Nothing to update',
    };
    if (error == null) {
      // Reconcile with the backend so the pipeline shows the real status.
      await refresh();
      // Accepting deducts stock on the server — pull the fresh numbers so the
      // inventory + product pickers + customer catalogue all update reactively.
      if (next == MarketingOrderStatus.confirmed) unawaited(refreshStock());
    }
    return error;
  }

  /// Re-fetches product stock from the backend after a server-side stock
  /// mutation (accept deducts, cancel restores): the marketing inventory
  /// (MarketingProductsController) AND the shared customer Catalog (via
  /// CustomerApi.getProducts) so every stock display refreshes without a
  /// manual reload. The app itself never computes stock — it only re-reads it.
  Future<void> refreshStock() async {
    await Future.wait([
      MarketingProductsController.instance.refresh(),
      CustomerApi().getProducts(),
    ]);
  }
}

/// The medicine inventory.
class MarketingProductsController extends ChangeNotifier {
  MarketingProductsController._();
  static final MarketingProductsController instance =
      MarketingProductsController._();

  final MarketingApi _api = MarketingApi();

  // Starts empty — the inventory is ALWAYS the live backend list. No seed /
  // dummy products are ever shown; an empty list means "nothing loaded yet"
  // (spinner) or "backend has none" (empty state), never fake data.
  final List<InventoryProduct> _products = [];
  bool _loading = false;
  bool _loaded = false;

  List<InventoryProduct> get products => List.unmodifiable(_products);

  /// True while a fetch is in flight; true once at least one fetch has returned.
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;

  /// Loads the live inventory from the backend (GET /all-products). On failure
  /// (offline) the current list is kept as-is — NO mock/dummy data is shown.
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    final backend = await _api.getProducts();
    if (backend != null) {
      _products
        ..clear()
        ..addAll(backend);
    }
    _loading = false;
    _loaded = true;
    notifyListeners();
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

}

/// The promo coupons / campaigns.
class MarketingCouponsController extends ChangeNotifier {
  MarketingCouponsController._();
  static final MarketingCouponsController instance =
      MarketingCouponsController._();

  final CouponApi _api = CouponApi();

  // Starts empty — coupons are ALWAYS the live backend list; no seed/dummy
  // coupons are ever shown.
  final List<MarketingCoupon> _coupons = [];
  bool _loading = false;
  bool _loaded = false;

  List<MarketingCoupon> get coupons => List.unmodifiable(_coupons);

  bool get isLoading => _loading;
  bool get isLoaded => _loaded;

  int get activeCount => _coupons.where((c) => c.active && !c.expired).length;

  /// Loads coupons from the backend. On failure the current list is kept as-is
  /// — NO mock/dummy data is shown.
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    final backend = await _api.getCoupons();
    if (backend != null) {
      _coupons
        ..clear()
        ..addAll(backend);
    }
    _loading = false;
    _loaded = true;
    notifyListeners();
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

  /// Adds a coupon to the local list (used as an optimistic/offline fallback).
  void add(MarketingCoupon coupon) {
    _coupons.insert(0, coupon);
    notifyListeners();
  }
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

  /// Creates a banner on the backend, then refreshes so it appears on the
  /// customer home carousel. Pass an [image] for a full-image creative, or omit
  /// it for a text/gradient banner. Returns true on success.
  Future<bool> add(PromoBanner banner, [XFile? image]) async {
    final ok = await _api.addBanner(banner, image);
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

/// The registered buyer/vendor directory, fetched live from the backend
/// (GET /all-vendors, staff roles filtered out). Used by the manual-order
/// "on behalf of" vendor picker — never dummy data.
class MarketingVendorsController extends ChangeNotifier {
  MarketingVendorsController._();
  static final MarketingVendorsController instance =
      MarketingVendorsController._();

  final MarketingOrdersApi _api = MarketingOrdersApi();

  List<VendorAccount> _vendors = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<VendorAccount> get vendors => List.unmodifiable(_vendors);
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  /// Loads (or reloads) the vendor directory. Keeps the current list on
  /// failure and exposes [error] so the picker can offer a retry.
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    final res = await _api.getVendors();
    if (res == null) {
      _error = 'Could not load vendors. Check your connection.';
    } else {
      _vendors = res;
      _loaded = true;
    }
    _loading = false;
    notifyListeners();
  }
}

/// The real delivery-partner directory, fetched live from the backend
/// (role == "delivery"). Used by the "assign agent" picker — never dummy data.
class MarketingAgentsController extends ChangeNotifier {
  MarketingAgentsController._();
  static final MarketingAgentsController instance =
      MarketingAgentsController._();

  final MarketingOrdersApi _api = MarketingOrdersApi();

  List<DeliveryAgent> _agents = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<DeliveryAgent> get agents => List.unmodifiable(_agents);
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  /// Loads (or reloads) the delivery agents from the backend. Keeps the current
  /// list on failure and exposes [error] so the picker can offer a retry.
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    final res = await _api.getDeliveryAgents();
    if (res == null) {
      _error = 'Could not load delivery agents. Check your connection.';
    } else {
      _agents = res;
      _loaded = true;
    }
    _loading = false;
    notifyListeners();
  }
}
