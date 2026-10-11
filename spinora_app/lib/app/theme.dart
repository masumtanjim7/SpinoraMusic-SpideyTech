import 'package:flutter/material.dart';

/// Design tokens and color palette for Spinora Music.
class AppColors {
  AppColors._();

  /// Dark background color: #0A0A12
  static const background = Color(0xFF0A0A12);

  /// Surface / card fallback tint
  static const surface = Color(0xFF13131F);

  /// Primary purple / violet: #7C4DFF
  static const purpleAccent = Color(0xFF7C4DFF);

  /// Deeper purple for gradients
  static const deepPurple = Color(0xFF3B1E7E);

  /// Cyan accent: #00E5FF
  static const cyanAccent = Color(0xFF00E5FF);

  /// Reusable purple to deeper purple gradient
  static const purpleGradient = LinearGradient(
    colors: [purpleAccent, deepPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Top-level constants for quick access
const kBackgroundColor = AppColors.background;
const kPurpleAccent = AppColors.purpleAccent;
const kDeepPurple = AppColors.deepPurple;
const kCyanAccent = AppColors.cyanAccent;
const kPurpleGradient = AppColors.purpleGradient;

/// Spinora clean dark [ThemeData].
final spideyDarkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.purpleAccent,
    brightness: Brightness.dark,
    surface: AppColors.background,
    onSurface: const Color(0xFFF0F0FF),
    primary: AppColors.purpleAccent,
    secondary: AppColors.cyanAccent,
  ),
  scaffoldBackgroundColor: AppColors.background,
  useMaterial3: true,
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: Colors.white,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: Colors.white,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: Colors.white,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFFCCCCCC),
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: Color(0xFFAAAAAA),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
);
