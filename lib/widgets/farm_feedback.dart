import 'package:flutter/material.dart';

import '../services/api_response.dart';

String dateLabel(DateTime d) => '${d.day} ${[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ][d.month - 1]} ${d.year}';
String kgLabel(double n) => n.toStringAsFixed(1).replaceAll('.', ',');
String errorMessage(Object error,
    {String fallback = 'Terjadi kendala. Silakan coba lagi.'}) {
  if (error is String) {
    return error;
  }
  if (error is ApiException) {
    return error.message;
  }
  if (error is FormatException) {
    return error.message;
  }
  if (error is StateError) {
    return error.message;
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? fallback;
  }
  return fallback;
}

void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage(error))));
