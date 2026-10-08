import 'package:flutter/material.dart';

class SalesVistaPalette {
  static const Color ink = Color(0xFF0F172A);
  static const Color slate = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color softSurface = Color(0xFFF8FAFC);
  static const Color background = Color(0xFFF3F7FB);
  static const Color primary = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color indigoDark = Color(0xFF111827);
  static const Color navy = Color(0xFF020617);
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: SalesVistaPalette.background,
    primaryColor: SalesVistaPalette.primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SalesVistaPalette.primary,
      brightness: Brightness.light,
      primary: SalesVistaPalette.primary,
      secondary: SalesVistaPalette.secondary,
      tertiary: SalesVistaPalette.emerald,
      surface: SalesVistaPalette.surface,
      error: SalesVistaPalette.rose,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: SalesVistaPalette.background,
      foregroundColor: SalesVistaPalette.ink,
      titleTextStyle: TextStyle(
        color: SalesVistaPalette.ink,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.all(10),
      color: SalesVistaPalette.surface,
      shadowColor: SalesVistaPalette.primary.withOpacity(0.10),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: Color(0xFFE5E7EB)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SalesVistaPalette.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SalesVistaPalette.primary,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SalesVistaPalette.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: SalesVistaPalette.primary,
      disabledColor: const Color(0xFFE2E8F0),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SalesVistaPalette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SalesVistaPalette.navy,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SalesVistaPalette.primary, width: 1.4),
      ),
    ),
  );
}
