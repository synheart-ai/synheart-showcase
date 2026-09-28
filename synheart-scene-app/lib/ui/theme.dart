import 'package:flutter/material.dart';

/// Scene's palette, taken from the demo plan's own styling: deep green
/// headings, sage secondary text and pale green panels.
abstract final class SceneColors {
  static const ink = Color(0xFF1B3D33); // deep green — headings, primary
  static const sage = Color(0xFF6E8B7B); // secondary text
  static const panel = Color(0xFFE8F0EC); // pale green callouts
  static const paper = Color(0xFFFAFBFA); // background
  static const line = Color(0xFFD9E3DE);
  static const accent = Color(0xFF3F7CC4); // the plan's blue rule; used sparingly
  static const warm = Color(0xFFC9803D); // "Love it" and highlights
}

ThemeData sceneTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SceneColors.ink,
    primary: SceneColors.ink,
    secondary: SceneColors.sage,
    surface: SceneColors.paper,
  );
  const serif = 'Georgia';
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: SceneColors.paper);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: const TextStyle(fontFamily: serif, fontSize: 34, height: 1.1, fontWeight: FontWeight.w600, color: SceneColors.ink),
      headlineSmall: const TextStyle(fontFamily: serif, fontSize: 24, height: 1.2, fontWeight: FontWeight.w600, color: SceneColors.ink),
      titleLarge: const TextStyle(fontFamily: serif, fontSize: 20, fontWeight: FontWeight.w600, color: SceneColors.ink),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SceneColors.ink),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.45, color: Color(0xFF2E3B36)),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF2E3B36)),
      labelSmall: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: SceneColors.sage),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: SceneColors.paper, foregroundColor: SceneColors.ink, elevation: 0, centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SceneColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SceneColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: SceneColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SceneColors.line)),
    ),
    chipTheme: base.chipTheme.copyWith(side: const BorderSide(color: SceneColors.line), selectedColor: SceneColors.panel),
  );
}
