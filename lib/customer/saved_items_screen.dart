// =============================================================================
// MediCaPlus — Saved Items (Wishlist) Screen
//
// Shows products the user has wishlisted. Observes WishlistController so it
// updates live as items are toggled. Each row opens product details.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'customer_controllers.dart';
import 'customer_mock_data.dart';
import 'customer_widgets.dart';
import 'product_card.dart';

class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('Saved Items',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: WishlistController.instance,
        builder: (context, _) {
          final saved =
              WishlistController.instance.resolve(MockData.products);
          if (saved.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border,
              title: 'No saved items yet',
              message:
                  'Tap the heart on any product to save it here for later.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: saved.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => ProductListTile(product: saved[i]),
          );
        },
      ),
    );
  }
}
