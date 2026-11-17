import '../models/appliance_model.dart';
import 'api_service.dart';

class ApplianceService {
  final ApiService apiService;

  ApplianceService({required this.apiService});

  Future<List<ApplianceModel>> getAppliances({String? token}) async {
    final response = await apiService.get('/appliances', token: token);

    final items = _extractList(response);

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => ApplianceModel.fromJson(json))
        .toList();
  }

  Future<List<ApplianceModel>> getAppliancesByRoom(
    String roomId, {
    String? token,
  }) async {
    final response = await apiService.get(
      '/rooms/$roomId/appliances',
      token: token,
    );

    final items = _extractList(response);

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => ApplianceModel.fromJson(json))
        .toList();
  }

  Future<ApplianceModel> getApplianceById(String id, {String? token}) async {
    final response = await apiService.get('/appliances/$id', token: token);

    return ApplianceModel.fromJson(_extractObject(response));
  }

  Future<ApplianceModel> setAppliancePower(
    String id,
    bool isOn, {
    String? token,
  }) async {
    final response = await apiService.put(
      '/appliances/$id',
      body: {'isOn': isOn},
      token: token,
    );

    return ApplianceModel.fromJson(_extractObject(response));
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;

    if (response is Map) {
      final data = response['data'] ?? response['appliances'];

      if (data is List) return data;
    }

    throw const FormatException(
      'The appliances response is not in the expected list format.',
    );
  }

  Map<String, dynamic> _extractObject(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response['appliance'];

      if (data is Map<String, dynamic>) return data;
      return response;
    }

    throw const FormatException(
      'The appliance response is not in the expected object format.',
    );
  }
}
