import 'package:flutter/material.dart';

// ─── Global theme notifier (set before runApp) ───────────────────────────────
// Declared here so AppColors can read it synchronously in getters.
late final ValueNotifier<ThemeMode> themeModeNotifier;

// ─── Dynamic Color Palette ────────────────────────────────────────────────────

class AppColors {
  static bool get _dark => themeModeNotifier.value != ThemeMode.light;

  // Surfaces
  static Color get surface => _dark ? const Color(0xFF06090F) : const Color(0xFFF1F5F9);
  static Color get panel  => _dark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF);
  static Color get card   => _dark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC);

  // Borders
  static Color get border      => _dark ? const Color(0x0FFFFFFF) : const Color(0x18000000);
  static Color get borderLight => _dark ? const Color(0x14FFFFFF) : const Color(0x22000000);

  // Accents (same in both modes)
  static const blue      = Color(0xFF3B82F6);
  static const blueDim   = Color(0x1F3B82F6);
  static const green     = Color(0xFF22C55E);
  static const greenDim  = Color(0x1F22C55E);
  static const yellow    = Color(0xFFEAB308);
  static const red       = Color(0xFFEF4444);
  static const purple    = Color(0xFF8B5CF6);

  // Text
  static Color get textStrong => _dark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
  static Color get textBase   => _dark ? const Color(0xFF9CA3AF) : const Color(0xFF374151);
  static Color get textDim    => _dark ? const Color(0xFF6B7280) : const Color(0xFF6B7280);
  static Color get textMuted  => _dark ? const Color(0xFF374151) : const Color(0xFF9CA3AF);
}

// ─── Extension Colors for file types ─────────────────────────────────────────

const Map<String, Color> extColors = {
  'js':    Color(0xFFF0DB4F), 'ts':   Color(0xFF3178C6), 'jsx':  Color(0xFF61DAFB),
  'tsx':   Color(0xFF61DAFB), 'dart': Color(0xFF00B4AB), 'py':   Color(0xFF4B8BBE),
  'kt':    Color(0xFF7F52FF), 'swift':Color(0xFFF05138), 'css':  Color(0xFF264DE4),
  'html':  Color(0xFFE34C26), 'json': Color(0xFF9CA3AF), 'md':   Color(0xFF6B7280),
  'xml':   Color(0xFFF97316), 'yaml': Color(0xFFCC3534), 'yml':  Color(0xFFCC3534),
  'sh':    Color(0xFF89E051), 'bash': Color(0xFF89E051), 'gradle':Color(0xFF02303A),
  'txt':   Color(0xFF6B7280), 'svg':  Color(0xFFFFB13B), 'png':  Color(0xFF9CA3AF),
  'jpg':   Color(0xFF9CA3AF), 'jpeg': Color(0xFF9CA3AF), 'go':   Color(0xFF00ACD7),
  'rs':    Color(0xFFDEA584), 'rb':   Color(0xFFCC342D), 'php':  Color(0xFF8892BF),
  'c':     Color(0xFF555555), 'cpp':  Color(0xFF00599C), 'h':    Color(0xFF6B7280),
  'java':  Color(0xFFF89820),
};

Color extColor(String ext) =>
    extColors[ext.toLowerCase()] ?? const Color(0xFF4B5563);

// ─── Dark Theme ───────────────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      surface: Color(0xFF0D1117),
      onSurface: Color(0xFF9CA3AF),
    ),
    scaffoldBackgroundColor: const Color(0xFF06090F),
    useMaterial3: true,
    fontFamily: 'DM Sans',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D1117),
      foregroundColor: Color(0xFFE5E7EB),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x0AFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x0FFFFFFF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x0FFFFFFF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x663B82F6))),
      hintStyle: const TextStyle(color: Color(0xFF374151)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0x0FFFFFFF), thickness: 1),
  );
}

// ─── Light Theme ─────────────────────────────────────────────────────────────

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF374151),
    ),
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    useMaterial3: true,
    fontFamily: 'DM Sans',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Color(0xFF111827),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x06000000),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x18000000))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x18000000))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x663B82F6))),
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0x18000000), thickness: 1),
  );
}

// ─── Shared Decoration Helpers ────────────────────────────────────────────────

BoxDecoration get cardDecoration => BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    );

BoxDecoration glowDecoration(Color color) => BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    );
