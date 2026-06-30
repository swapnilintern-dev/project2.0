import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'splash_screen.dart';
import 'theme/app_theme.dart';

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
      title: 'Vs Arogya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Dark theme is fully built but kept staged: screens still hardcode
      // light colours, so we don't switch to ThemeMode.system until the
      // per-screen token migration is complete (avoids a broken half-dark UI).
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
