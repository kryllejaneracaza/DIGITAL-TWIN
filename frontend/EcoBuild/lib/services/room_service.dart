import '../models/room_model.dart';
import 'api_service.dart';

class RoomService {
  final ApiService apiService;

  RoomService({required this.apiService});

  Future<List<RoomModel>> getRooms({String? token}) async {
    final response = await apiService.get('/rooms', token: token);

    final items = _extractList(response);

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => RoomModel.fromJson(json))
        .toList();
  }

  Future<List<RoomModel>> getRoomsByBuilding(
    String buildingId, {
    String? token,
  }) async {
    final response = await apiService.get(
      '/buildings/$buildingId/rooms',
      token: token,
    );

    final items = _extractList(response);

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => RoomModel.fromJson(json))
        .toList();
  }

  Future<RoomModel> getRoomById(String id, {String? token}) async {
    final response = await apiService.get('/rooms/$id', token: token);

    return RoomModel.fromJson(_extractObject(response));
  }

  Future<RoomModel> createRoom(RoomModel room, {String? token}) async {
    final response = await apiService.post(
      '/rooms',
      body: room.toJson(),
      token: token,
    );

    return RoomModel.fromJson(_extractObject(response));
  }

  Future<RoomModel> updateRoom(
    String id,
    RoomModel room, {
    String? token,
  }) async {
    final response = await apiService.put(
      '/rooms/$id',
      body: room.toJson(),
      token: token,
    );

    return RoomModel.fromJson(_extractObject(response));
  }

  Future<void> deleteRoom(String id, {String? token}) async {
    await apiService.delete('/rooms/$id', token: token);
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;

    if (response is Map) {
      final data = response['data'] ?? response['rooms'];

      if (data is List) return data;
    }

    throw const FormatException(
      'The rooms response is not in the expected list format.',
    );
  }

  Map<String, dynamic> _extractObject(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response['room'];

      if (data is Map<String, dynamic>) return data;
      return response;
    }

    throw const FormatException(
      'The room response is not in the expected object format.',
    );
  }
}
