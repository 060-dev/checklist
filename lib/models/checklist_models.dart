import 'package:flutter/material.dart';

enum OperationalResponsible {
  tratador,
  vaqueiro,
  outro,
}

extension OperationalResponsibleX on OperationalResponsible {
  String get label => switch (this) {
        OperationalResponsible.tratador => 'Tratador',
        OperationalResponsible.vaqueiro => 'Vaqueiro',
        OperationalResponsible.outro => 'Outro',
      };

  String get id => switch (this) {
        OperationalResponsible.tratador => 'tratador',
        OperationalResponsible.vaqueiro => 'vaqueiro',
        OperationalResponsible.outro => 'outro',
      };

  static OperationalResponsible? fromId(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    return switch (v) {
      'tratador' => OperationalResponsible.tratador,
      'vaqueiro' => OperationalResponsible.vaqueiro,
      'outro' => OperationalResponsible.outro,
      _ => null,
    };
  }
}

enum ChecklistAnswerType { simNao, simNaoOk, simNaoComNivel }

enum AdditionalFieldInputType { textOrAudio }

@immutable
class ChecklistDisplayWhen {
  final String questionId;
  final String answer;

  const ChecklistDisplayWhen({required this.questionId, required this.answer});
}

@immutable
class OperationalAreaDefinition {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const OperationalAreaDefinition(
      {required this.id,
      required this.title,
      required this.description,
      required this.icon});
}

class OperationalAreasRepository {
  static const String agriculturaId = 'area_agricultura';
  static const String pecuariaId = 'area_pecuaria';

  static const List<OperationalAreaDefinition> available = [
    OperationalAreaDefinition(
      id: agriculturaId,
      title: 'Agricultura',
      description:
          'Checklists de solo, plantio, dessecação, colheita e tratos culturais',
      icon: Icons.agriculture_rounded,
    ),
    OperationalAreaDefinition(
      id: pecuariaId,
      title: 'Pecuária',
      description: 'Checklists de curral, confinamento, boia, bosta e boi',
      icon: Icons.pets_rounded,
    ),
  ];
}

@immutable
class PenDefinition {
  final String id;
  final String name;

  const PenDefinition({required this.id, required this.name});
}

enum PenChecklistStatus { pendente, parcial, preenchido, comAlerta }

/// Status simples de um checklist “geral” no dia (não associado a curral).
enum ChecklistDayStatus { pendente, preenchido, comAlerta }

class PensRepository {
  static const List<PenDefinition> available = [
    PenDefinition(id: 'curral_01', name: 'Curral 1'),
    PenDefinition(id: 'curral_02', name: 'Curral 2'),
    PenDefinition(id: 'curral_03', name: 'Curral 3'),
    PenDefinition(id: 'curral_04', name: 'Curral 4'),
    PenDefinition(id: 'curral_05', name: 'Curral 5'),
    PenDefinition(id: 'curral_06', name: 'Curral 6'),
    PenDefinition(id: 'curral_07', name: 'Curral 7'),
    PenDefinition(id: 'curral_08', name: 'Curral 8'),
    PenDefinition(id: 'curral_09', name: 'Curral 9'),
    PenDefinition(id: 'curral_10', name: 'Curral 10'),
    PenDefinition(id: 'curral_11', name: 'Curral 11'),
    PenDefinition(id: 'curral_12', name: 'Curral 12'),
  ];
}

@immutable
class ChecklistInterstitialDefinition {
  /// Optional id used to dedupe interstitials in a single run.
  final String? id;

  /// If the answer matches [whenAnswer], an interstitial sheet is shown
  /// before continuing to the next question.
  final String whenAnswer;
  final String message;
  final String buttonLabel;

  const ChecklistInterstitialDefinition(
      {this.id,
      required this.whenAnswer,
      required this.message,
      required this.buttonLabel});
}

@immutable
class ChecklistLevelOption {
  final String label;
  final Object value;

  const ChecklistLevelOption({required this.label, required this.value});
}

@immutable
class ChecklistLevelDefinition {
  final String label;
  final bool required;

  /// When null, the level is requested for any answer.
  final String? requiredWhenAnswer;
  final List<ChecklistLevelOption> options;

  const ChecklistLevelDefinition(
      {required this.label,
      required this.required,
      this.requiredWhenAnswer,
      required this.options});
}

@immutable
class ChecklistAdditionalFieldDefinition {
  final String id;
  final String label;
  final AdditionalFieldInputType inputType;
  final String requiredWhenAnswer; // ex.: 'sim'
  final String placeholder;

  const ChecklistAdditionalFieldDefinition({
    required this.id,
    required this.label,
    required this.inputType,
    required this.requiredWhenAnswer,
    required this.placeholder,
  });
}

@immutable
class ChecklistPhotoRequestDefinition {
  final String label;
  final String instruction;
  final String requiredWhenAnswer; // ex.: 'sim'
  /// Optional local filename to be used when photo capture is mocked.
  /// If null, the UI will use a generic fallback name.
  final String? mockLocalFile;

  const ChecklistPhotoRequestDefinition({
    required this.label,
    required this.instruction,
    required this.requiredWhenAnswer,
    this.mockLocalFile,
  });
}

@immutable
class ChecklistQuestion {
  final String id;

  /// Optional stage label shown above the question (ex.: "Etapa 1").
  final String? stage;

  /// Optional block label shown above the question (ex.: "BOIA / Cocho").
  final String? block;
  final String text;
  final String audioText;
  final ChecklistAnswerType answerType;
  final List<String> options; // ex.: ['sim', 'nao', 'ok']
  final bool required;

  /// Optional conditional display rule.
  /// If set, this question is shown only when the referenced question
  /// was answered with [ChecklistDisplayWhen.answer].
  final ChecklistDisplayWhen? displayWhen;

  /// Optional rule that shows this question when ANY condition matches.
  /// (useful for "exibirQuandoQualquer").
  final List<ChecklistDisplayWhen> displayWhenAny;
  final String? alertWhenAnswer;
  final String? alertMessage;

  /// Optional interstitial step shown after answering this question.
  final ChecklistInterstitialDefinition? interstitial;
  final ChecklistAdditionalFieldDefinition? additionalField;
  final ChecklistLevelDefinition? level;
  final ChecklistPhotoRequestDefinition? photoRequest;

  const ChecklistQuestion({
    required this.id,
    this.stage,
    this.block,
    required this.text,
    required this.audioText,
    required this.answerType,
    required this.options,
    required this.required,
    this.displayWhen,
    this.displayWhenAny = const [],
    this.alertWhenAnswer,
    this.alertMessage,
    this.interstitial,
    this.additionalField,
    this.level,
    this.photoRequest,
  });
}

@immutable
class ChecklistDefinition {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String areaId;
  final bool appliesPerPen;

  /// Who is operationally responsible for executing this checklist.
  ///
  /// Used mainly to organize per-pen checklists by routine.
  final OperationalResponsible? responsible;

  /// Optional periodicity label used in payloads (ex.: 'diaria', 'semanal').
  final String? periodicity;
  final List<ChecklistQuestion> questions;

  const ChecklistDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.areaId,
    this.appliesPerPen = false,
    this.responsible,
    this.periodicity,
    required this.questions,
  });
}
