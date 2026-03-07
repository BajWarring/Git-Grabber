import 'package:flutter/material.dart';

// ─── Color Palette ────────────────────────────────────────────────────────

class AppColors {
  static const surface = Color(0xFF06090F);
  static const panel = Color(0xFF0D1117);
  static const card = Color(0xFF161B22);
  static const cardHover = Color(0xFF1C2230);
  static const border = Color(0x0FFFFFFF);
  static const borderLight = Color(0x14FFFFFF);

  static const blue = Color(0xFF3B82F6);
  static const blueDim = Color(0x1F3B82F6);
  static const green = Color(0xFF22C55E);
  static const greenDim = Color(0x1F22C55E);
  static const yellow = Color(0xFFEAB308);
  static const red = Color(0xFFEF4444);
  static const purple = Color(0xFF8B5CF6);

  static const textStrong = Color(0xFFE5E7EB);
  static const textBase = Color(0xFF9CA3AF);
  static const textDim = Color(0xFF6B7280);
  static const textMuted = Color(0xFF374151);
}

// ─── Extension Colors for file types ─────────────────────────────────────

const Map<String, Color> extColors = {
  'js': Color(0xFFF0DB4F),
  'ts': Color(0xFF3178C6),
  'jsx': Color(0xFF61DAFB),
  'tsx': Color(0xFF61DAFB),
  'dart': Color(0xFF00B4AB),
  'py': Color(0xFF4B8BBE),
  'kt': Color(0xFF7F52FF),
  'swift': Color(0xFFF05138),
  'css': Color(0xFF264DE4),
  'html': Color(0xFFE34C26),
  'json': Color(0xFF9CA3AF),
  'md': Color(0xFF6B7280),
  'xml': Color(0xFFF97316),
  'yaml': Color(0xFFCC3534),
  'yml': Color(0xFFCC3534),
  'sh': Color(0xFF89E051),
  'bash': Color(0xFF89E051),
  'gradle': Color(0xFF02303A),
  'txt': Color(0xFF6B7280),
  'svg': Color(0xFFFFB13B),
  'png': Color(0xFF9CA3AF),
  'jpg': Color(0xFF9CA3AF),
  'jpeg': Color(0xFF9CA3AF),
  'go': Color(0xFF00ACD7),
  'rs': Color(0xFFDEA584),
  'rb': Color(0xFFCC342D),
  'php': Color(0xFF8892BF),
  'c': Color(0xFF555555),
  'cpp': Color(0xFF00599C),
  'h': Color(0xFF6B7280),
  'java': Color(0xFFF89820),
};

Color extColor(String ext) =>
    extColors[ext.toLowerCase()] ?? const Color(0xFF4B5563);

// ─── Theme ────────────────────────────────────────────────────────────────

ThemeData buildTheme() {
  return ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      surface: AppColors.panel,
      background: AppColors.surface,
      onBackground: AppColors.textBase,
      onSurface: AppColors.textBase,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    useMaterial3: true,
    fontFamily: 'DM Sans',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.textStrong,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0x663B82F6)),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textBase),
      bodyMedium: TextStyle(color: AppColors.textBase),
      bodySmall: TextStyle(color: AppColors.textDim),
      labelLarge: TextStyle(
          color: AppColors.textStrong, fontWeight: FontWeight.w500),
    ),
  );
}

// ─── Shared Decoration Helpers ───────────────────────────────────────────

BoxDecoration get cardDecoration => BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    );

BoxDecoration glowDecoration(Color color) => BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    );
