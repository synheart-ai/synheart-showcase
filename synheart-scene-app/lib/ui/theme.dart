import 'package:flutter/material.dart';

/// Scene's palette: a dark, cinema-style home (as Resona borrows a music
/// app's dark look), in Scene's own red from its logo — no other brand's
/// name, logo or colours. Token names are kept from the first palette so
/// every screen follows; each text colour is 4.5:1 or better (WCAG AA) on
/// [paper], [card] and [panel].
abstract final class SceneColors {
  static const ink = Color(0xFFFFFFFF); // headings, primary text
  static const body = Color(0xFFE5E5E5); // body text
  static const sage = Color(0xFFB3B3B3); // secondary text — 8.8:1 on card
  static const panel = Color(0xFF232323); // callouts, sheets, secondary buttons
  static const card = Color(0xFF141414); // cards and tiles
  static const paper = Color(0xFF000000); // background
  static const line = Color(0xFF333333);
  static const red = Color(0xFFDC1929); // the logo's red — fills only (white on it 5.0:1)
  static const accent = Color(0xFFFF5A63); // red for text — 6.9:1 on black, 5.2:1 on panel
  static const warm = Color(0xFFF5C451); // highlights — stale readings
}

ThemeData sceneTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SceneColors.red,
    brightness: Brightness.dark,
    primary: SceneColors.ink,
    onPrimary: SceneColors.paper,
    secondary: SceneColors.sage,
    surface: SceneColors.paper,
    onSurface: SceneColors.ink,
    surfaceContainerLow: SceneColors.card,
    surfaceContainer: SceneColors.panel,
    surfaceContainerHigh: SceneColors.panel,
    error: SceneColors.accent,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: SceneColors.paper);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: const TextStyle(fontSize: 34, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: SceneColors.ink),
      headlineSmall: const TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: SceneColors.ink),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: SceneColors.ink),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SceneColors.ink),
      titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SceneColors.ink),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.45, color: SceneColors.body),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.45, color: SceneColors.body),
      bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: SceneColors.sage),
      labelSmall: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: SceneColors.sage),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: SceneColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: SceneColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SceneColors.ink),
    ),
    // The primary action is white with black text, as a cinema app's "Play".
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SceneColors.ink,
        foregroundColor: SceneColors.paper,
        disabledBackgroundColor: SceneColors.panel,
        disabledForegroundColor: SceneColors.sage,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    // Secondary actions: grey fill, white text.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: SceneColors.panel,
        foregroundColor: SceneColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: SceneColors.ink)),
    cardTheme: CardThemeData(
      color: SceneColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: SceneColors.paper,
      selectedColor: SceneColors.ink,
      side: const BorderSide(color: Color(0xFF808080)),
      labelStyle: const TextStyle(color: SceneColors.ink, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: SceneColors.paper, fontWeight: FontWeight.w700),
      checkmarkColor: SceneColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SceneColors.ink : SceneColors.paper),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled)
            ? SceneColors.sage
            : s.contains(WidgetState.selected)
                ? SceneColors.paper
                : SceneColors.ink),
        side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF808080))),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: SceneColors.panel, surfaceTintColor: Colors.transparent),
    dialogTheme: const DialogThemeData(backgroundColor: SceneColors.panel, surfaceTintColor: Colors.transparent),
    dividerTheme: const DividerThemeData(color: SceneColors.line),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: SceneColors.red, linearTrackColor: SceneColors.line),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(SceneColors.ink),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SceneColors.red : SceneColors.line),
    ),
    snackBarTheme: const SnackBarThemeData(backgroundColor: SceneColors.panel, contentTextStyle: TextStyle(color: SceneColors.ink)),
    iconTheme: const IconThemeData(color: SceneColors.ink),
  );
}
