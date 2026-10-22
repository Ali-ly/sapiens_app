import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
        useMaterial3: true,
        platform: TargetPlatform.iOS,
        colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            surface: AppColors.surface,
            primary: AppColors.primary,
            brightness: Brightness.light));
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      cupertinoOverrideTheme: const CupertinoThemeData(
          primaryColor: AppColors.primary, brightness: Brightness.light),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder()
      }),
      textTheme: base.textTheme.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceSoft,
          labelStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          hintStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.3))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 56),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size(0, 54),
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      chipTheme: base.chipTheme.copyWith(
          backgroundColor: Colors.white,
          selectedColor: AppColors.primarySoft,
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      dividerTheme: const DividerThemeData(
          color: AppColors.divider, thickness: .7, space: 24),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}
