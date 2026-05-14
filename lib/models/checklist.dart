import 'package:flutter/material.dart';
import 'package:morro_do_peo/models/checklist_question.dart';

class Checklist {
  final String id;
  final String areaId;
  final String name;
  final String simpleName;
  final String description;
  final int estimatedMinutes;
  final IconData icon;
  final int version;
  final List<ChecklistQuestion> questions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Checklist({
    required this.id,
    required this.areaId,
    required this.name,
    required this.simpleName,
    required this.description,
    required this.estimatedMinutes,
    required this.icon,
    required this.version,
    required this.questions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Checklist.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Checklist';
    return Checklist(
      id: json['id'] as String,
      areaId: json['areaId'] as String,
      name: name,
      simpleName: json['simpleName'] as String? ?? name,
      description: json['description'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 10,
      icon: _getIconForChecklist(json['id'] as String),
      version: json['version'] as int? ?? 1,
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => ChecklistQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
    );
  }

  static IconData _getIconForChecklist(String id) {
    if (id.contains('pasture')) return Icons.grass;
    if (id.contains('soil')) return Icons.landscape;
    if (id.contains('water')) return Icons.water;
    if (id.contains('feed')) return Icons.restaurant;
    return Icons.checklist;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'areaId': areaId,
    'name': name,
    'simpleName': simpleName,
    'description': description,
    'estimatedMinutes': estimatedMinutes,
    'version': version,
    'iconCode': icon.codePoint,
    'questions': questions.map((q) => q.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
