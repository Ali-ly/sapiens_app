import 'package:flutter/material.dart';

/// Shared visual tokens. Domain state and data never depend on these values.
abstract final class Palette {
  static const ink = Color(0xFF163D35),
      muted = Color(0xFF53665E),
      cream = Color(0xFFF6F7F3),
      line = Color(0xFFDEE5DE),
      leaf = Color(0xFFE4EDE5),
      amber = Color(0xFF82521B),
      warningSurface = Color(0xFFFFF3DE),
      error = Color(0xFFA43232),
      errorSurface = Color(0xFFFFEFEC),
      blue = Color(0xFF286771);
}

abstract final class AppSpace {
  static const small = 8.0, medium = 12.0, large = 20.0, section = 28.0;
}

abstract final class AppLayout {
  static const contentWidth = 1040.0, formWidth = 760.0, radius = 16.0;
  static double gutter(double width) => width < 600 ? 20 : 32;
}

ThemeData sapiensTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: Palette.ink,
      primary: Palette.ink,
      secondary: Palette.blue,
      surface: Colors.white,
      error: Palette.error,
      brightness: Brightness.light);
  final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.cream,
      visualDensity: VisualDensity.standard);
  final type =
      base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  final button =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    textTheme: type.copyWith(
      headlineSmall: type.headlineSmall?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
          height: 1.25),
      titleLarge: type.titleLarge?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.4),
      titleMedium:
          type.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: type.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: type.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: type.bodySmall
          ?.copyWith(fontSize: 12, height: 1.5, color: Palette.muted),
      labelLarge:
          type.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
        backgroundColor: Palette.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: type.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Palette.muted, fontSize: 14),
        floatingLabelStyle: const TextStyle(
            color: Palette.ink, fontSize: 14, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: Palette.muted, fontSize: 14),
        helperStyle:
            const TextStyle(color: Palette.muted, fontSize: 12, height: 1.5),
        errorMaxLines: 4,
        helperMaxLines: 4,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.line)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.ink, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.error, width: 2))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: button,
            textStyle: type.labelLarge
                ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Palette.line),
            shape: button,
            textStyle: type.labelLarge
                ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48), shape: button)),
    chipTheme: base.chipTheme.copyWith(
        labelStyle:
            type.labelMedium?.copyWith(fontSize: 13, color: Palette.ink),
        side: const BorderSide(color: Palette.line),
        selectedColor: Palette.leaf,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Palette.leaf,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            type.labelMedium!.copyWith(
                fontSize: 12,
                color: states.contains(WidgetState.selected)
                    ? Palette.ink
                    : Palette.muted,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
    dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radius)),
        titleTextStyle: type.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: type.bodyMedium),
    snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.ink,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: type.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: Palette.ink, borderRadius: BorderRadius.circular(8)),
        textStyle: type.bodySmall?.copyWith(color: Colors.white)),
    listTileTheme: const ListTileThemeData(
        iconColor: Palette.muted,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
    dividerTheme:
        const DividerThemeData(color: Palette.line, space: 28, thickness: 1),
  );
}
