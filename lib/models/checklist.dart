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
    required this.questions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Checklist.fromJson(Map<String, dynamic> json) => Checklist(
    id: json['id'] as String,
    areaId: json['areaId'] as String,
    name: json['name'] as String,
    simpleName: json['simpleName'] as String,
    description: json['description'] as String,
    estimatedMinutes: json['estimatedMinutes'] as int,
    icon: IconData(json['iconCode'] as int? ?? Icons.checklist.codePoint, fontFamily: 'MaterialIcons'),
    questions: (json['questions'] as List<dynamic>)
        .map((q) => ChecklistQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'areaId': areaId,
    'name': name,
    'simpleName': simpleName,
    'description': description,
    'estimatedMinutes': estimatedMinutes,
    'iconCode': icon.codePoint,
    'questions': questions.map((q) => q.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
