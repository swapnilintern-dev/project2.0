// =============================================================================
// MediCaPlus / VS Arogya — Splash Screen
//
// First impression of the app. A branded, animated intro:
//   • the VS Arogya logo scales in (elastic) inside a glowing ring,
//   • the wordmark + "SWASTHYA HI JEEVAN HAI" tagline fade up,
//   • medicine icons (pills, vaccine, syringe, leaf) drift upward in the back,
//   • a delivery truck drives across a dashed road (the "delivery" motif),
//   • animated loading dots, then it routes to Sign In.
//
// Pure Flutter animation — no packages, no assets required (the logo falls back
// to a vector emblem if the image is missing). Navigation timing unchanged in
// spirit: it advances automatically to SignInScreen.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vendor_registration_screen.dart' show AppColors;
import 'sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Plays once: logo + text reveal.
  late final AnimationController _intro;
  // Loops: floating icons + delivery truck + dots.
  late final AnimationController _loop;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _logoScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.62, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _textSlide = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );

    _intro.forward();

    // Advance to Sign In once the intro has had time to play.
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.darkGreen, AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Soft decorative circles.
            Positioned(
              top: -60,
              right: -40,
              child: _circle(180, Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _circle(200, Colors.white.withValues(alpha: 0.06)),
            ),

            // Drifting medicine icons in the background.
            ..._floatingIcons(size),

            // Center brand lockup.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo in a glowing ring.
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _logoRing(),
                    ),
                  ),
                  const SizedBox(height: 26),
                  // Wordmark + tagline.
                  FadeTransition(
                    opacity: _textFade,
                    child: AnimatedBuilder(
                      animation: _textSlide,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, (1 - _textSlide.value) * 18),
                        child: child,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'VS AROGYA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: const Text(
                              'SWASTHYA HI JEEVAN HAI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Delivery motif.
                  FadeTransition(
                    opacity: _textFade,
                    child: _deliveryTrack(size.width),
                  ),
                ],
              ),
            ),

            // Bottom loading dots + strapline.
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                children: [
                  _loadingDots(),
                  const SizedBox(height: 14),
                  Text(
                    'Healthcare Trading & Distribution',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- pieces --------------------------------------------------------------

  Widget _circle(double d, Color c) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  /// The FULL logo on a soft white plate (BoxFit.contain so nothing is cropped,
  /// high filter quality so it stays crisp).
  Widget _logoRing() {
    return Container(
      width: 168,
      height: 168,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 38,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const Icon(Icons.local_pharmacy_rounded,
            color: AppColors.darkGreen, size: 72),
      ),
    );
  }

  /// Background medicine icons drifting slowly upward and fading in/out.
  List<Widget> _floatingIcons(Size size) {
    const specs = <(IconData, double, double, double)>[
      // icon, x fraction, base y fraction, phase (0..1)
      (Icons.vaccines_rounded, 0.14, 0.30, 0.0),
      (Icons.medication_rounded, 0.82, 0.24, 0.35),
      (Icons.local_hospital_rounded, 0.20, 0.74, 0.6),
      (Icons.healing_rounded, 0.86, 0.70, 0.15),
      (Icons.eco_rounded, 0.50, 0.16, 0.8),
      (Icons.medical_services_rounded, 0.72, 0.84, 0.5),
    ];
    return [
      for (final s in specs)
        AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final t = (_loop.value + s.$4) % 1.0;
            final drift = math.sin(t * 2 * math.pi) * 10;
            final opacity = 0.06 + 0.10 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
            return Positioned(
              left: size.width * s.$2 - 16,
              top: size.height * s.$3 + drift,
              child: Opacity(
                opacity: opacity,
                child: Icon(s.$1, color: Colors.white, size: 34),
              ),
            );
          },
        ),
    ];
  }

  /// A delivery truck driving across a dashed road — the "timely delivery"
  /// motif. Loops continuously behind the loading dots.
  Widget _deliveryTrack(double width) {
    final trackWidth = math.min(width * 0.62, 260.0);
    return SizedBox(
      width: trackWidth,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed road.
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DashedLinePainter(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
          // Moving truck.
          AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final x = (_loop.value * (trackWidth + 40)) - 20;
              return Positioned(
                left: x,
                bottom: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_rounded,
                        color: Colors.white.withValues(alpha: 0.95), size: 26),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Three dots that pulse in sequence.
  Widget _loadingDots() {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_loop.value + i * 0.18) % 1.0;
            final scale = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Paints a thin horizontal dashed line (the delivery road).
class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 7.0;
    const gap = 6.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
