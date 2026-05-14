import 'package:flutter/material.dart';

enum AnswerType {
  yesNo,
  photo,
  number,
  choice,
  audioNote,
}

class ChecklistQuestion {
  final String id;
  final int order;
  final String fullText;
  final String simpleText;
  final String audioText;
  final AnswerType answerType;
  final bool isRequired;
  final bool requiresPhoto;
  final String? photoInstruction;
  final IconData icon;
  final List<String>? choices;
  final String? conditionalQuestionId;
  final String? conditionalValue;

  const ChecklistQuestion({
    required this.id,
    required this.order,
    required this.fullText,
    required this.simpleText,
    required this.audioText,
    required this.answerType,
    this.isRequired = true,
    this.requiresPhoto = false,
    this.photoInstruction,
    this.icon = Icons.help_outline,
    this.choices,
    this.conditionalQuestionId,
    this.conditionalValue,
  });

  factory ChecklistQuestion.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'yes_no';
    final answerType = _mapBackendTypeToEnum(type);
    final text = json['text'] as String? ?? '';

    return ChecklistQuestion(
      id: json['id'] as String,
      order: json['order'] as int? ?? 0,
      fullText: text,
      simpleText: text,
      audioText: text,
      answerType: answerType,
      isRequired: json['isRequired'] as bool? ?? true,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      photoInstruction: json['photoInstruction'] as String?,
      icon: _getIconForQuestion(json['id'] as String, answerType),
      choices: (json['choices'] as List<dynamic>?)?.cast<String>(),
      conditionalQuestionId: json['conditionalQuestionId'] as String?,
      conditionalValue: json['conditionalValue'] as String?,
    );
  }

  static AnswerType _mapBackendTypeToEnum(String type) {
    switch (type) {
      case 'yes_no': return AnswerType.yesNo;
      case 'photo': return AnswerType.photo;
      case 'number': return AnswerType.number;
      case 'choice': return AnswerType.choice;
      case 'audio_note': return AnswerType.audioNote;
      default: return AnswerType.yesNo;
    }
  }

  static String _mapEnumToBackendType(AnswerType type) {
    switch (type) {
      case AnswerType.yesNo: return 'yes_no';
      case AnswerType.photo: return 'photo';
      case AnswerType.number: return 'number';
      case AnswerType.choice: return 'choice';
      case AnswerType.audioNote: return 'audio_note';
    }
  }

  static IconData _getIconForQuestion(String id, AnswerType type) {
    if (id.contains('water')) return Icons.water_drop;
    if (id.contains('soil')) return Icons.landscape;
    if (id.contains('tire')) return Icons.tire_repair;
    
    switch (type) {
      case AnswerType.yesNo: return Icons.check_circle_outline;
      case AnswerType.photo: return Icons.camera_alt;
      case AnswerType.audioNote: return Icons.mic;
      case AnswerType.number: return Icons.numbers;
      default: return Icons.help_outline;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'text': fullText,
    'type': _mapEnumToBackendType(answerType),
    'isRequired': isRequired,
    'requiresPhoto': requiresPhoto,
    'photoInstruction': photoInstruction,
    'choices': choices,
    'conditionalQuestionId': conditionalQuestionId,
    'conditionalValue': conditionalValue,
  };
}
