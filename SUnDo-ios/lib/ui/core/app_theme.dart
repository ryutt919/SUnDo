import 'package:flutter/material.dart';

import '../../domain/use_cases/routine_analyzer.dart';

Color hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}

class AppColors {
  static const green = Color(0xFF18CD72);
  static const darkGreen = Color(0xFF475B4A);
  static const yellow = Color(0xFFFABD03);
  static const red = Color(0xFFFF4A4A);
  static const rest = Color(0xFF7FB6FF);
  static const gray = Color(0xFFD9D9D9);
  static const paper = Color(0xFFFFFBF8);
  static const rowText = Color(0xFF222222);

  static Color forLight(TrafficLight l) => switch (l) {
        TrafficLight.green => green,
        TrafficLight.yellow => yellow,
        TrafficLight.red => red,
        TrafficLight.rest => rest,
        TrafficLight.none => gray,
      };
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: b);
    final isLight = b == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? AppColors.paper : const Color(0xFF17181A),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? AppColors.paper : const Color(0xFF17181A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : const Color(0xFF222427),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isLight ? const Color(0xFFEEEEEE) : const Color(0xFF34373A)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? AppColors.paper : const Color(0xFF17181A),
        indicatorColor: AppColors.green.withValues(alpha: 0.2),
      ),
    );
  }
}
