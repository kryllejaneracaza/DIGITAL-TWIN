class SensorModel {
  final String id;
  final String roomId;
  final String buildingId;
  final String name;
  final String type;
  final dynamic reading;
  final String? unit;
  final String? status;
  final DateTime? lastUpdated;

  SensorModel({
    required this.id,
    required this.roomId,
    required this.buildingId,
    required this.name,
    required this.type,
    this.reading,
    this.unit,
    this.status,
    this.lastUpdated,
  });

  factory SensorModel.fromJson(Map<String, dynamic> json) {
    return SensorModel(
      id: (json['id'] ?? json['_id'] ?? json['sensorId'] ?? '').toString(),
      roomId: (json['roomId'] ?? json['room_id'] ?? '').toString(),
      buildingId: (json['buildingId'] ?? json['building_id'] ?? '').toString(),
      name: (json['name'] ?? json['sensorName'] ?? 'Unnamed Sensor').toString(),
      type: (json['type'] ?? json['sensorType'] ?? 'Unknown').toString(),
      reading: json['reading'] ?? json['value'] ?? json['currentValue'],
      unit: (json['unit'] ?? json['measurementUnit'])?.toString(),
      status: json['status']?.toString(),
      lastUpdated: _parseDate(
        json['lastUpdated'] ?? json['last_updated'] ?? json['timestamp'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'buildingId': buildingId,
      'name': name,
      'type': type,
      'reading': reading,
      'unit': unit,
      'status': status,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  double? get numericReading {
    if (reading is num) return (reading as num).toDouble();
    return double.tryParse(reading?.toString() ?? '');
  }

  bool? get occupancyDetected {
    if (reading is bool) return reading as bool;

    final value = reading?.toString().toLowerCase();

    if (value == 'true' || value == 'occupied') return true;
    if (value == 'false' || value == 'unoccupied') return false;

    return null;
  }
}
