// =============================================================================
// VS Arogya — Outlet Staff · Cart
//
// The staff's working basket for a manual order, built from the outlet's OWN
// stock only. ChangeNotifier singleton matching the app's controller pattern
// (see CartController); screens listen with ListenableBuilder.
//
// BATCH-WISE (locked): every line is pinned to ONE lot the user chose from the
// backend's sellable batches, and a line's quantity can never exceed what that
// lot holds — [setQty] clamps to [OutletCartLine.maxQty] rather than trusting
// the caller. Re-pinning the line to another lot ([setBatch]) re-clamps against
// the new lot's availability, so the cart can never describe stock that isn't
// there. The server re-validates every pin at order time regardless.
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

  /// Lines with no lot pinned yet. The order screen refuses to submit while
  /// this is non-empty — an outlet sale must always name the batch it came from.
  List<OutletCartLine> get linesWithoutBatch =>
      _lines.where((l) => !l.hasBatch).toList();

  bool get allLinesHaveBatch => _lines.every((l) => l.hasBatch);

  int quantityOf(String productId) => lineOf(productId)?.qty ?? 0;

  /// The line for [productId], or null when the product isn't in the cart.
  /// There is at most ONE line per product, so a repeat add can never duplicate.
  OutletCartLine? lineOf(String productId) {
    for (final l in _lines) {
      if (l.productId == productId) return l;
    }
    return null;
  }

  /// The ceiling for [productId]'s quantity — the pinned lot's availability.
  /// 0 when the product isn't in the cart.
  int maxQtyOf(String productId) => lineOf(productId)?.maxQty ?? 0;

  /// Adds an own-outlet product pinned to [batch] (or bumps its quantity, still
  /// capped at that lot). Generates the idempotency key on the first item so
  /// it's fixed before any order is built.
  ///
  /// Passing [batch] on an existing line RE-PINS it, which is what the "change
  /// batch" action does — the quantity is then re-clamped to the new lot.
  void add(OutletStockItem item, {int qty = 1, OutletBatch? batch}) {
    if (_lines.isEmpty) _idempotencyKey = _newIdempotencyKey();
    final idx = _lines.indexWhere((l) => l.productId == item.id);
    if (idx >= 0) {
      final repinned = _lines[idx].copyWith(batch: batch);
      _lines[idx] = repinned.copyWith(qty: _clamp(repinned, repinned.qty + qty));
    } else {
      final line = OutletCartLine.fromStock(item, qty: qty, batch: batch);
      _lines.add(line.copyWith(qty: _clamp(line, qty)));
    }
    notifyListeners();
  }

  /// Re-pins an existing line to another lot, re-clamping its quantity to what
  /// the new lot holds. No-op when the product isn't in the cart.
  void setBatch(String productId, OutletBatch batch) {
    final idx = _lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    final repinned = _lines[idx].copyWith(batch: batch);
    _lines[idx] = repinned.copyWith(qty: _clamp(repinned, repinned.qty));
    notifyListeners();
  }

  /// Sets a line's quantity. Values at or below zero remove the line; anything
  /// above the pinned lot's availability is clamped down to it.
  void setQty(String productId, int qty) {
    final idx = _lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    if (qty <= 0) {
      _lines.removeAt(idx);
    } else {
      _lines[idx] = _lines[idx].copyWith(qty: _clamp(_lines[idx], qty));
    }
    if (_lines.isEmpty) _idempotencyKey = '';
    notifyListeners();
  }

  void increment(String productId) =>
      setQty(productId, quantityOf(productId) + 1);
  void decrement(String productId) =>
      setQty(productId, quantityOf(productId) - 1);

  void remove(String productId) => setQty(productId, 0);

  /// Empties the cart and resets the idempotency key — the NEXT add starts a
  /// brand-new cart with a fresh key. Call after an order is created.
  void clear() {
    _lines.clear();
    _idempotencyKey = '';
    notifyListeners();
  }

  /// Clamps [qty] to `1..line.maxQty`. A line with no server-reported lot size
  /// (maxQty 0 — nothing pinned yet) is left alone rather than clamped against a
  /// figure nobody knows; submitting is blocked for those lines anyway.
  static int _clamp(OutletCartLine line, int qty) {
    if (qty < 1) return 1;
    final cap = line.maxQty;
    if (cap <= 0) return qty;
    return qty > cap ? cap : qty;
  }

  static String _newIdempotencyKey() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rand = Random().nextInt(0x7fffffff).toRadixString(16);
    return 'outlet-$ts-$rand';
  }
}
