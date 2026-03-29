import 'package:flutter_app/core/services/app_insights_service.dart';
import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static final AppInsightsService _insights = AppInsightsService.instance;

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _insights.trackTrace(message, SeverityLevel.verbose);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _insights.trackTrace(message, SeverityLevel.information);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _insights.trackTrace(message, SeverityLevel.warning);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _insights.trackTrace(message, SeverityLevel.error);
    if (error != null) {
      _insights.trackException(error, stackTrace: stackTrace);
    }
  }

  static void event(String name, [Map<String, String>? properties]) {
    _logger.i('Event: $name${properties != null ? ' $properties' : ''}');
    _insights.trackEvent(name, properties);
  }

  static void pageView(String pageName) {
    _logger.i('PageView: $pageName');
    _insights.trackPageView(pageName);
  }
}
