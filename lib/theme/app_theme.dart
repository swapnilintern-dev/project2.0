// =============================================================================
// MediCaPlus — Design System (Phase 1, additive & non-destructive)
//
// A single source of truth for tokens + ThemeData, layered ON TOP of the
// existing brand palette (`AppColors` in vendor_registration_screen.dart) so
// the visual identity is REFINED, not replaced. Every token here encodes a
// value already used across the app, which means migrating a screen to these
// tokens is a pure refactor with no visual change — except where the Phase 0
// audit flagged an inconsistency (e.g. the Delivery teal palette), which we
// deliberately bring onto the brand green.
//
// Nothing in here touches business logic, routes, models or state. Screens opt
// in incrementally; widgets that rely on Flutter defaults pick up the refined
// component themes automatically.
//
// Exposed:
//   • AppSpacing / AppRadius / AppShadows / AppDuration / AppCurves  — tokens
//   • AppPalette        — app-wide semantic accents (info/warning/etc.)
//   • AppColorsDark     — dark-scheme surface colours (staged, see main.dart)
//   • AppTypography     — the shared TextTheme / type scale
//   • AppTheme.light / AppTheme.dark  — production ThemeData
// =============================================================================

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vendor_registration_screen.dart' show AppColors;

// -----------------------------------------------------------------------------
// SPACING — an 4pt-based rhythm (the values already peppered across the app).
// -----------------------------------------------------------------------------

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16; // the default screen gutter
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard horizontal screen padding used everywhere.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: md);
}

// -----------------------------------------------------------------------------
// RADIUS — the corner-radius scale observed in the codebase.
// -----------------------------------------------------------------------------

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 12;
  static const double button = 13;
  static const double lg = 16; // the canonical card radius
  static const double xl = 20;
  static const double xxl = 26; // hero / sheet
  static const double pill = 999;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
}

// -----------------------------------------------------------------------------
// SHADOWS / ELEVATION — the single subtle card shadow used app-wide.
// -----------------------------------------------------------------------------

abstract final class AppShadows {
  /// Soft, layered card shadow — a tight contact shadow plus a wider ambient
  /// one for real, premium-feeling depth (replaces the old near-flat shadow).
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.03),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  /// Coloured glow under primary/brand buttons so they lift off the page.
  static List<BoxShadow> brand(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.32),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];
}

// -----------------------------------------------------------------------------
// MOTION — durations & curves for micro-interactions (Phase 3 will use these).
// -----------------------------------------------------------------------------

abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration count = Duration(milliseconds: 900);
}

abstract final class AppCurves {
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
}

// -----------------------------------------------------------------------------
// SEMANTIC ACCENTS — one source for the status/category accents that were
// previously re-declared in AdminColors and hardcoded in the Delivery screens.
// -----------------------------------------------------------------------------

abstract final class AppPalette {
  static const Color success = AppColors.primary;
  static const Color danger = AppColors.error;
  static const Color info = Color(0xFF3B82F6); // blue
  static const Color warning = Color(0xFFF59E0B); // amber/orange
  static const Color purple = Color(0xFF8B5CF6);
  static const Color amber = Color(0xFFD97706);

  /// The shared brand gradient (matches AppColors.greenGradient direction).
  static const LinearGradient brandGradient = LinearGradient(
    colors: [AppColors.darkGreen, AppColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// -----------------------------------------------------------------------------
// DARK SURFACES — staged. The dark ThemeData is fully built, but main.dart
// keeps themeMode light until screens consume tokens (flipping it on before
// migration would render hardcoded-light screens incorrectly).
// -----------------------------------------------------------------------------

abstract final class AppColorsDark {
  static const Color pageBg = Color(0xFF0F1512);
  static const Color surface = Color(0xFF18211D);
  static const Color surfaceAlt = Color(0xFF1F2A25);
  static const Color border = Color(0xFF2A3A33);
  static const Color text = Color(0xFFE8F0EC);
  static const Color greyText = Color(0xFF9DB0A8);
}

// -----------------------------------------------------------------------------
// TYPOGRAPHY — the shared type scale. Sizes/weights mirror what screens already
// set inline, so adopting it changes nothing visually but kills the drift.
// -----------------------------------------------------------------------------

abstract final class AppTypography {
  static const String fontFamily = 'Roboto';

  static TextTheme textTheme(Color text, Color muted) => TextTheme(
        displaySmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: text),
        headlineSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: text),
        titleLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: text),
        titleMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: text),
        titleSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: text),
        bodyLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: text),
        bodyMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: text),
        bodySmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: muted),
        labelLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: text),
        labelMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: muted),
        labelSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted),
      );
}

// -----------------------------------------------------------------------------
// THEMES
// -----------------------------------------------------------------------------

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        scaffold: AppColors.pageBg,
        surface: AppColors.white,
        border: AppColors.border,
        text: AppColors.darkText,
        muted: AppColors.greyText,
        statusBarIcons: Brightness.dark,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scaffold: AppColorsDark.pageBg,
        surface: AppColorsDark.surface,
        border: AppColorsDark.border,
        text: AppColorsDark.text,
        muted: AppColorsDark.greyText,
        statusBarIcons: Brightness.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color border,
    required Color text,
    required Color muted,
    required Brightness statusBarIcons,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      surface: surface,
      error: AppColors.error,
    );

    final textTheme = AppTypography.textTheme(text, muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // Larger, comfortable tap targets (accessibility).
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // Native-feeling page transitions per platform (Phase 2 builds on this).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: text,
        titleTextStyle: textTheme.titleLarge!.copyWith(fontSize: 19),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarIcons,
          statusBarBrightness:
              statusBarIcons == Brightness.dark ? Brightness.light : Brightness.dark,
        ),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: muted, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.45),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.button))),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.button))),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.4)
              : null,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: surface,
        indicatorColor: AppColors.lightGreenBg,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.darkGreen
                : muted,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkGreen,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
