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

  factory ChecklistQuestion.fromJson(Map<String, dynamic> json) => ChecklistQuestion(
    id: json['id'] as String,
    order: json['order'] as int,
    fullText: json['fullText'] as String,
    simpleText: json['simpleText'] as String,
    audioText: json['audioText'] as String,
    answerType: AnswerType.values.firstWhere((e) => e.name == json['answerType']),
    isRequired: json['isRequired'] as bool? ?? true,
    requiresPhoto: json['requiresPhoto'] as bool? ?? false,
    photoInstruction: json['photoInstruction'] as String?,
    icon: IconData(json['iconCode'] as int? ?? Icons.help_outline.codePoint, fontFamily: 'MaterialIcons'),
    choices: (json['choices'] as List<dynamic>?)?.cast<String>(),
    conditionalQuestionId: json['conditionalQuestionId'] as String?,
    conditionalValue: json['conditionalValue'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'fullText': fullText,
    'simpleText': simpleText,
    'audioText': audioText,
    'answerType': answerType.name,
    'isRequired': isRequired,
    'requiresPhoto': requiresPhoto,
    'photoInstruction': photoInstruction,
    'iconCode': icon.codePoint,
    'choices': choices,
    'conditionalQuestionId': conditionalQuestionId,
    'conditionalValue': conditionalValue,
  };
}
