import 'package:flutter/material.dart';
import 'vendor_registration_screen.dart';
import 'splash_screen.dart';

void main() {
  runApp(const MediCaPlusApp());
}

class MediCaPlusApp extends StatelessWidget {
  const MediCaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCaPlus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
