import 'package:flutter/material.dart';

/// "Forja cálida" tokens from docs/areas/stitch-design.md (dark mode).
abstract final class ForgeColors {
  static const primary = Color(0xFFFF8A3D);
  static const onPrimary = Color(0xFF14110F);
  static const background = Color(0xFF14110F);
  static const surface = Color(0xFF1E1A17);
  static const surfaceHigh = Color(0xFF2A2420);
  static const onSurface = Color(0xFFF2ECE6);
  static const onSurfaceMuted = Color(0xFFB3A79C);
  static const outline = Color(0xFF3A322C);
  static const outlineControl = Color(0xFF8A7B6F);
  static const negative = Color(0xFFF26B5B);

  static const areaHealth = Color(0xFFE07A5F);
  static const areaCareer = Color(0xFFD4A373);
  static const areaFinance = Color(0xFF81B29A);
  static const areaRelationships = Color(0xFFD98C9B);
  static const areaLeisure = Color(0xFFA88BD9);
  static const protectedTime = Color(0xFF8C9BAB);
  static const positive = Color(0xFF7BC47F);
  static const warning = Color(0xFFF2C94C);
}

ThemeData buildForgeTheme() {
  const scheme = ColorScheme.dark(
    primary: ForgeColors.primary,
    onPrimary: ForgeColors.onPrimary,
    surface: ForgeColors.background,
    onSurface: ForgeColors.onSurface,
    onSurfaceVariant: ForgeColors.onSurfaceMuted,
    surfaceContainer: ForgeColors.surface,
    surfaceContainerHigh: ForgeColors.surfaceHigh,
    outline: ForgeColors.outlineControl,
    outlineVariant: ForgeColors.outline,
    error: ForgeColors.negative,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: ForgeColors.outlineControl),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: ForgeColors.background,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ForgeColors.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: ForgeColors.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
    ),
  );
}
