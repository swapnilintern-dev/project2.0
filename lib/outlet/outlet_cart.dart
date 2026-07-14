// =============================================================================
// VS Arogya — Outlet Staff · Cart
//
// The staff's working basket for a manual order, built from OWN-outlet stock
// only (district stock is read-only — locked rule #1). ChangeNotifier singleton
// matching the app's controller pattern (see CartController); screens listen
// with ListenableBuilder.
//
// IDEMPOTENCY (locked requirement): a single [idempotencyKey] is generated ONCE
// when the cart goes from empty → non-empty, and stays stable for the life of
// that cart. It is sent with the create-order request so a double-tapped
// "Create order" can never produce two orders — the server returns the same
// order for a repeated key. The key is reset only when the cart is cleared
// (after a successful order, or explicitly), starting a fresh cart.
// =============================================================================

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'outlet_models.dart';

class OutletCart extends ChangeNotifier {
  OutletCart._();
  static final OutletCart instance = OutletCart._();

  final List<OutletCartLine> _lines = [];
  List<OutletCartLine> get lines => List.unmodifiable(_lines);

  /// Generated once per cart (empty → non-empty). Empty when the cart is empty.
  String _idempotencyKey = '';
  String get idempotencyKey => _idempotencyKey;

  bool get isEmpty => _lines.isEmpty;
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.qty);
  int get distinctCount => _lines.length;
  double get total => _lines.fold(0.0, (sum, l) => sum + l.lineTotal);

  int quantityOf(String productId) {
    for (final l in _lines) {
      if (l.productId == productId) return l.qty;
    }
    return 0;
  }

  /// Adds an own-outlet product (or bumps its quantity). Generates the
  /// idempotency key on the first item so it's fixed before any order is built.
  void add(OutletStockItem item, {int qty = 1}) {
    if (_lines.isEmpty) _idempotencyKey = _newIdempotencyKey();
    final idx = _lines.indexWhere((l) => l.productId == item.id);
    if (idx >= 0) {
      _lines[idx] = _lines[idx].copyWith(qty: _lines[idx].qty + qty);
    } else {
      _lines.add(OutletCartLine.fromStock(item, qty: qty));
    }
    notifyListeners();
  }

  void setQty(String productId, int qty) {
    final idx = _lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    if (qty <= 0) {
      _lines.removeAt(idx);
    } else {
      _lines[idx] = _lines[idx].copyWith(qty: qty);
    }
    if (_lines.isEmpty) _idempotencyKey = '';
    notifyListeners();
  }

  void increment(String productId) => setQty(productId, quantityOf(productId) + 1);
  void decrement(String productId) => setQty(productId, quantityOf(productId) - 1);

  void remove(String productId) => setQty(productId, 0);

  /// Empties the cart and resets the idempotency key — the NEXT add starts a
  /// brand-new cart with a fresh key. Call after an order is created.
  void clear() {
    _lines.clear();
    _idempotencyKey = '';
    notifyListeners();
  }

  static String _newIdempotencyKey() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rand = Random().nextInt(0x7fffffff).toRadixString(16);
    return 'outlet-$ts-$rand';
  }
}
