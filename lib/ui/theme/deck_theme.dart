import 'package:flutter/material.dart';

/// Design tokens and modern minimal OLED dark theme for the Stream Deck interface.
class DeckTheme {
  // Deep OLED dark backgrounds
  static const Color background = Color(0xFF08090C);
  static const Color surface = Color(0xFF0F1218);
  static const Color card = Color(0xFF161922);
  static const Color cardHighlight = Color(0xFF1E222F);
  static const Color border = Color(0xFF262C3D);
  static const Color borderSubtle = Color(0xFF1B202C);

  // Refined Accents
  static const Color cyan = Color(0xFF00F0FF);
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFF43F5E);
  static const Color orange = Color(0xFFFB923C);
  static const Color purple = Color(0xFFA855F7);
  static const Color yellow = Color(0xFFFBBF24);
  static const Color blue = Color(0xFF3B82F6);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: green,
        surface: surface,
        error: red,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }

  /// Converts a Hex color string (`#RRGGBB` or `#AARRGGBB`) to a Color.
  static Color fromHex(String hexString, [Color defaultColor = card]) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  /// Converts a Color to a `#RRGGBB` string.
  static String toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}'.toUpperCase();
  }
}
