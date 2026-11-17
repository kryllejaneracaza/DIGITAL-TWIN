class ApplianceModel {
  final String id;
  final String roomId;
  final String buildingId;
  final String name;
  final String type;
  final bool isOn;
  final double? powerUsage;
  final String? status;

  ApplianceModel({
    required this.id,
    required this.roomId,
    required this.buildingId,
    required this.name,
    required this.type,
    required this.isOn,
    this.powerUsage,
    this.status,
  });

  factory ApplianceModel.fromJson(Map<String, dynamic> json) {
    return ApplianceModel(
      id: (json['id'] ?? json['_id'] ?? json['applianceId'] ?? '').toString(),
      roomId: (json['roomId'] ?? json['room_id'] ?? '').toString(),
      buildingId: (json['buildingId'] ?? json['building_id'] ?? '').toString(),
      name: (json['name'] ?? json['applianceName'] ?? 'Unnamed Appliance')
          .toString(),
      type: (json['type'] ?? json['applianceType'] ?? 'Unknown').toString(),
      isOn: _parseBool(
        json['isOn'] ?? json['is_on'] ?? json['power'] ?? json['status'],
      ),
      powerUsage: _parseDouble(
        json['powerUsage'] ?? json['power_usage'] ?? json['powerConsumption'],
      ),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'buildingId': buildingId,
      'name': name,
      'type': type,
      'isOn': isOn,
      'powerUsage': powerUsage,
      'status': status,
    };
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase();

    return text == 'true' || text == 'on' || text == '1' || text == 'active';
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
