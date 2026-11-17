class BuildingModel {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BuildingModel({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    return BuildingModel(
      id: (json['id'] ?? json['_id'] ?? json['buildingId'] ?? '').toString(),
      name: (json['name'] ?? json['buildingName'] ?? 'Unnamed Building')
          .toString(),
      description: json['description']?.toString(),
      address: (json['address'] ?? json['location'])?.toString(),
      status: json['status']?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
