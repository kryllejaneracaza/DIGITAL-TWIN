import '../models/sensor_model.dart';
import 'api_service.dart';

class SensorService {
  final ApiService apiService;

  SensorService({required this.apiService});

  Future<List<SensorModel>> getSensors({String? token}) async {
    final response = await apiService.get('/sensors', token: token);

    final items = _extractList(response);

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => SensorModel.fromJson(json))
        .toList();
  }

  Future<List<SensorModel>> getSensorsByRoom(
    String roomId, {
    String? token,
  }) async {
    final response = await apiService.get(
      '/rooms/$roomId/sensors',
      token: token,
    );

    final items = _extractList(response);

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => SensorModel.fromJson(json))
        .toList();
  }

  Future<SensorModel> getSensorById(String id, {String? token}) async {
    final response = await apiService.get('/sensors/$id', token: token);

    return SensorModel.fromJson(_extractObject(response));
  }

  Future<SensorModel> getLatestSensorReading(String id, {String? token}) async {
    final response = await apiService.get('/sensors/$id/latest', token: token);

    return SensorModel.fromJson(_extractObject(response));
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;

    if (response is Map) {
      final data = response['data'] ?? response['sensors'];

      if (data is List) return data;
    }

    throw const FormatException(
      'The sensors response is not in the expected list format.',
    );
  }

  Map<String, dynamic> _extractObject(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response['sensor'];

      if (data is Map<String, dynamic>) return data;
      return response;
    }

    throw const FormatException(
      'The sensor response is not in the expected object format.',
    );
  }
}
