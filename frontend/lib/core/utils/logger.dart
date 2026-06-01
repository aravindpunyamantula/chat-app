import 'dart:developer' as developer;

class AppLogger {
  static void info(String message, {String tag = 'CHAT_APP'}) {
    developer.log(message, name: tag, level: 800);
  }

  static void warn(String message, {String tag = 'CHAT_APP'}) {
    developer.log(message, name: tag, level: 900);
  }

  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String tag = 'CHAT_APP',
  }) {
    developer.log(
      message,
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
