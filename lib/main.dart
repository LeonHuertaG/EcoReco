import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFFB94B10));
    return MaterialApp(
      title: 'EcoReco',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colors,
        appBarTheme: AppBarThemeData(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
