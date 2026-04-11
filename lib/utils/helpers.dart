import 'package:flutter/material.dart';

abstract class AppHelpers {
  AppHelpers._();

  /// Shows a snackbar safely — no-op if the context is unmounted.
  static void showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Formats a [DateTime] to dd/MM/yyyy.
  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
