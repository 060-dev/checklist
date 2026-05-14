import 'package:flutter/foundation.dart';

@immutable
class Operator {
  final String id;
  final String farmId;
  final String name;
  final bool active;

  const Operator({required this.id, required this.farmId, required this.name, required this.active});

  factory Operator.fromJson(Map<String, dynamic> json) => Operator(
    id: (json['id'] as String?) ?? (json['_id'] as String?) ?? '',
    farmId: (json['farmId'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    active: (json['active'] as bool?) ?? true,
  );
}
