import 'package:flutter/material.dart';

/// Keeps a failed save visible beside the form without covering its controls.
class FormSaveError extends StatelessWidget {
  const FormSaveError({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
            liveRegion: true,
            child: Text(message,
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
      );
}
