import 'package:flutter/material.dart';

abstract final class Palette {
  static const ink = Color(0xFF153D35),
      muted = Color(0xFF69776F),
      cream = Color(0xFFF5F4ED),
      line = Color(0xFFE3E8DE),
      leaf = Color(0xFFD9EACB),
      amber = Color(0xFFB56A20),
      blue = Color(0xFF337F88);
}

ThemeData sapiensTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: Palette.ink,
      primary: Palette.ink,
      secondary: Palette.blue,
      surface: Colors.white);
  final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.cream);
  return base.copyWith(
    textTheme:
        base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    appBarTheme: const AppBarTheme(
        backgroundColor: Palette.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Palette.ink,
        centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F5EF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Palette.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Palette.ink, width: 1.5))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: base.textTheme.labelLarge
                ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: Palette.line),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: Palette.line),
        selectedColor: Palette.leaf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Palette.leaf,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 24),
  );
}
