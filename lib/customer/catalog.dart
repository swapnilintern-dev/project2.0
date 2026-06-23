// =============================================================================
// MediCaPlus — Catalog Bridge (single source of truth for products/stock)
//
// The shopping app does NOT keep its own product list. It reads a live, mapped
// view of the SAME store the Marketing Head edits
// (MarketingProductsController). So:
//
//   • A medicine the marketing team adds / activates appears in the shop the
//     moment they save it.
//   • When a customer order is confirmed, stock is decremented in that one
//     store, and every screen observing it (shop + inventory) updates together.
//
// This file is the only place the customer layer reaches into the marketing
// layer, so the dependency stays contained. When the backend lands, swap the
// body of these methods to hit the server and keep the same signatures — the
// screens won't need to change.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../marketing/marketing_controllers.dart';
import '../marketing/marketing_models.dart';
import 'customer_models.dart';

class Catalog {
  Catalog._();

  static final MarketingProductsController _store =
      MarketingProductsController.instance;

  /// Screens listen to this to rebuild when products or stock change.
  static Listenable get listenable => _store;

  /// Every active product, as customer [Product]s. Out-of-stock-but-active
  /// items stay in the list (shown as "Out of Stock") rather than vanishing.
  static List<Product> get all =>
      _store.activeProducts.map(_toProduct).toList();

  /// The current shop record for [id], or null if it's gone / deactivated.
  static Product? byId(String id) {
    final inv = _store.byId(id);
    if (inv == null || !inv.active) return null;
    return _toProduct(inv);
  }

  /// Decrements stock for a confirmed order. Called from checkout once the
  /// order is placed (COD) or payment succeeds (Razorpay).
  static void decrementForOrder(List<CartItem> items) {
    final quantities = <String, int>{};
    for (final item in items) {
      quantities.update(
        item.product.id,
        (q) => q + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    _store.decrementForOrder(quantities);
  }

  /// Maps an inventory record onto the customer-facing product model.
  static Product _toProduct(InventoryProduct p) {
    return Product(
      id: p.id,
      title: p.name,
      brand: p.brand,
      description: p.description,
      price: p.price,
      mrp: p.mrp,
      category: p.categoryId,
      imageUrl: p.imageUrl,
      icon: p.icon,
      rating: p.rating,
      reviewCount: p.reviewCount,
      inStock: p.stock > 0,
      stockCount: p.stock,
      badge: p.badge,
      packInfo: p.packInfo,
    );
  }
}
