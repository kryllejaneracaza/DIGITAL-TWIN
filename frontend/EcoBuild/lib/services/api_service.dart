import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUri(String endpoint, {Map<String, String>? queryParameters}) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;

    final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;

    return Uri.parse('$base/$path').replace(queryParameters: queryParameters);
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body;

    dynamic data;

    if (body.isNotEmpty) {
      try {
        data = jsonDecode(body);
      } catch (_) {
        data = body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(
      message: data is Map
          ? (data['message'] ?? data['error'] ?? 'Request failed').toString()
          : 'Request failed: $data',
      statusCode: response.statusCode,
    );
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    String? token,
  }) async {
    try {
      final response = await _client
          .get(
            _buildUri(endpoint, queryParameters: queryParameters),
            headers: _headers(token: token),
          )
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;

      throw ApiException(message: 'GET request failed: $e');
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await _client
          .post(
            _buildUri(endpoint),
            headers: _headers(token: token),
            body: jsonEncode(body ?? {}),
          )
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;

      throw ApiException(message: 'POST request failed: $e');
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await _client
          .put(
            _buildUri(endpoint),
            headers: _headers(token: token),
            body: jsonEncode(body ?? {}),
          )
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;

      throw ApiException(message: 'PUT request failed: $e');
    }
  }

  Future<dynamic> delete(String endpoint, {String? token}) async {
    try {
      final response = await _client
          .delete(_buildUri(endpoint), headers: _headers(token: token))
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;

      throw ApiException(message: 'DELETE request failed: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() {
    return 'ApiException: $message '
        '${statusCode != null ? '(Status: $statusCode)' : ''}';
  }
}
