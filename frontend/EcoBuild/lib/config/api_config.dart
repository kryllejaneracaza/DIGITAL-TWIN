class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:1880',
  );

  static const Duration connectionTimeout = Duration(seconds: 15);

  static const Duration receiveTimeout = Duration(seconds: 15);
}
