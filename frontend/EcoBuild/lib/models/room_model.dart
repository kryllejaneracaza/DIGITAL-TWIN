class RoomModel {
  final String id;
  final String buildingId;
  final String name;
  final int? floor;
  final String? description;
  final String? status;

  RoomModel({
    required this.id,
    required this.buildingId,
    required this.name,
    this.floor,
    this.description,
    this.status,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: (json['id'] ?? json['_id'] ?? json['roomId'] ?? '').toString(),
      buildingId: (json['buildingId'] ?? json['building_id'] ?? '').toString(),
      name: (json['name'] ?? json['roomName'] ?? 'Unnamed Room').toString(),
      floor: _parseInt(json['floor'] ?? json['floorNumber']),
      description: json['description']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buildingId': buildingId,
      'name': name,
      'floor': floor,
      'description': description,
      'status': status,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
