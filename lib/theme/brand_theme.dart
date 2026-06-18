import 'package:flutter/material.dart';

class BrandColors {
  const BrandColors._();

  static const red = Color(0xFFF91525);
  static const deepRed = Color(0xFFC80F1F);
  static const orange = Color(0xFFFF7A00);
  static const amber = Color(0xFFFFB300);
  static const yellow = Color(0xFFFFE000);
  static const warmSurface = Color(0xFFFFF7DE);
  static const warmSurfaceAlt = Color(0xFFFFE9B5);
  static const ink = Color(0xFF2F1800);
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
    surfaceContainerHighest: Color(0xFFFFEBC1),
    onSurfaceVariant: Color(0xFF654200),
    outline: Color(0xFFD38A00),
    outlineVariant: Color(0xFFFFC46C),
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
      backgroundColor: BrandColors.red,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: BrandColors.orange.withValues(alpha: 0.18),
      surfaceTintColor: BrandColors.yellow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: BrandColors.orange.withValues(alpha: 0.14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: BrandColors.yellow.withValues(alpha: 0.42),
      surfaceTintColor: BrandColors.warmSurface,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? BrandColors.red
              : BrandColors.orange,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? BrandColors.deepRed
              : BrandColors.ink,
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
        side: const BorderSide(color: BrandColors.orange),
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
        borderSide:
            BorderSide(color: BrandColors.orange.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: BrandColors.red, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: BrandColors.yellow.withValues(alpha: 0.55),
      checkmarkColor: BrandColors.deepRed,
      side: BorderSide(color: BrandColors.orange.withValues(alpha: 0.4)),
      labelStyle: const TextStyle(color: BrandColors.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrandColors.red,
      linearTrackColor: BrandColors.warmSurfaceAlt,
    ),
    dividerTheme:
        DividerThemeData(color: BrandColors.orange.withValues(alpha: 0.35)),
  );
}
