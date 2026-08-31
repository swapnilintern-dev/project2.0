// =============================================================================
// MediCaPlus — Promo Carousel
//
// Auto-sliding promotional banner carousel for the home screen. Banners are
// data-driven (PromoBanner) so the marketing team can add/update offers from
// the backend and have them appear here. Features: timed auto-advance, manual
// swipe, looping, animated page indicator dots, and a tappable CTA.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'customer_models.dart';

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({
    super.key,
    required this.banners,
    required this.onTap,
    this.height = 150,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner> onTap;
  final double height;
  final Duration autoPlayInterval;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  // Start in the "middle" of a large virtual range so it can loop both ways.
  static const int _virtualBase = 10000;
  late final PageController _controller =
      PageController(viewportFraction: 0.92, initialPage: _virtualBase);
  Timer? _timer;
  int _page = _virtualBase;

  int get _count => widget.banners.length;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart the timer if the banner set changed (e.g. after a refresh).
    if (oldWidget.banners.length != widget.banners.length) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (_count <= 1) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    if (_count == 1) {
      return SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _BannerCard(
              banner: widget.banners.first,
              onTap: () => widget.onTap(widget.banners.first)),
        ),
      );
    }

    final activeIndex = _page % _count;
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          // Pause auto-play while the user is interacting.
          child: Listener(
            onPointerDown: (_) => _timer?.cancel(),
            onPointerUp: (_) => _startAutoPlay(),
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, index) {
                final banner = widget.banners[index % _count];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _BannerCard(
                      banner: banner, onTap: () => widget.onTap(banner)),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_count, (i) {
            final active = i == activeIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? widget.banners[activeIndex].endColor
                    : const Color(0xFFD9E5DF),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});

  final PromoBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Image-first banners render the uploaded creative edge-to-edge; older
    // (image-less) banners fall back to the gradient + text layout below.
    if (banner.hasImage) return _imageCard();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [banner.startColor, banner.endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: banner.endColor.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      banner.ctaLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: banner.endColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.local_offer,
                color: Colors.white.withValues(alpha: 0.25), size: 56),
          ],
        ),
      ),
    );
  }

  /// Full-bleed creative for image-backed banners. Fills the carousel card
  /// (BoxFit.cover) so any uploaded aspect ratio looks right on iOS + Android,
  /// with graceful loading and error states.
  Widget _imageCard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: banner.startColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: banner.endColor.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Image.network(
          banner.imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: banner.startColor.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [banner.startColor, banner.endColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined,
                color: Colors.white70, size: 40),
          ),
        ),
      ),
    );
  }
}
