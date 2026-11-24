class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://100.100.73.108:1880';

  static const Duration connectionTimeout = Duration(seconds: 15);

  static const Duration receiveTimeout = Duration(seconds: 15);
}
