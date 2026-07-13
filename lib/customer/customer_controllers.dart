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

  // ---------------------------------------------------------------------------
  // SERVER-BACKED CART
  //
  // The UI updates instantly (local list first), and every change is then
  // MIRRORED to the backend cart on the vendor's account:
  //   add        → POST   /add-cart/:id            (+1, or creates the line)
  //   increment  → POST   /increase-cart-item/:id
  //   decrement  → POST   /dec-cart-itm/:id
  //   remove     → DELETE /remove-cart-item/:id
  //   hydrate    → GET    /getCart-product          (restores cart on login)
  //
  // All mirror calls go through ONE queue ([_mirror]) so they reach the server
  // in the exact order the user tapped — parallel +/- calls were the source of
  // the old stale/accumulating-cart races. Every call is offline-safe (never
  // throws, never blocks the UI), and checkout still force-replaces the server
  // cart via [pushToServer] as a final safety net.
  //
  // THE SERVER IS THE SOURCE OF TRUTH: once the queue drains, [_reconcile]
  // re-fetches the server cart and shows exactly that. This self-heals any
  // drift (e.g. yesterday's saved cart already had the item, so today's "add"
  // made the server +1 on top of it — the screen now shows the real total
  // instead of silently diverging and "doubling" after the next restart).
  // ---------------------------------------------------------------------------

  /// The tail of the mirror queue: each new backend call is chained onto the
  /// previous one, so calls run strictly one-after-another, in tap order.
  Future<void> _syncTail = Future.value();

  /// How many queued backend calls have not finished yet. Reconciles/hydrates
  /// never overwrite the screen while the user still has edits in flight.
  int _pending = 0;

  /// Bumped on [clear] (logout / after order). A hydrate/reconcile response
  /// from a previous session is thrown away instead of resurrecting its cart.
  int _epoch = 0;

  /// True once the server cart has been loaded for this login session.
  bool _hydrated = false;

  /// Guards against overlapping hydrate calls (shell open + cart tab open).
  bool _hydrating = false;

  /// Queues one backend mirror call. Errors are swallowed so a failed call
  /// can never break the queue. When the LAST call in the queue finishes, the
  /// server cart is re-fetched so the screen matches the server exactly.
  void _mirror(Future<void> Function() op) {
    _pending++;
    final epoch = _epoch;
    _syncTail =
        _syncTail.then((_) => op()).catchError((_) {}).whenComplete(() {
      _pending--;
      if (_pending == 0 && epoch == _epoch) _reconcile(epoch);
    });
  }

  /// Replaces the local cart with the server's copy — the final word after a
  /// burst of taps. Skipped when the user made new edits meanwhile ([_pending])
  /// or logged out ([_epoch]), and on fetch failure (offline keeps local).
  Future<void> _reconcile(int epoch) async {
    final server = await _api.getCart();
    if (server == null) return;
    if (_pending > 0 || epoch != _epoch) return;
    _items
      ..clear()
      ..addAll(server);
    notifyListeners();
  }

  /// Loads the logged-in vendor's saved cart from the backend so the cart
  /// SURVIVES app restarts and re-logins. Called by the customer shell on
  /// open. Only replaces the local cart when it's empty (fresh login) — items
  /// the user already added this session are never clobbered. On failure
  /// (offline) nothing changes and the next call may retry.
  Future<void> hydrateFromServer() async {
    if (_hydrated || _hydrating) return; // once per login session
    _hydrating = true;
    final epoch = _epoch;
    final server = await _api.getCart();
    _hydrating = false;
    if (server == null) return; // couldn't reach the server — retry later
    if (epoch != _epoch) return; // logged out while the request was in flight
    _hydrated = true;
    if (_items.isNotEmpty || _pending > 0) return; // keep in-progress edits
    _items
      ..clear()
      ..addAll(server);
    notifyListeners();
  }

  /// Makes the SERVER cart exactly match the local one and CONFIRMS it —
  /// called right before /place-order, because the backend builds the order
  /// from ITS cart. Returns false when the server can't be reached or still
  /// disagrees after repair; the checkout then aborts instead of placing an
  /// order with wrong quantities.
  ///
  /// Differences are repaired with TARGETED backend calls (add / increase /
  /// decrease / remove) — never "clear everything and re-add". The old
  /// clear+re-add approach silently DOUBLED quantities: when the clear call
  /// was lost on a cold server, the re-adds piled on top of the old cart
  /// (cart showed 1, the placed order had 2).
  Future<bool> pushToServer() async {
    _pending++; // blocks a reconcile from rewriting the cart mid-sync
    try {
      await _syncTail; // let queued taps reach the server first

      var server = await _api.getCart();
      if (server == null) return false; // unreachable — don't order blind

      // Server-side quantity of one product (0 = not in the server cart).
      int serverQty(String productId) {
        for (final s in server!) {
          if (s.product.id == productId) return s.quantity;
        }
        return 0;
      }

      // 1. Fix lines the server is missing or has the wrong quantity for.
      for (final item in _items) {
        final have = serverQty(item.product.id);
        final want = item.quantity;
        if (have == 0) {
          await _api.addToCart(item.product.id, quantity: want);
        } else if (have < want) {
          for (var q = have; q < want; q++) {
            await _api.increaseCartItem(item.product.id);
          }
        } else if (have > want) {
          for (var q = have; q > want; q--) {
            await _api.decreaseCartItem(item.product.id);
          }
        }
      }

      // 2. Drop lines the server still has but the user removed locally.
      final localIds = _items.map((i) => i.product.id).toSet();
      for (final s in server) {
        if (!localIds.contains(s.product.id)) {
          await _api.removeFromCart(s.product.id);
        }
      }

      // 3. Read the server cart back — the order is only placed on an
      //    EXACT match, so a wrong-quantity order can never happen again.
      server = await _api.getCart();
      if (server == null || server.length != _items.length) return false;
      for (final item in _items) {
        if (serverQty(item.product.id) != item.quantity) return false;
      }
      return true;
    } finally {
      _pending--;
    }
  }

  /// Adds [quantity] of [product]; merges with an existing line. Mirrored via
  /// add-cart (+1 per call server-side, so one add covers new AND existing
  /// lines) plus (quantity-1) increases — handled inside CustomerApi.addToCart.
  void add(Product product, {int quantity = 1}) {
    final index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      _items[index] =
          _items[index].copyWith(quantity: _items[index].quantity + quantity);
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
    _mirror(() => _api.addToCart(product.id, quantity: quantity));
  }

  void setQuantity(String productId, int quantity) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    final before = _items[index].quantity;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
    notifyListeners();
    _mirrorLineQuantity(productId, from: before, to: quantity);
  }

  /// Mirrors one line's quantity change as increase/decrease/remove calls.
  /// If an increase fails (the line doesn't exist server-side yet), add-cart
  /// is used instead — the server treats it as "create or +1".
  void _mirrorLineQuantity(String productId,
      {required int from, required int to}) {
    _mirror(() async {
      if (to <= 0) {
        await _api.removeFromCart(productId);
      } else if (to > from) {
        for (var q = from; q < to; q++) {
          final ok = await _api.increaseCartItem(productId);
          if (!ok) await _api.addToCart(productId);
        }
      } else {
        for (var q = from; q > to; q--) {
          await _api.decreaseCartItem(productId);
        }
      }
    });
  }

  void increment(String productId) =>
      setQuantity(productId, quantityOf(productId) + 1);

  void decrement(String productId) =>
      setQuantity(productId, quantityOf(productId) - 1);

  void remove(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
    _mirror(() => _api.removeFromCart(productId));
  }

  /// Clears the LOCAL cart only. We deliberately do NOT wipe the backend cart:
  /// clear() runs on logout (via resetCustomerSession) and after an order —
  /// after an order the server has already emptied its own cart, and on logout
  /// the server copy is exactly what lets the cart REAPPEAR at next login.
  void clear() {
    _items.clear();
    _coupon = null;
    _hydrated = false; // next login re-loads the server cart
    _epoch++; // in-flight hydrate/reconcile responses become stale no-ops
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

  /// Product prices are GST-INCLUSIVE (the invoice extracts the embedded tax
  /// per slab; the backend's order total is simply price × qty). So NOTHING
  /// is added on top here — the old "+12%" made the app show a bigger total
  /// than the server actually charges.
  double get gst => 0;

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

  /// Cancels an order: optimistic local flip for instant feedback, then the
  /// backend call (PUT /cancel-order/:id) is AWAITED. On success the list is
  /// reconciled with the server and the product catalogue is re-fetched so any
  /// stock the backend restored shows up immediately in the shop. Returns true
  /// when the server confirmed the cancel (false = offline / rejected — the
  /// next refresh re-asserts the authoritative status).
  Future<bool> cancel(String id) async {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i < 0) return false;
    _orders[i] = _orders[i].copyWith(status: OrderStatus.cancelled);
    notifyListeners();
    final ok = await _api.cancelOrder(id);
    if (ok) {
      await refresh();
      // Restored stock → refresh the shared Catalog (stock displays update
      // reactively everywhere via Catalog.listenable).
      unawaited(_api.getProducts());
    }
    return ok;
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
