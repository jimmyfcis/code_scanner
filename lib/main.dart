// pubspec.yaml dependencies needed:
// flutter_barcode_scanner: ^2.0.0
// or mobile_scanner: ^5.0.0 (recommended)

import 'package:code_scanner/screens/login_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD13827)),
        primaryColor: Color(0xFFD13827),
        progressIndicatorTheme: ProgressIndicatorThemeData(color: const Color(0xFFD13827)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD13827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
