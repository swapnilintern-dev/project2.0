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

  /// Adds [quantity] of [product]; merges with an existing line. Fires the
  /// backend call in the background but never blocks the UI.
  void add(Product product, {int quantity = 1}) {
    final index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      _items[index] =
          _items[index].copyWith(quantity: _items[index].quantity + quantity);
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
    // Best-effort sync; result intentionally ignored (offline-safe).
    unawaited(_api.addToCart(product.id, quantity: quantity));
  }

  void setQuantity(String productId, int quantity) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    final oldQty = _items[index].quantity;
    if (quantity <= 0) {
      _items.removeAt(index);
      notifyListeners();
      unawaited(_api.removeFromCart(productId));
      return;
    }
    _items[index] = _items[index].copyWith(quantity: quantity);
    notifyListeners();
    // Mirror the change to the backend one step at a time (offline-safe).
    final delta = quantity - oldQty;
    for (var i = 0; i < delta; i++) {
      unawaited(_api.increaseCartItem(productId));
    }
    for (var i = 0; i < -delta; i++) {
      unawaited(_api.decreaseCartItem(productId));
    }
  }

  void increment(String productId) =>
      setQuantity(productId, quantityOf(productId) + 1);

  void decrement(String productId) =>
      setQuantity(productId, quantityOf(productId) - 1);

  void remove(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
    unawaited(_api.removeFromCart(productId));
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

  /// Free delivery over ₹500, otherwise a flat ₹40.
  double get deliveryFee => _items.isEmpty || subtotal >= 500 ? 0 : 40;

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

/// Saved / wishlisted products.
class WishlistController extends ChangeNotifier {
  WishlistController._();
  static final WishlistController instance = WishlistController._();

  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  bool contains(String productId) => _ids.contains(productId);

  void toggle(String productId) {
    if (!_ids.remove(productId)) _ids.add(productId);
    notifyListeners();
  }

  List<Product> resolve(List<Product> catalogue) =>
      catalogue.where((p) => _ids.contains(p.id)).toList();

  void reset() {
    _ids.clear();
    notifyListeners();
  }
}

/// In-memory order history. Seeded from mock data on first access; new orders
/// from checkout are prepended.
class OrdersController extends ChangeNotifier {
  OrdersController._();
  static final OrdersController instance = OrdersController._();

  final CustomerApi _api = CustomerApi();

  List<Order>? _orders;
  List<Order> get orders => List.unmodifiable(_orders ?? const []);

  bool get isInitialised => _orders != null;

  void ensureSeeded() {
    _orders ??= MockData.seedOrders();
  }

  /// Loads orders from the backend (GET /get-order). Replaces the list on
  /// success; on failure (offline / not logged in) keeps the local/mock seed so
  /// the screen is never empty.
  Future<void> refresh() async {
    final backend = await _api.getOrders();
    if (backend != null) {
      _orders = backend;
    } else {
      ensureSeeded();
    }
    notifyListeners();
  }

  List<Order> byFilter(OrderFilter filter) {
    ensureSeeded();
    return switch (filter) {
      OrderFilter.all => orders,
      OrderFilter.active => orders.where((o) => o.status.isActive).toList(),
      OrderFilter.delivered =>
        orders.where((o) => o.status == OrderStatus.delivered).toList(),
      OrderFilter.cancelled =>
        orders.where((o) => o.status == OrderStatus.cancelled).toList(),
    };
  }

  Order? byId(String id) {
    ensureSeeded();
    for (final o in _orders!) {
      if (o.id == id) return o;
    }
    return null;
  }

  void addOrder(Order order) {
    ensureSeeded();
    _orders!.insert(0, order);
    notifyListeners();
  }

  void cancel(String id) {
    ensureSeeded();
    final i = _orders!.indexWhere((o) => o.id == id);
    if (i < 0) return;
    _orders![i] = _orders![i].copyWith(status: OrderStatus.cancelled);
    notifyListeners();
    // Mirror to the backend (offline-safe; ignored if not logged in).
    unawaited(_api.cancelOrder(id));
  }

  /// Drops cached orders so the next access reseeds (or refetches from the API
  /// once wired). Used by [resetCustomerSession] on logout.
  void reset() {
    _orders = null;
    notifyListeners();
  }
}

/// Saved delivery addresses. Seeded from mock data; supports add/edit/delete
/// and a single default. Checkout + Profile observe this.
class AddressController extends ChangeNotifier {
  AddressController._();
  static final AddressController instance = AddressController._();

  List<Address>? _addresses;
  List<Address> get addresses {
    _addresses ??= List<Address>.from(MockData.addresses);
    return List.unmodifiable(_addresses!);
  }

  Address? get defaultAddress {
    final list = addresses;
    if (list.isEmpty) return null;
    return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
  }

  /// Drops cached addresses so the next access reseeds (or refetches once the
  /// API is wired). Used by [resetCustomerSession] on logout.
  void reset() {
    _addresses = null;
    notifyListeners();
  }

  void add(Address address) {
    final list = _ensure();
    // First address added becomes default automatically.
    final makeDefault = address.isDefault || list.isEmpty;
    if (makeDefault) _clearDefaults(list);
    list.add(address.copyWith(isDefault: makeDefault));
    notifyListeners();
  }

  void update(Address address) {
    final list = _ensure();
    final i = list.indexWhere((a) => a.id == address.id);
    if (i < 0) return;
    if (address.isDefault) _clearDefaults(list);
    list[i] = address;
    notifyListeners();
  }

  void remove(String id) {
    final list = _ensure();
    final wasDefault = list.any((a) => a.id == id && a.isDefault);
    list.removeWhere((a) => a.id == id);
    if (wasDefault && list.isNotEmpty) list[0] = list[0].copyWith(isDefault: true);
    notifyListeners();
  }

  void setDefault(String id) {
    final list = _ensure();
    _clearDefaults(list);
    final i = list.indexWhere((a) => a.id == id);
    if (i >= 0) list[i] = list[i].copyWith(isDefault: true);
    notifyListeners();
  }

  List<Address> _ensure() {
    _addresses ??= List<Address>.from(MockData.addresses);
    return _addresses!;
  }

  void _clearDefaults(List<Address> list) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].isDefault) list[i] = list[i].copyWith(isDefault: false);
    }
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
