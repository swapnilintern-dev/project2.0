// =============================================================================
// MediCaPlus — Customer App State
//
// Lightweight global state using Flutter's built-in ChangeNotifier (no extra
// packages). Screens listen with ListenableBuilder / AnimatedBuilder. This is
// the seam where a state-management library (Riverpod/Bloc) could later plug
// in: the controllers own the logic, widgets just observe them.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'customer_api.dart';
import 'customer_models.dart';
import 'customer_mock_data.dart';

/// The cart. Holds line items and exposes invoice maths.
class CartController extends ChangeNotifier {
  CartController._();
  static final CartController instance = CartController._();

  final CustomerApi _api = CustomerApi();

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  Coupon? _coupon;
  Coupon? get appliedCoupon => _coupon;

  /// Coupons available to apply, loaded from the backend (mock as fallback).
  List<Coupon> _availableCoupons = MockData.coupons;

  /// Refreshes the available coupons from the backend. Call when the cart /
  /// checkout opens so [applyCoupon] validates real, active codes.
  Future<void> loadCoupons() async {
    _availableCoupons = await _api.getCoupons();
  }

  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  int get distinctCount => _items.length;

  int quantityOf(String productId) {
    for (final i in _items) {
      if (i.product.id == productId) return i.quantity;
    }
    return 0;
  }

  // The cart is LOCAL-authoritative. We do NOT mirror every add/remove to the
  // server (that caused races + a stale/accumulating server cart). Instead the
  // whole cart is pushed to the server ONCE at checkout via
  // CustomerApi.syncCartToServer, so the placed order exactly matches this cart.

  /// Adds [quantity] of [product]; merges with an existing line.
  void add(Product product, {int quantity = 1}) {
    final index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      _items[index] =
          _items[index].copyWith(quantity: _items[index].quantity + quantity);
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void increment(String productId) =>
      setQuantity(productId, quantityOf(productId) + 1);

  void decrement(String productId) =>
      setQuantity(productId, quantityOf(productId) - 1);

  void remove(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
  }

  /// Clears the LOCAL cart only. We deliberately do NOT mirror this to the
  /// backend: clear() runs on logout (via resetCustomerSession) and after an
  /// order, and we don't want to wipe the server-side cart in those flows.
  void clear() {
    _items.clear();
    _coupon = null;
    notifyListeners();
  }

  /// Returns null when applied, or an error string when the coupon is invalid.
  String? applyCoupon(String code) {
    final match = _availableCoupons
        .where((c) => c.code.toUpperCase() == code.trim().toUpperCase());
    if (match.isEmpty) return 'Invalid coupon code';
    _coupon = match.first;
    notifyListeners();
    return null;
  }

  void removeCoupon() {
    _coupon = null;
    notifyListeners();
  }

  // --- invoice maths (single source of truth, reused by cart + checkout) ---

  double get subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);

  double get discount => _coupon?.discountFor(subtotal) ?? 0;

  /// Delivery is always FREE on the platform.
  double get deliveryFee => 0;

  /// 12% GST on the discounted subtotal.
  double get gst =>
      double.parse(((subtotal - discount) * 0.12).toStringAsFixed(2));

  double get total => subtotal - discount + deliveryFee + gst;
}

/// Clears all in-memory customer session state. Call on logout (and, once the
/// backend lands, right after a new login) so one account's cart / wishlist /
/// orders / addresses never leak into the next user's session.
void resetCustomerSession() {
  CartController.instance.clear();
  WishlistController.instance.reset();
  OrdersController.instance.reset();
  AddressController.instance.reset();
}

/// Saved / wishlisted products — backed by the server (GET /all-saved,
/// POST /save-prod/:id). The local [Set] is the source of truth for the UI and
/// is kept in sync with the backend: [refresh] pulls it, [toggle] mirrors each
/// change. Everything is offline-safe — the UI updates instantly and the
/// backend call is best-effort.
class WishlistController extends ChangeNotifier {
  WishlistController._();
  static final WishlistController instance = WishlistController._();

  final CustomerApi _api = CustomerApi();

  // id -> full product. Single source of truth (populated from /all-saved and
  // from each toggle), so the Saved screen never depends on the catalogue.
  final Map<String, Product> _products = {};

  Set<String> get ids => _products.keys.toSet();
  int get count => _products.length;

  /// The saved products themselves (newest additions last).
  List<Product> get products => _products.values.toList();

  bool contains(String productId) => _products.containsKey(productId);

  /// Pulls the saved products from the backend (GET /all-saved). Keeps the
  /// current list on failure (offline / not logged in) — never wipes it.
  Future<void> refresh() async {
    final saved = await _api.getSavedProducts();
    if (saved != null) {
      _products
        ..clear()
        ..addEntries(saved.map((p) => MapEntry(p.id, p)));
      notifyListeners();
    }
  }

  /// Optimistically flips the saved state locally, then mirrors it to the
  /// backend (POST /save-prod/:id is itself a toggle). Offline-safe.
  void toggle(Product product) {
    if (_products.remove(product.id) == null) {
      _products[product.id] = product;
    }
    notifyListeners();
    unawaited(_api.toggleSavedProduct(product.id));
  }

  /// Kept for callers that still pass the catalogue — now simply the saved
  /// products (the catalogue arg is ignored; saved products are self-contained).
  List<Product> resolve(List<Product> catalogue) => products;

  void reset() {
    _products.clear();
    notifyListeners();
  }
}

/// Order history, fetched from the backend (GET /get-order). No mock/dummy
/// data — the list is empty until [refresh] loads the user's real orders.
class OrdersController extends ChangeNotifier {
  OrdersController._();
  static final OrdersController instance = OrdersController._();

  final CustomerApi _api = CustomerApi();

  final List<Order> _orders = [];
  bool _loaded = false;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoaded => _loaded;

  /// Loads order history from the backend (GET /get-order). On failure the
  /// current list is kept — NO mock/dummy data is ever injected.
  Future<void> refresh() async {
    final backend = await _api.getOrders();
    if (backend != null) {
      // Preserve any just-placed / offline-only orders the backend list doesn't
      // (yet) contain, so a freshly-placed order is never shown as "Order not
      // found" while the server catches up — or when it was placed offline.
      final backendIds = backend.map((o) => o.id).toSet();
      final localOnly =
          _orders.where((o) => !backendIds.contains(o.id)).toList();
      _orders
        ..clear()
        ..addAll(backend)
        ..addAll(localOnly)
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    }
    _loaded = true;
    notifyListeners();
    // The user's real delivery addresses live on their past orders — feed them
    // to the address book so it reflects real data (no server change needed).
    AddressController.instance.syncFromOrders(_orders);
  }

  List<Order> byFilter(OrderFilter filter) {
    return switch (filter) {
      OrderFilter.all => orders,
      OrderFilter.active => _orders.where((o) => o.status.isActive).toList(),
      OrderFilter.delivered =>
        _orders.where((o) => o.status == OrderStatus.delivered).toList(),
      OrderFilter.cancelled =>
        _orders.where((o) => o.status == OrderStatus.cancelled).toList(),
    };
  }

  Order? byId(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Optimistically prepends a freshly-placed order (reconciled by [refresh]).
  void addOrder(Order order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void cancel(String id) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i < 0) return;
    _orders[i] = _orders[i].copyWith(status: OrderStatus.cancelled);
    notifyListeners();
    // Mirror to the backend (offline-safe; ignored if not logged in).
    unawaited(_api.cancelOrder(id));
  }

  /// Clears cached orders. Used by [resetCustomerSession] on logout.
  void reset() {
    _orders.clear();
    _loaded = false;
    notifyListeners();
  }
}

/// Saved delivery addresses. NO fake seed — the list is built from the user's
/// REAL past-order shipping addresses (via [syncFromOrders], fed by
/// [OrdersController]) plus any addresses added this session. The backend has
/// no address-book endpoint, so session-added addresses aren't persisted on
/// their own; once used in an order they reappear via the order-derived list.
/// Checkout + Profile observe this.
class AddressController extends ChangeNotifier {
  AddressController._();
  static final AddressController instance = AddressController._();

  /// Addresses the user added this session (not yet persisted server-side).
  final List<Address> _local = [];

  /// Real addresses derived from the user's past orders (GET /get-order).
  List<Address> _derived = const [];

  /// Id of the address the user chose as default (spans local + derived).
  String? _defaultId;

  /// Merged, de-duplicated address list (local first, then order-derived), with
  /// exactly one entry marked default.
  List<Address> get addresses {
    final merged = <Address>[];
    final seen = <String>{};
    for (final a in [..._local, ..._derived]) {
      if (a.line1.trim().isEmpty) continue;
      if (seen.add(a.formatted.toLowerCase())) merged.add(a);
    }
    if (merged.isEmpty) return const [];
    final chosen = _defaultId != null && merged.any((a) => a.id == _defaultId);
    return List.unmodifiable([
      for (int i = 0; i < merged.length; i++)
        merged[i].copyWith(
          isDefault: chosen ? merged[i].id == _defaultId : i == 0,
        ),
    ]);
  }

  Address? get defaultAddress {
    final list = addresses;
    if (list.isEmpty) return null;
    return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
  }

  /// Rebuilds the order-derived addresses from the user's real orders,
  /// newest-first and de-duplicated by full address.
  void syncFromOrders(List<Order> orders) {
    final sorted = List<Order>.from(orders)
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final seen = <String>{};
    final out = <Address>[];
    for (final o in sorted) {
      final a = o.address;
      if (a.line1.trim().isEmpty) continue;
      final key = a.formatted.toLowerCase();
      if (seen.add(key)) {
        out.add(a.copyWith(
          id: 'ord-${key.hashCode}',
          label: a.label.trim().isEmpty ? 'Delivery' : a.label,
        ));
      }
    }
    _derived = out;
    notifyListeners();
  }

  /// Clears all address state. Used by [resetCustomerSession] on logout.
  void reset() {
    _local.clear();
    _derived = const [];
    _defaultId = null;
    notifyListeners();
  }

  void add(Address address) {
    final id = address.id.isEmpty
        ? 'loc-${DateTime.now().microsecondsSinceEpoch}'
        : address.id;
    _local.insert(0, address.copyWith(id: id));
    // First-ever address (or one explicitly marked) becomes the default.
    if (address.isDefault || (_local.length == 1 && _derived.isEmpty)) {
      _defaultId = id;
    }
    notifyListeners();
  }

  void update(Address address) {
    final i = _local.indexWhere((a) => a.id == address.id);
    if (i >= 0) _local[i] = address; // order-derived entries are read-only
    if (address.isDefault) _defaultId = address.id;
    notifyListeners();
  }

  void remove(String id) {
    _local.removeWhere((a) => a.id == id);
    if (_defaultId == id) _defaultId = null;
    notifyListeners();
  }

  void setDefault(String id) {
    _defaultId = id;
    notifyListeners();
  }
}

enum OrderFilter { all, active, delivered, cancelled }

extension OrderFilterX on OrderFilter {
  String get label => switch (this) {
        OrderFilter.all => 'All',
        OrderFilter.active => 'Active',
        OrderFilter.delivered => 'Delivered',
        OrderFilter.cancelled => 'Cancelled',
      };
}
