import 'package:flutter/material.dart';
import 'pages.dart';

class AuralisApp extends StatelessWidget {
  const AuralisApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Auralis',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF536B62)),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8DA99B),
        brightness: Brightness.dark,
      ),
    ),
    home: const HomeShell(),
  );
}
