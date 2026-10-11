import 'package:flutter/material.dart';

/// Spinora dark glassmorphism theme.
///
/// Based on a deep charcoal background with an indigo/violet accent.
/// Colors are kept in one place so every feature widget inherits them
/// via Theme.of(context) without hard-coding hex values.
final spideyDarkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C63FF), // indigo-violet accent
    brightness: Brightness.dark,
    surface: const Color(0xFF0F0F1A),     // deep charcoal
    onSurface: const Color(0xFFE8E8F0),
  ),
  scaffoldBackgroundColor: const Color(0xFF0F0F1A),
  useMaterial3: true,
  // Typography – prefer clean sans-serif until a branded font is added.
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
    ),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0F0F1A),
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1A1A2E),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
);
