import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_screen.dart';

class SapitaApp extends StatelessWidget {
  const SapitaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppStrings.appTitle,
        theme: AppTheme.light,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.background,
              systemNavigationBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const MainScreen(),
      );
}

// Compatibility for existing integrations and older tests.
@Deprecated('Gunakan SapitaApp')
class CattleApp extends SapitaApp {
  const CattleApp({super.key});
}
