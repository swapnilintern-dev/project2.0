import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'splash_screen.dart';
import 'theme/app_theme.dart';

/// Widest the app is drawn on the web. Every screen is designed for a phone,
/// so a desktop browser shows it as a centred column of this width.
const double kWebMaxContentWidth = 560;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Baseline overlay: dark status-bar icons for the light backgrounds that
  // most screens use. AppBar screens reaffirm this via the theme; screens with
  // a dark brand top (e.g. the Delivery shell) flip it to light via
  // BrandStatusBar. Keeps the status bar legible everywhere.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const MediCaPlusApp());
}

class MediCaPlusApp extends StatelessWidget {
  const MediCaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VS Arogya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Dark theme is fully built but kept staged: screens still hardcode
      // light colours, so we don't switch to ThemeMode.system until the
      // per-screen token migration is complete (avoids a broken half-dark UI).
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      // Bound the OS font-size setting app-wide.
      //
      // Android's "Font size" and iOS's Larger Text go up to ~2.0x (and much
      // further with iOS accessibility sizes). At those scales the dense screens
      // this app is built from — billing rows, batch pickers, invoice totals,
      // stat tiles — overflow rather than reflow, which turns a preference into
      // a broken screen. Capping at 1.3 keeps the app readable for users who
      // enlarge text while guaranteeing every layout still fits. Scaling DOWN is
      // left alone (floored only at 0.8), since smaller text never overflows.
      //
      // The right long-term fix is per-screen layouts that reflow at any scale;
      // until then this is the difference between "large text" and "unusable".
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final textScaler = media.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.3,
        );
        final app = child ?? const SizedBox.shrink();

        // WEB on a wide window: every screen in this app (all six roles) is
        // laid out for a phone. Stretched across a desktop browser, grids and
        // stat tiles balloon and rows spread edge to edge. So the app is shown
        // in a centred phone-width column instead, with MediaQuery reporting
        // that column's size so width-based layouts compute exactly as they do
        // on a phone. Dialogs, sheets and snackbars live inside it too.
        // Native apps are untouched (kIsWeb).
        if (kIsWeb && media.size.width > kWebMaxContentWidth) {
          return ColoredBox(
            color: const Color(0xFFE6EEEA),
            child: Center(
              child: Container(
                width: kWebMaxContentWidth,
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: ClipRect(
                  child: MediaQuery(
                    data: media.copyWith(
                      size: Size(kWebMaxContentWidth, media.size.height),
                      textScaler: textScaler,
                    ),
                    child: app,
                  ),
                ),
              ),
            ),
          );
        }

        return MediaQuery(
          data: media.copyWith(textScaler: textScaler),
          child: app,
        );
      },
      home: const SplashScreen(),
    );
  }
}
