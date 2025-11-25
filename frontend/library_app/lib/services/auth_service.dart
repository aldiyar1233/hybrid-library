import 'dart:convert';
import '../models/user.dart';
import '../config/constants.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String password2,
    String? phone,
    String? firstName,
    String? lastName,
  }) async {
    final data = {
      'username': username,
      'email': email,
      'password': password,
      'password2': password2,
      if (phone != null) 'phone': phone,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    };

    try {
      final response = await _api.post(AppConstants.registerEndpoint, data);

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final user = User.fromJson(responseData['user']);
        final tokens = responseData['tokens'];

        await _storage.saveToken(tokens['access']);
        await _storage.saveRefreshToken(tokens['refresh']);
        await _storage.saveUser(user);

        return {'success': true, 'user': user};
      } else {
        final error = _api.handleError(response);
        return {'success': false, 'error': error};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка регистрации: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final data = {
      'username': username,
      'password': password,
    };

    try {
      final response = await _api.post(AppConstants.loginEndpoint, data);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final user = User.fromJson(responseData['user']);
        final tokens = responseData['tokens'];

        await _storage.saveToken(tokens['access']);
        await _storage.saveRefreshToken(tokens['refresh']);
        await _storage.saveUser(user);

        print('✅ Токен сохранен: ${tokens['access'].substring(0, 30)}...');

        return {'success': true, 'user': user};
      } else {
        final error = _api.handleError(response);
        return {'success': false, 'error': error};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка входа: $e'};
    }
  }

  Future<User?> getCurrentUser() async {
    return await _storage.getUser();
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }
}