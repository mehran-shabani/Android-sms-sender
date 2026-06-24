import 'package:flutter/material.dart';

class BrandColors {
  const BrandColors._();

  static const red = Color(0xFFF91525);
  static const deepRed = Color(0xFFC80F1F);
  static const orange = Color(0xFFFF7A00);
  static const amber = Color(0xFFFFB300);
  static const yellow = Color(0xFFFFE000);
  static const warmSurface = Color(0xFFFAFAF8);
  static const warmSurfaceAlt = Color(0xFFF0F2F4);
  static const ink = Color(0xFF202124);
}

ThemeData buildSmsSenderTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: BrandColors.red,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFD9D6),
    onPrimaryContainer: BrandColors.deepRed,
    secondary: BrandColors.orange,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFE0B8),
    onSecondaryContainer: Color(0xFF5A2500),
    tertiary: BrandColors.yellow,
    onTertiary: BrandColors.ink,
    tertiaryContainer: Color(0xFFFFF3A3),
    onTertiaryContainer: Color(0xFF4D3900),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: BrandColors.warmSurface,
    onSurface: BrandColors.ink,
    surfaceContainerHighest: Color(0xFFE8EAED),
    onSurfaceVariant: Color(0xFF5F6368),
    outline: Color(0xFFB8BDC4),
    outlineVariant: Color(0xFFDADCE0),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: BrandColors.ink,
    onInverseSurface: Color(0xFFFFF4DB),
    inversePrimary: Color(0xFFFFB4AB),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: BrandColors.warmSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: BrandColors.ink,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE6E8EB)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: BrandColors.red.withValues(alpha: 0.12),
      surfaceTintColor: BrandColors.warmSurface,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? BrandColors.red
              : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? BrandColors.deepRed
              : scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BrandColors.warmSurfaceAlt,
        disabledForegroundColor: BrandColors.ink.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandColors.deepRed,
        side: const BorderSide(color: Color(0xFFB8BDC4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: BrandColors.deepRed),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDADCE0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: BrandColors.red, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: BrandColors.red.withValues(alpha: 0.10),
      checkmarkColor: BrandColors.deepRed,
      side: const BorderSide(color: Color(0xFFDADCE0)),
      labelStyle: const TextStyle(color: BrandColors.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrandColors.red,
      linearTrackColor: BrandColors.warmSurfaceAlt,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE6E8EB)),
  );
}
