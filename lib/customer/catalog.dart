// =============================================================================
// MediCaPlus — Catalog (single source of truth for the customer shop)
//
// The shop reads every product through this facade. The list is loaded from
// the backend (GET /vsArogya/all-products) by CustomerApi.getProducts(), which
// calls [setProducts] to fill this cache. Screens observe [listenable] and read
// [all] / [byId], so they don't care where the data came from.
//
// NOTE: This used to be a live view of the Marketing inventory store. The app
// has been switched to make the BACKEND the product source of truth, so the
// marketing dependency was removed. The backend product model has no per-item
// stock field, so [decrementForOrder] is a no-op kept for API compatibility.
// =============================================================================

import 'package:flutter/foundation.dart';

import 'customer_models.dart';

class Catalog {
  Catalog._();

  /// Notifier the screens listen to so they rebuild when the list changes.
  static final ChangeNotifier _notifier = _CatalogNotifier();
  static Listenable get listenable => _notifier;

  /// In-memory cache of products fetched from the backend.
  static List<Product> _products = const [];

  /// Every product currently loaded from the backend.
  static List<Product> get all => List.unmodifiable(_products);

  /// Replaces the cache and notifies listeners. Called by CustomerApi after a
  /// successful GET /all-products.
  static void setProducts(List<Product> products) {
    _products = List<Product>.from(products);
    (_notifier as _CatalogNotifier).bump();
  }

  /// The product with [id] from the cache, or null if it isn't loaded.
  static Product? byId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// No-op: the backend product model does not track per-product stock, so
  /// there is nothing to decrement. Kept so checkout can keep calling it
  /// without change. (Stock management lives on the server when it's added.)
  static void decrementForOrder(List<CartItem> items) {
    // Intentionally empty — see file header.
  }
}

/// Tiny ChangeNotifier wrapper so [Catalog] can fire change notifications.
class _CatalogNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}
