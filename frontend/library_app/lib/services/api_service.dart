import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'storage_service.dart';
import 'logger_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      LoggerService.debug('Токен добавлен в заголовок');
    }
    
    return headers;
  }

  Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    
    try {
      LoggerService.api(method: 'GET', endpoint: endpoint);
      
      final response = await http.get(url, headers: headers);
      
      LoggerService.api(
        method: 'GET',
        endpoint: endpoint,
        statusCode: response.statusCode,
        response: response.statusCode == 200 
          ? 'Success' 
          : response.body.substring(0, response.body.length > 200 ? 200 : response.body.length),
      );
      
      return response;
    } catch (e) {
      LoggerService.error('Ошибка GET запроса: $endpoint', e);
      throw Exception('Ошибка сети: $e');
    }
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    
    try {
      LoggerService.api(
        method: 'POST',
        endpoint: endpoint,
        data: data,
      );
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      
      LoggerService.api(
        method: 'POST',
        endpoint: endpoint,
        statusCode: response.statusCode,
        response: response.statusCode >= 200 && response.statusCode < 300
          ? 'Success'
          : response.body,
      );
      
      return response;
    } catch (e) {
      LoggerService.error('Ошибка POST запроса: $endpoint', e);
      throw Exception('Ошибка сети: $e');
    }
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    
    try {
      LoggerService.api(method: 'PUT', endpoint: endpoint, data: data);
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      
      LoggerService.api(
        method: 'PUT',
        endpoint: endpoint,
        statusCode: response.statusCode,
      );
      
      return response;
    } catch (e) {
      LoggerService.error('Ошибка PUT запроса: $endpoint', e);
      throw Exception('Ошибка сети: $e');
    }
  }

  Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    
    try {
      LoggerService.api(method: 'DELETE', endpoint: endpoint);
      
      final response = await http.delete(url, headers: headers);
      
      LoggerService.api(
        method: 'DELETE',
        endpoint: endpoint,
        statusCode: response.statusCode,
      );
      
      return response;
    } catch (e) {
      LoggerService.error('Ошибка DELETE запроса: $endpoint', e);
      throw Exception('Ошибка сети: $e');
    }
  }

  String handleError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'];
        if (data.containsKey('error')) return data['error'];
        if (data.containsKey('message')) return data['message'];
        
        // Для ошибок валидации Django
        if (data.containsKey('non_field_errors')) {
          return data['non_field_errors'].join(', ');
        }
        
        // Первая ошибка из любого поля
        for (var key in data.keys) {
          if (data[key] is List && data[key].isNotEmpty) {
            return data[key][0];
          }
        }
      }
      
      return 'Произошла ошибка';
    } catch (e) {
      LoggerService.error('Ошибка парсинга ошибки', e);
      return 'Ошибка сервера';
    }
  }
}