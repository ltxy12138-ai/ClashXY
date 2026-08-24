import 'dart:developer' as developer;

import 'secret_redactor.dart';

enum LogLevel { debug, info, warning, error }

abstract interface class AppLogger {
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}

class RedactingLogger implements AppLogger {
  const RedactingLogger({this.redactor = const SecretRedactor()});

  final SecretRedactor redactor;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      redactor.redact(message),
      name: 'ClashXY.${level.name}',
      error: error == null ? null : redactor.redact(error),
      stackTrace: stackTrace,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
    );
  }
}
