import 'package:flutter/material.dart';

import '../models/room_model.dart';
import '../services/room_service.dart';

class RoomProvider with ChangeNotifier {
  final RoomService roomService;

  RoomProvider({required this.roomService});

  List<RoomModel> _rooms = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RoomModel> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // FETCH ROOMS FROM ALL BUILDINGS
  Future<void> fetchAllRooms({String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rooms = await roomService.getRooms(token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // FETCH ROOMS FROM A SPECIFIC BUILDING
  Future<void> fetchRoomsByBuilding(String buildingId, {String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rooms = await roomService.getRoomsByBuilding(buildingId, token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ADD ROOM
  Future<bool> addRoom(RoomModel room, {String? token}) async {
    try {
      final newRoom = await roomService.createRoom(room, token: token);

      _rooms.add(newRoom);
      _errorMessage = null;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // UPDATE ROOM
  Future<bool> editRoom(String id, RoomModel room, {String? token}) async {
    try {
      final updatedRoom = await roomService.updateRoom(id, room, token: token);

      final index = _rooms.indexWhere((item) => item.id == id);

      if (index != -1) {
        _rooms[index] = updatedRoom;
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // DELETE ROOM
  Future<bool> removeRoom(String id, {String? token}) async {
    try {
      await roomService.deleteRoom(id, token: token);

      _rooms.removeWhere((room) => room.id == id);

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // CLEAR ERROR
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // CLEAR ROOMS
  void clearRooms() {
    _rooms = [];
    _errorMessage = null;
    notifyListeners();
  }
}
