import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Production-safe logger.
/// All output is suppressed in release builds — safe to leave in production code.
abstract class AppLogger {
  AppLogger._();

  static void info(String tag, String message) {
    if (kDebugMode) dev.log(message, name: tag);
  }

  static void warning(String tag, String message) {
    if (kDebugMode) dev.log('⚠ $message', name: tag);
  }

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      dev.log(
        '✖ $message',
        name: tag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
