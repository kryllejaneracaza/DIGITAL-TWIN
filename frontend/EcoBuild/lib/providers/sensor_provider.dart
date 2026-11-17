import 'package:flutter/material.dart';

import '../models/sensor_model.dart';
import '../services/sensor_service.dart';

class SensorProvider with ChangeNotifier {
  final SensorService sensorService;

  SensorProvider({required this.sensorService});

  List<SensorModel> _sensors = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SensorModel> get sensors => _sensors;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSensors({String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sensors = await sensorService.getSensors(token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSensorsByRoom(String roomId, {String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sensors = await sensorService.getSensorsByRoom(roomId, token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SensorModel?> fetchLatestReading(
    String sensorId, {
    String? token,
  }) async {
    try {
      final latestReading = await sensorService.getLatestSensorReading(
        sensorId,
        token: token,
      );

      final index = _sensors.indexWhere((sensor) => sensor.id == sensorId);

      if (index != -1) {
        _sensors[index] = latestReading;
      } else {
        _sensors.add(latestReading);
      }

      _errorMessage = null;
      notifyListeners();

      return latestReading;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
