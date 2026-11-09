import 'package:flutter/material.dart';
import 'pages.dart';

class AuralisApp extends StatelessWidget {
  const AuralisApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Auralis',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF080B0A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF71D6A1),
        brightness: Brightness.dark,
        surface: const Color(0xFF101613),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF080B0A),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111915),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    home: const HomeShell(),
  );
}
