enum UserRole { operator, manager }

class FarmUser {
  final String id;
  final String name;
  final UserRole role;
  final String farmId;
  final String farmName;
  final DateTime createdAt;
  final DateTime updatedAt;

  FarmUser({
    required this.id,
    required this.name,
    required this.role,
    required this.farmId,
    required this.farmName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FarmUser.fromJson(Map<String, dynamic> json) => FarmUser(
    id: json['id'] as String,
    name: json['name'] as String,
    role: UserRole.values.firstWhere((e) => e.name == json['role']),
    farmId: json['farmId'] as String,
    farmName: json['farmName'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'farmId': farmId,
    'farmName': farmName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  FarmUser copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? farmId,
    String? farmName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FarmUser(
    id: id ?? this.id,
    name: name ?? this.name,
    role: role ?? this.role,
    farmId: farmId ?? this.farmId,
    farmName: farmName ?? this.farmName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
