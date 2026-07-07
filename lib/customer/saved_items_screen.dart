// =============================================================================
// MediCaPlus — Saved Items (Wishlist) Screen
//
// Shows products the user has saved on the backend (GET /all-saved). Pulls a
// fresh copy on open and on pull-to-refresh, and observes WishlistController so
// it updates live as items are toggled. Each row opens product details.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'customer_controllers.dart';
import 'customer_widgets.dart';
import 'product_card.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  @override
  void initState() {
    super.initState();
    // Always pull the latest saved list from the backend on open, so a login
    // on any device shows all previously-saved items here.
    WishlistController.instance.refresh();
  }

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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: WishlistController.instance.refresh,
        child: ListenableBuilder(
          listenable: WishlistController.instance,
          builder: (context, _) {
            final saved = WishlistController.instance.products;
            if (saved.isEmpty) {
              // Keep it scrollable so pull-to-refresh works when empty.
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const EmptyState(
                      icon: Icons.favorite_border,
                      title: 'No saved items yet',
                      message:
                          'Tap the heart on any product to save it here for later.',
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: saved.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => ProductListTile(product: saved[i]),
            );
          },
        ),
      ),
    );
  }
}
