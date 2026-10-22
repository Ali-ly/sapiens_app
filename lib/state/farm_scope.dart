import 'package:flutter/widgets.dart';

import 'farm_store.dart';

/// Supplies one store for an app tree, including routes and dialogs.
class FarmScope extends InheritedNotifier<FarmStore> {
  const FarmScope({super.key, required FarmStore store, required super.child})
      : super(notifier: store);

  static FarmStore read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<FarmScope>();
    final scope = element?.widget as FarmScope?;
    if (scope == null) {
      throw StateError('FarmScope is missing above this widget.');
    }
    return scope.notifier!;
  }
}
