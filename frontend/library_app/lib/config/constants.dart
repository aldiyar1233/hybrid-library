import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  // ✅ ИСПРАВЛЕНО: убрали /api из baseUrl
  static String get baseUrl {
    if (kIsWeb) {
      // Web (Chrome) - используем localhost
      return 'http://localhost:8000';  // БЕЗ /api
    } else if (Platform.isAndroid) {
      // Android - используем IP компьютера
      return 'http://192.168.0.106:8000';  // БЕЗ /api
    } else if (Platform.isIOS) {
      // iOS - используем IP компьютера  
      return 'http://192.168.0.106:8000';  // БЕЗ /api
    } else {
      return 'http://localhost:8000';  // БЕЗ /api
    }
  }
  
  // Endpoints - уже содержат /api/
  static const String registerEndpoint = '/api/auth/register/';
  static const String loginEndpoint = '/api/auth/login/';
  static const String profileEndpoint = '/api/auth/profile/';
  static const String booksEndpoint = '/api/books/';
  static const String genresEndpoint = '/api/genres/';
  static const String reservationsEndpoint = '/api/reservations/';
  
  // Storage Keys
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  
  // App Info
  static const String appName = 'Гибридная Библиотека';
  static const String appVersion = '1.0.0';
}