import 'package:flutter/material.dart';

/// Design tokens. Calm, high-contrast reading surfaces; one accent.
abstract final class AppColors {
  static const ink = Color(0xFF1D2433);
  static const muted = Color(0xFF5A6478);
  static const accent = Color(0xFF2F5BEA);
  static const accentSoft = Color(0xFFE6ECFD);
  static const correct = Color(0xFF1E8E4E);
  static const correctSoft = Color(0xFFE5F4EA);
  static const wrong = Color(0xFFC6392F);
  static const wrongSoft = Color(0xFFFBEAE8);
  static const mark = Color(0xFFB7791F);
  static const highlight = Color(0xFFFFF0A8);
  static const paper = Color(0xFFFAFBFD);
  static const line = Color(0xFFD9DEE8);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
}

/// Serif for passages (reads like a test booklet), sans for the interface.
const passageFont = 'serif';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );
}
