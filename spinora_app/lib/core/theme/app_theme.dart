import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens & Colors — Dark Cosmos & Apple Lucid Glass Light
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Dark Cosmos Palette (Existing)
  static const background = Color(0xFF08070F);
  static const darkBackground = Color(0xFF08070F);
  static const surface = Color(0xFF13131F);
  static const purpleAccent = Color(0xFF7C4DFF);
  static const deepPurple = Color(0xFF3B1E7E);
  static const cyanAccent = Color(0xFF00E5FF);
  static const coralAccent = Color(0xFFFF758F);
  static const violetAccent = Color(0xFF8B5CF6);

  static const purpleGradient = LinearGradient(
    colors: [purpleAccent, deepPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Apple-Grade "Light Lucid Glass" Palette
  /// Luminous soft pearl-white and silver gradient base: #F4F5FA to #EAEEF8
  static const lightBackground = Color(0xFFF4F5FA);
  static const lightBackgroundEnd = Color(0xFFEAEEF8);
  static const lightSurface = Color(0xFFFFFFFF);

  /// Ultra-clean frosted white glass: 75% white
  static const lightGlass = Color(0xBFFFFFFF);

  /// Iridescent white border highlight: 90% white
  static const lightGlassBorder = Color(0xE6FFFFFF);

  /// Deep charcoal / slate black for primary titles: #0F111A
  static const lightTextPrimary = Color(0xFF0F111A);

  /// Muted slate for subtitles: #5C6275
  static const lightTextSecondary = Color(0xFF5C6275);

  /// Vibrant violet for active controls & accents: #7C3AED
  static const lightAccent = Color(0xFF7C3AED);

  /// Vibrant coral for secondary highlights & badges: #E63946
  static const lightAccentSecondary = Color(0xFFE63946);

  static const lightGradient = LinearGradient(
    colors: [lightAccent, lightAccentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Backward Compatibility Top-Level Constants
// ─────────────────────────────────────────────────────────────────────────────

const kBackgroundColor = AppColors.background;
const kPurpleAccent = AppColors.purpleAccent;
const kDeepPurple = AppColors.deepPurple;
const kCyanAccent = AppColors.cyanAccent;
const kPurpleGradient = AppColors.purpleGradient;

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme Definition (Dark Cosmos & Apple-Grade Light Lucid Glass)
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static final List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF7C3AED).withValues(alpha: 0.04),
      blurRadius: 16,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> darkCardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 22,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
      blurRadius: 18,
      spreadRadius: -2,
      offset: const Offset(0, 3),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark Cosmos Theme
// ─────────────────────────────────────────────────────────────────────────────

final appDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.violetAccent,
    brightness: Brightness.dark,
    surface: AppColors.darkBackground,
    onSurface: Colors.white,
    primary: AppColors.violetAccent,
    secondary: AppColors.coralAccent,
  ),
  useMaterial3: true,
  cardColor: AppColors.surface,
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
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
      color: Color(0xFFE2E8F0),
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Color(0xFF94A3B8),
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: Color(0xFFAAAAAA),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkBackground,
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

// ─────────────────────────────────────────────────────────────────────────────
// Apple-Grade Light Lucid Glass Theme
// ─────────────────────────────────────────────────────────────────────────────

final appLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.lightAccent,
    brightness: Brightness.light,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    primary: AppColors.lightAccent,
    secondary: AppColors.lightAccentSecondary,
  ),
  useMaterial3: true,
  cardColor: AppColors.lightSurface,
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: AppColors.lightTextPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.lightTextPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.15,
      color: AppColors.lightTextPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.lightTextSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: AppColors.lightTextSecondary,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightBackground,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    titleTextStyle: TextStyle(
      color: AppColors.lightTextPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
);

/// Backward-compatibility alias
final spideyDarkTheme = appDarkTheme;

// ─────────────────────────────────────────────────────────────────────────────
// BuildContext Theme Helpers
// ─────────────────────────────────────────────────────────────────────────────

extension LucidGlassThemeExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  bool get isDark => isDarkMode;
  bool get isLight => !isDarkMode;

  Color get scaffoldBg =>
      isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;

  Color get cardBg =>
      isDarkMode ? AppColors.surface : AppColors.lightSurface;

  Color get glassFill => isDarkMode
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.78);

  Color get glassBorder => isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.90);

  /// Primary text color: crisp pure white on cosmos, deep charcoal (#0F111A) on lucid light
  Color get primaryText =>
      isDarkMode ? Colors.white : AppColors.lightTextPrimary;

  /// Secondary text color: muted white/slate on cosmos, deep slate (#5C6275) on lucid light
  Color get secondaryText => isDarkMode
      ? Colors.white.withValues(alpha: 0.60)
      : AppColors.lightTextSecondary;

  /// Subtle tertiary text color
  Color get tertiaryText => isDarkMode
      ? Colors.white.withValues(alpha: 0.38)
      : const Color(0xFF5C6275).withValues(alpha: 0.70);

  /// Standard tile background (Song tiles, playlist tiles, artist tiles)
  Color get glassTileBg => isDarkMode
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.white.withValues(alpha: 0.85);

  /// Standard tile border
  Color get glassTileBorder => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.90);

  /// Standard tile shadow
  List<BoxShadow> get glassTileShadow => isDarkMode
      ? const <BoxShadow>[]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ];

  /// Search bar surface
  Color get searchBarBg => isDarkMode
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.88);

  /// Search bar border
  Color get searchBarBorder => isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.95);

  /// Search bar hint text
  Color get searchBarHint => isDarkMode
      ? Colors.white.withValues(alpha: 0.40)
      : const Color(0xFF5C6275);

  /// Primary accent color
  Color get primaryAccent =>
      isDarkMode ? AppColors.violetAccent : AppColors.lightAccent;

  /// Secondary accent color
  Color get secondaryAccent =>
      isDarkMode ? AppColors.coralAccent : AppColors.lightAccentSecondary;

  /// Cyan/Violet adaptive vibrant highlight
  Color get vibrantHighlight =>
      isDarkMode ? AppColors.cyanAccent : AppColors.lightAccent;

  List<BoxShadow> get cardShadows =>
      isDarkMode ? AppTheme.darkCardShadow : AppTheme.lightCardShadow;
}
