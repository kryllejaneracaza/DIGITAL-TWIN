import 'package:flutter/material.dart';

import '../models/building_model.dart';
import '../services/building_service.dart';

class BuildingProvider with ChangeNotifier {
  final BuildingService buildingService;

  BuildingProvider({required this.buildingService});

  List<BuildingModel> _buildings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<BuildingModel> get buildings => _buildings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchBuildings({String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _buildings = await buildingService.getBuildings(token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addBuilding(BuildingModel building, {String? token}) async {
    try {
      final newBuilding = await buildingService.createBuilding(
        building,
        token: token,
      );

      _buildings.add(newBuilding);
      _errorMessage = null;
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editBuilding(
    String id,
    BuildingModel building, {
    String? token,
  }) async {
    try {
      final updatedBuilding = await buildingService.updateBuilding(
        id,
        building,
        token: token,
      );

      final index = _buildings.indexWhere((item) => item.id == id);

      if (index != -1) {
        _buildings[index] = updatedBuilding;
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

  Future<bool> removeBuilding(String id, {String? token}) async {
    try {
      await buildingService.deleteBuilding(id, token: token);

      _buildings.removeWhere((item) => item.id == id);

      _errorMessage = null;
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
