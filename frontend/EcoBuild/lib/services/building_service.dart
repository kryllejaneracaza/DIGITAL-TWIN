
import '../models/building_model.dart';
import 'api_service.dart';

class BuildingService {
  final ApiService apiService;

  BuildingService({required this.apiService});

  Future<List<BuildingModel>> getBuildings({String? token}) async {
    final response = await apiService.get('/api/buildings', token: token);

    final List<dynamic> items = _extractList(response);

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => BuildingModel.fromJson(json))
        .toList();
  }

  Future<BuildingModel> getBuildingById(String id, {String? token}) async {
    final response =
        await apiService.get('/api/buildings/$id', token: token);

    return BuildingModel.fromJson(_extractObject(response));
  }

  Future<BuildingModel> createBuilding(
    BuildingModel building, {
    String? token,
  }) async {
    final response = await apiService.post(
      '/api/buildings',
      body: building.toJson(),
      token: token,
    );

    return BuildingModel.fromJson(_extractObject(response));
  }

  Future<BuildingModel> updateBuilding(
    String id,
    BuildingModel building, {
    String? token,
  }) async {
    final response = await apiService.put(
      '/api/buildings/$id',
      body: building.toJson(),
      token: token,
    );

    return BuildingModel.fromJson(_extractObject(response));
  }

  Future<void> deleteBuilding(String id, {String? token}) async {
    await apiService.delete('/api/buildings/$id', token: token);
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;

    if (response is Map) {
      final data = response['data'] ?? response['buildings'];

      if (data is List) return data;
    }

    throw const FormatException(
      'The buildings response is not in the expected list format.',
    );
  }

  Map<String, dynamic> _extractObject(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response['building'];

      if (data is Map<String, dynamic>) return data;
      return response;
    }

    throw const FormatException(
      'The building response is not in the expected object format.',
    );
  }
}
