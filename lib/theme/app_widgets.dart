// =============================================================================
// MediCaPlus — Shared UI building blocks (design system, role-agnostic)
//
// Cross-cutting widgets every role reuses, so we stop re-implementing them:
//   • AppNetworkImage  — the ONLY way to render a network image: skeleton
//                        placeholder while loading, graceful fallback on error,
//                        fade-in on first frame. (Disk caching can later be
//                        swapped in behind this single widget.)
//   • AppShimmer / AppSkeletonBox — shimmer skeleton loaders (no spinners).
//   • AppEmptyState / AppErrorState — first-class empty & error screens.
//   • BrandStatusBar   — light status-bar icons over the dark brand gradients.
//   • ResponsiveCenter — caps content width so phones-app doesn't stretch ugly
//                        on tablets / large screens.
//
// Pure UI. No logic, models, routes or state touched.
// =============================================================================

import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        showCupertinoModalPopup,
        CupertinoActionSheet,
        CupertinoActionSheetAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'app_theme.dart';

// -----------------------------------------------------------------------------
// NETWORK IMAGE — placeholder + error + fade-in
// -----------------------------------------------------------------------------

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String? url;

  /// Shown when [url] is null/empty or fails to load (e.g. a category icon).
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: fit,
      width: width,
      height: height,
      // Fade the image in once the first frame is ready.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: AppDuration.base,
          curve: AppCurves.standard,
          child: child,
        );
      },
      // Shimmer while bytes are in flight (never a bare spinner).
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return AppSkeletonBox(width: width, height: height, radius: 0);
      },
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

// -----------------------------------------------------------------------------
// SHIMMER + SKELETON
// -----------------------------------------------------------------------------

class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                AppColors.lightGreenBg,
                AppColors.lighterGreen,
                AppColors.lightGreenBg,
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlideGradient(_controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Slides a gradient horizontally across its bounds as [t] goes 0→1.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues((t * 2 - 1) * bounds.width, 0, 0);
  }
}

/// A single shimmering placeholder block.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A few stacked skeleton "lines" — handy as a list-row placeholder.
class AppSkeletonLines extends StatelessWidget {
  const AppSkeletonLines({super.key, this.lines = 3, this.spacing = 10});
  final int lines;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < lines; i++) ...[
          AppSkeletonBox(
            height: 14,
            width: i.isEven ? double.infinity : 160,
          ),
          if (i != lines - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// EMPTY / ERROR STATES
// -----------------------------------------------------------------------------

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.lightGreenBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.darkGreen),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.greyText),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please try again in a moment.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 34, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.greyText)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MOTION — tactile press feedback + entrance animation
// -----------------------------------------------------------------------------

/// Subtle scale-down while pressed, for a tactile, premium feel. Uses a
/// [Listener] (raw pointer events) NOT a GestureDetector, so it never competes
/// in the gesture arena — any inner InkWell/onTap keeps working with its ripple.
/// Wrap the OUTER container of a tappable card; leave the inner tap as-is.
class AppPressable extends StatefulWidget {
  const AppPressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppDuration.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fade + gentle rise on first build — a quiet entrance for list/grid items and
/// section blocks. Animates once; cheap (no controller).
class AppFadeIn extends StatelessWidget {
  const AppFadeIn({
    super.key,
    required this.child,
    this.duration = AppDuration.slow,
    this.offsetY = 12,
  });

  final Widget child;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: AppCurves.standard,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - t) * offsetY), child: child),
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// DEBOUNCER — coalesce rapid search/filter input (UI layer). Keep one per State
// and `dispose()` it. Becomes important once search hits the network.
// -----------------------------------------------------------------------------

class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});
  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

// -----------------------------------------------------------------------------
// PLATFORM ADAPTIVITY HELPERS
// -----------------------------------------------------------------------------

/// Wrap a screen whose top is a dark brand gradient so the status-bar icons
/// render light (legible on the dark background) on both Android and iOS.
class BrandStatusBar extends StatelessWidget {
  const BrandStatusBar({super.key, required this.child, this.light = true});

  final Widget child;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: child,
    );
  }
}

/// Centres and caps content width on large screens (tablets / foldables) so a
/// phone-first layout doesn't stretch into over-wide rows.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADAPTIVE ACTION SHEET — native CupertinoActionSheet on iOS, Material bottom
// sheet on Android. One API for role action menus.
// -----------------------------------------------------------------------------

class AppSheetAction {
  const AppSheetAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

DateTime? _lastBackTapAt;

/// Two-step "press back again to exit" for a role shell's home tab — prevents an
/// accidental single-press exit. Call from the shell's PopScope when index == 0.
void maybeExitApp(BuildContext context) {
  final now = DateTime.now();
  if (_lastBackTapAt == null ||
      now.difference(_lastBackTapAt!) > const Duration(seconds: 2)) {
    _lastBackTapAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
      ));
    return;
  }
  SystemNavigator.pop();
}

Future<void> showAppActionSheet(
  BuildContext context, {
  String? title,
  required List<AppSheetAction> actions,
}) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

  if (isIOS) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: a.destructive,
              onPressed: () {
                Navigator.pop(sheetContext);
                a.onSelected();
              },
              child: Text(a.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greyText),
                ),
              ),
            ),
          for (final a in actions)
            ListTile(
              leading: Icon(a.icon,
                  color: a.destructive ? AppColors.error : AppColors.darkText),
              title: Text(
                a.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: a.destructive ? AppColors.error : AppColors.darkText,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                a.onSelected();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
