import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

final loggerHelper = _LoggerHelper();

class _LoggerHelper {
  void log(String message) {
    if (!kDebugMode) return;
    dev.log(message);
  }

  void success(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[32m[INFO] ${message}\x1B[0m');
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[31m[ERROR] ${message}\x1B[0m');
  }

  void warn(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[33m[WARN] ${message}\x1B[0m');
  }

  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[34m[DEBUG] ${message}\x1B[0m');
  }

  void logWhite(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[37m[INFO] ${message}\x1B[0m');
  }

  void logCyan(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[36m[CYAN] ${message}\x1B[0m');
  }

  void logMagenta(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[35m[MAGENTA] ${message}\x1B[0m');
  }

  void logBlue(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    dev.log('\x1B[34m[BLUE] ${message}\x1B[0m');
  }
}
