import 'package:flutter/material.dart';
import 'package:sapita_app/core/theme/app_theme.dart';
import 'package:sapita_app/state/farm_scope.dart';
import 'package:sapita_app/state/farm_store.dart';

Widget buildTestApp({required FarmStore store, required Widget home}) =>
    FarmScope(
      store: store,
      child: MaterialApp(theme: AppTheme.light, home: home),
    );
