import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'ui/eco_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoReco',
      debugShowCheckedModeBanner: false,
      theme: ecoTheme(),
      home: const LoginScreen(),
    );
  }
}
