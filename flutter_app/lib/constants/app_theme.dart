import 'package:flutter/material.dart';

class JokarzColors {
  // Midnight Obsidian & Poker Table Backgrounds
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B26);
  static const Color surfaceLight = Color(0xFF1F2637);
  static const Color card = Color(0xFF1A2234);
  static const Color cardBorder = Color(0xFF2A364F);

  // Casino Felt Emeralds
  static const Color emerald = Color(0xFF00E676);
  static const Color emeraldDark = Color(0xFF00897B);
  static const Color feltGreen = Color(0xFF0B6623);
  static const Color feltGreenDark = Color(0xFF053B13);

  // High-Roller Gold & Amber
  static const Color gold = Color(0xFFFFB300);
  static const Color goldLight = Color(0xFFFFD54F);
  static const Color goldDark = Color(0xFFFF8F00);
  static const Color amber = Color(0xFFFF9800);

  // Casino Crimson & Velvet
  static const Color crimson = Color(0xFFFF3366);
  static const Color crimsonDark = Color(0xFFB71C1C);
  static const Color velvetPurple = Color(0xFF7C4DFF);

  // Poker Suits & Accents
  static const Color spade = Color(0xFF90CAF9);
  static const Color heart = Color(0xFFFF5252);
  static const Color diamond = Color(0xFFFF7043);
  static const Color club = Color(0xFF69F0AE);

  // Text & Neutrals
  static const Color textPrimary = Color(0xFFF0F4FC);
  static const Color textSecondary = Color(0xFF8B9CB8);
  static const Color textMuted = Color(0xFF53627A);
  static const Color divider = Color(0xFF232E42);

  // Telestrator Drawing Palette
  static const List<Color> telestratorPalette = [
    Color(0xFFFFD700), // Vegas Gold
    Color(0xFFFF1744), // Laser Crimson
    Color(0xFF00E676), // Neon Emerald
    Color(0xFF00E5FF), // Cyber Cyan
    Color(0xFFFFFFFF), // Pure White
    Color(0xFFFF9100), // Amber Blaze
  ];
}

class JokarzTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: JokarzColors.background,
      colorScheme: const ColorScheme.dark(
        primary: JokarzColors.gold,
        secondary: JokarzColors.emerald,
        surface: JokarzColors.surface,
        error: JokarzColors.crimson,
        onPrimary: Color(0xFF0D1117),
        onSecondary: Color(0xFF0D1117),
        onSurface: JokarzColors.textPrimary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: JokarzColors.card,
        elevation: 4,
        shadowColor: Colors.black.withAlpha(128),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: JokarzColors.cardBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: JokarzColors.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: JokarzColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        iconTheme: IconThemeData(color: JokarzColors.gold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: JokarzColors.gold,
          foregroundColor: const Color(0xFF0D1117),
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: JokarzColors.gold,
          side: const BorderSide(color: JokarzColors.gold, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: JokarzColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: JokarzColors.cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JokarzColors.surfaceLight,
        hintStyle: const TextStyle(color: JokarzColors.textMuted),
        labelStyle: const TextStyle(color: JokarzColors.goldLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: JokarzColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: JokarzColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: JokarzColors.gold, width: 1.8),
        ),
      ),
    );
  }
}
