import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  final ApiService _apiService;
  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'ecobuild_auth_token';

  AuthService({required ApiService apiService, FlutterSecureStorage? storage})
    : _apiService = apiService,
      _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiService.post(
      '/api/login',
      body: {'email': email.trim(), 'password': password},
    );

    if (response is! Map || response['token'] == null) {
      throw ApiException(message: 'Invalid login response from server.');
    }

    final token = response['token'].toString();

    await _storage.write(key: _tokenKey, value: token);

    return Map<String, dynamic>.from(response['user'] as Map);
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _apiService.post(
      '/api/signup',
      body: {'name': name.trim(), 'email': email.trim(), 'password': password},
    );

    return login(email, password);
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await _storage.read(key: _tokenKey);

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _apiService.get('/api/me', token: token);

      if (response is! Map || response['user'] is! Map) {
        throw ApiException(message: 'Invalid user response from server.');
      }

      return Map<String, dynamic>.from(response['user'] as Map);
    } catch (e) {
      await _storage.delete(key: _tokenKey);
      rethrow;
    }
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> logout() async {
    final token = await _storage.read(key: _tokenKey);

    try {
      if (token != null && token.isNotEmpty) {
        await _apiService.post('/api/logout', token: token);
      }
    } finally {
      await _storage.delete(key: _tokenKey);
    }
  }
}
