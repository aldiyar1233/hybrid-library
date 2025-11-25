import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: kDebugMode ? 2 : 0,
      errorMethodCount: kDebugMode ? 5 : 3,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: kDebugMode ? Level.debug : Level.info,
  );

  // Отладочные сообщения
  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      _logger.d('🔍 $message', error: data);  // ✅ ИСПРАВЛЕНО: error вместо второго параметра
    }
  }

  // Информационные сообщения
  static void info(String message, [dynamic data]) {
    _logger.i('ℹ️ $message', error: data);  // ✅ ИСПРАВЛЕНО
  }

  // Предупреждения
  static void warning(String message, [dynamic data]) {
    _logger.w('⚠️ $message', error: data);  // ✅ ИСПРАВЛЕНО
  }

  // Ошибки
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e('❌ $message', error: error, stackTrace: stackTrace);  // ✅ Это правильно
  }

  // API запросы
  static void api({
    required String method,
    required String endpoint,
    Map<String, dynamic>? headers,
    dynamic data,
    int? statusCode,
    dynamic response,
  }) {
    final status = statusCode != null 
      ? (statusCode >= 200 && statusCode < 300 ? '✅' : '❌')
      : '📡';
    
    final logMessage = '$status $method $endpoint';
    final logData = {
      if (headers != null) 'headers': headers,
      if (data != null) 'request': data,
      if (statusCode != null) 'status': statusCode,
      if (response != null) 'response': response,
    };
    
    if (statusCode != null && statusCode >= 400) {
      _logger.e(logMessage, error: logData);  // ✅ ИСПРАВЛЕНО
    } else {
      _logger.i(logMessage, error: logData.isNotEmpty ? logData : null);  // ✅ ИСПРАВЛЕНО
    }
  }

  // Навигация
  static void navigation(String message, [String? route]) {
    _logger.i('🧭 $message${route != null ? ": $route" : ""}');
  }

  // Действия пользователя
  static void userAction(String action, [Map<String, dynamic>? details]) {
    _logger.i('👆 Действие: $action', error: details);  // ✅ ИСПРАВЛЕНО
  }

  // Состояние приложения
  static void appState(String state, [dynamic data]) {
    _logger.i('📱 Состояние: $state', error: data);  // ✅ ИСПРАВЛЕНО
  }

  // База данных / Хранилище
  static void storage(String operation, [dynamic data]) {
    _logger.d('💾 Хранилище: $operation', error: data);  // ✅ ИСПРАВЛЕНО
  }
}