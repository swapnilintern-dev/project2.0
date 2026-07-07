// =============================================================================
// MediCaPlus — Home Screen
//
// Greeting header + search entry, promotional banner, category row, featured
// products and best sellers. Pull-to-refresh reloads the catalogue from the
// API. The search bar and "See all" switch to the Search tab via [onOpenTab];
// categories push a filtered listing.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../services/auth_service.dart';
import '../theme/app_theme.dart' show AppShadows;
import '../services/live_refresh.dart';
import 'catalog.dart';
import 'customer_api.dart';
import 'customer_controllers.dart';
import 'customer_mock_data.dart';
import 'customer_models.dart';
import 'customer_widgets.dart';
import 'product_card.dart';
import 'product_list_screen.dart';
import 'promo_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Switches the shell's bottom-nav tab (1 = Search, 2 = Cart...).
  final ValueChanged<int> onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with LiveRefreshMixin {
  final CustomerApi _api = CustomerApi();
  List<Product> _products = [];
  List<PromoBanner> _banners = [];
  bool _loading = true;

  // Banners + catalogue are polled so a marketing publish appears on its own.
  // 30s keeps it fresh without hammering the API on the home tab.
  @override
  Duration get liveRefreshInterval => const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // Initial load + poll + refresh-on-resume (keeps promo banners live).
    startLiveRefresh();
    // Rebuild whenever the shared catalogue/stock changes (marketing adds a
    // medicine, an order decrements stock, an item is deactivated, …).
    Catalog.listenable.addListener(_onCatalogChanged);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    Catalog.listenable.removeListener(_onCatalogChanged);
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _load();

  void _onCatalogChanged() {
    if (!mounted) return;
    setState(() => _products = Catalog.all);
  }

  Future<void> _load() async {
    // Pull the user's saved products from the backend so the wishlist heart is
    // in sync everywhere (fire-and-forget; offline-safe).
    unawaited(WishlistController.instance.refresh());
    final results = await Future.wait([
      _api.getProducts(),
      _api.getPromoBanners(),
    ]);
    if (!mounted) return;
    setState(() {
      _products = results[0] as List<Product>;
      _banners = results[1] as List<PromoBanner>;
      _loading = false;
    });
  }

  List<Product> get _featured {
    final f = _products
        .where((p) => p.badge == 'NEW' || p.badge == 'BEST SELLER')
        .toList();
    return f.isEmpty ? _products.take(4).toList() : f;
  }

  List<Product> get _bestSellers =>
      _products.where((p) => p.badge == 'BEST SELLER').toList();

  void _openCategory(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductListScreen(initialCategory: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          children: [
            _header(),
            const SizedBox(height: 16),
            _banner(),
            const SizedBox(height: 20),
            _categories(),
            const SizedBox(height: 20),
            _section('Featured Medicines', _featured),
            const SizedBox(height: 8),
            _section('Best Sellers', _bestSellers),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  /// Time-of-day greeting (real, based on the device clock — not a fixed
  /// "Good Morning").
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      color: AppColors.lighterGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_greeting,',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.darkText)),
                  const SizedBox(height: 2),
                  // Real store name when the backend provides it; a neutral,
                  // non-fake greeting otherwise.
                  Text('${AuthService.storeName ?? 'Welcome back'} 👋',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText)),
                ],
              ),
              _bellButton(),
            ],
          ),
          const SizedBox(height: 16),
          // Tappable search "field" that routes to the Search tab.
          InkWell(
            onTap: () => widget.onOpenTab(1),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: AppColors.greyText),
                  SizedBox(width: 10),
                  Text('Search medicines, brands...',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.greyText)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bellButton() {
    return Semantics(
      button: true,
      label: 'Notifications',
      child: InkResponse(
        onTap: () => showAppSnack(context, 'No new notifications'),
        radius: 26,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // No fake unread dot — there's no notifications backend yet, so the
          // bell shows no unread indicator.
          child: const Icon(Icons.notifications_none, color: AppColors.darkText),
        ),
      ),
    );
  }

  Widget _banner() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Skeleton(height: 150, radius: 18),
      );
    }
    return PromoCarousel(
      banners: _banners,
      onTap: (banner) {
        if (banner.categoryId != null) {
          _openCategory(banner.categoryId!);
        } else {
          widget.onOpenTab(1);
        }
      },
    );
  }

  Widget _categories() {
    final cats = MockData.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeader(title: 'Categories'),
        ),
        const SizedBox(height: 12),
        // Only 3 categories exist, so spread them evenly across the full width
        // instead of a left-aligned scroll list.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (int i = 0; i < cats.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _categoryTile(cats[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryTile(Category c) {
    return InkWell(
      onTap: () => _openCategory(c.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(c.icon, color: c.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Product> products) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => const SizedBox(
                  width: 150,
                  child: Skeleton(height: 210, radius: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeader(
            title: title,
            actionLabel: 'See all',
            onAction: () => widget.onOpenTab(1),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                ProductCard(product: products[i], width: 158),
          ),
        ),
      ],
    );
  }
}
