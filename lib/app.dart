import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'models/production.dart';
import 'screens/main_screen.dart';
import 'screens/profile/farm_production_screen.dart';
import 'state/farm_scope.dart';
import 'state/farm_store.dart';

class SapiensApp extends StatefulWidget {
  const SapiensApp({super.key, this.store});
  final FarmStore? store;

  @override
  State<SapiensApp> createState() => _SapiensAppState();
}

class _SapiensAppState extends State<SapiensApp> {
  late final FarmStore _store;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? FarmStore();
    if (!_store.ready) {
      _store.load();
    }
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FarmScope(
        store: _store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppStrings.appTitle,
          theme: AppTheme.light,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.background,
              systemNavigationBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              if (!_store.ready) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (_store.error != null) return const MainScreen();
              final category = _store.productionSystems?.singleCategory;
              if (category == null) return const FarmProductionScreen();
              return MainScreen(key: ValueKey(category));
            },
          ),
        ),
      );
}
