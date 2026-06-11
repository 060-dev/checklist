import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:morro_do_peo/data/checklists_repository.dart';
import 'package:morro_do_peo/models/checklist_models.dart';
import 'package:morro_do_peo/models/operator.dart';

@immutable
class AudioMock {
  final String localFile;
  final int durationSeconds;
  final String? transcriptionMock;

  const AudioMock(
      {required this.localFile,
      required this.durationSeconds,
      this.transcriptionMock});

  Map<String, dynamic> toJson() => {
        'tipo': 'audio',
        'arquivoLocal': localFile,
        'duracaoSegundos': durationSeconds,
        if (transcriptionMock != null) 'transcricaoMock': transcriptionMock,
      };
}

@immutable
class PhotoMock {
  final bool captured;
  final String localFile;

  const PhotoMock({required this.captured, required this.localFile});

  Map<String, dynamic> toJson() => {
        'capturada': captured,
        'arquivoLocal': localFile,
      };
}

@immutable
class AdditionalFieldValue {
  final String type; // 'texto' | 'audio'
  final String? text;
  final AudioMock? audio;

  const AdditionalFieldValue._({required this.type, this.text, this.audio});

  const AdditionalFieldValue.text(String value)
      : this._(type: 'texto', text: value, audio: null);

  const AdditionalFieldValue.audio(AudioMock value)
      : this._(type: 'audio', text: null, audio: value);

  Map<String, dynamic> toJson() {
    if (type == 'audio') return audio!.toJson();
    return {'tipo': 'texto', 'valor': text};
  }
}

@immutable
class ChecklistResponse {
  final String answer;
  final ChecklistLevelOption? level;
  final bool generatedAlert;
  final Map<String, AdditionalFieldValue> additionalFields;
  final PhotoMock? photo;

  const ChecklistResponse(
      {required this.answer,
      this.level,
      this.generatedAlert = false,
      this.additionalFields = const {},
      this.photo});

  ChecklistResponse copyWith({
    String? answer,
    ChecklistLevelOption? level,
    bool? generatedAlert,
    Map<String, AdditionalFieldValue>? additionalFields,
    PhotoMock? photo,
  }) =>
      ChecklistResponse(
        answer: answer ?? this.answer,
        level: level ?? this.level,
        generatedAlert: generatedAlert ?? this.generatedAlert,
        additionalFields: additionalFields ?? this.additionalFields,
        photo: photo ?? this.photo,
      );
}

@immutable
class ObservationAudioMock {
  final bool recorded;
  final String localFile;
  final int durationSeconds;

  const ObservationAudioMock(
      {required this.recorded,
      required this.localFile,
      required this.durationSeconds});

  Map<String, dynamic> toJson() => {
        'gravado': recorded,
        'arquivoLocal': localFile,
        'duracaoSegundos': durationSeconds,
      };
}

class AppSession extends ChangeNotifier {
  Operator? _selectedOperator;
  OperationalAreaDefinition? _selectedArea;
  PenDefinition? _selectedPen;
  ChecklistDefinition? _selectedChecklist;
  OperationalResponsible? _operationalResponsible;

  DateTime? _startedAt;
  DateTime? _finishedAt;

  final Map<String, ChecklistResponse> _responsesByQuestionId = {};
  ObservationAudioMock? _observation;

  /// Status por curral (penId) e por checklist (checklistId) para o dia atual.
  final Map<String, Map<String, PenChecklistStatus>>
      _penChecklistStatusByPenIdToday = {};

  /// Status dos checklists gerais da Pecuária (por checklistId) para o dia atual.
  final Map<String, ChecklistDayStatus> _generalPecuariaChecklistStatusToday =
      {};
  final Set<String> _shownInterstitialIds = {};

  String? _successTitleOverride;
  String? _successMessageOverride;
  String _successReturnLocation = '/areas';
  String _successReturnLabel = 'Voltar';

  Operator? get selectedOperator => _selectedOperator;
  OperationalAreaDefinition? get selectedArea => _selectedArea;
  PenDefinition? get selectedPen => _selectedPen;
  ChecklistDefinition? get selectedChecklist => _selectedChecklist;
  OperationalResponsible? get operationalResponsible => _operationalResponsible;
  DateTime? get startedAt => _startedAt;
  DateTime? get finishedAt => _finishedAt;

  Map<String, ChecklistResponse> get responsesByQuestionId =>
      Map.unmodifiable(_responsesByQuestionId);
  ObservationAudioMock? get observation => _observation;

  String? get successTitleOverride => _successTitleOverride;
  String? get successMessageOverride => _successMessageOverride;
  String get successReturnLocation => _successReturnLocation;
  String get successReturnLabel => _successReturnLabel;

  String? answerFor(String questionId) =>
      _responsesByQuestionId[questionId]?.answer;

  void selectOperator(Operator op) {
    _selectedOperator = op;
    _operationalResponsible = null;
    notifyListeners();
  }

  void selectOperationalArea(OperationalAreaDefinition area) {
    _selectedArea = area;
    _selectedPen = null;
    notifyListeners();
  }

  void selectPen(PenDefinition pen) {
    _selectedPen = pen;
    notifyListeners();
  }

  void setOperationalResponsible(OperationalResponsible? value) {
    _operationalResponsible = value;
    notifyListeners();
  }

  void startChecklist(ChecklistDefinition checklist) {
    _selectedChecklist = checklist;
    _startedAt = DateTime.now();
    _finishedAt = null;
    _responsesByQuestionId.clear();
    _observation = null;
    _shownInterstitialIds.clear();
    notifyListeners();
  }

  void saveAnswer({required String questionId, required String answer}) {
    final current = _responsesByQuestionId[questionId];
    _responsesByQuestionId[questionId] =
        (current ?? ChecklistResponse(answer: answer)).copyWith(answer: answer);
    notifyListeners();
  }

  void setLevel(
      {required String questionId, required ChecklistLevelOption level}) {
    final current = _responsesByQuestionId[questionId];
    if (current == null) return;
    _responsesByQuestionId[questionId] = current.copyWith(level: level);
    notifyListeners();
  }

  void markAlert({required String questionId, required bool generated}) {
    final current = _responsesByQuestionId[questionId];
    if (current == null) return;
    _responsesByQuestionId[questionId] =
        current.copyWith(generatedAlert: generated);
    notifyListeners();
  }

  void removeResponse(String questionId) {
    if (_responsesByQuestionId.remove(questionId) != null) notifyListeners();
  }

  void removeResponses(Iterable<String> questionIds) {
    var changed = false;
    for (final id in questionIds) {
      changed = _responsesByQuestionId.remove(id) != null || changed;
    }
    if (changed) notifyListeners();
  }

  void setAdditionalField(
      {required String questionId,
      required String fieldId,
      required AdditionalFieldValue value}) {
    final current = _responsesByQuestionId[questionId];
    if (current == null) return;
    final next =
        Map<String, AdditionalFieldValue>.from(current.additionalFields);
    next[fieldId] = value;
    _responsesByQuestionId[questionId] =
        current.copyWith(additionalFields: next);
    notifyListeners();
  }

  void setPhotoMock({required String questionId, required PhotoMock photo}) {
    final current = _responsesByQuestionId[questionId];
    if (current == null) return;
    _responsesByQuestionId[questionId] = current.copyWith(photo: photo);
    notifyListeners();
  }

  void setObservationMock(ObservationAudioMock? obs) {
    _observation = obs;
    notifyListeners();
  }

  void finishNow() {
    _finishedAt = DateTime.now();
    notifyListeners();
  }

  PenChecklistStatus statusForPenToday(String penId) {
    final required = _requiredPerPenChecklistIds();
    if (required.isEmpty) return PenChecklistStatus.pendente;

    final map = _penChecklistStatusByPenIdToday[penId] ??
        const <String, PenChecklistStatus>{};
    final statuses = required
        .map((id) => map[id] ?? PenChecklistStatus.pendente)
        .toList(growable: false);

    if (statuses.every((s) => s == PenChecklistStatus.pendente)) {
      return PenChecklistStatus.pendente;
    }
    if (statuses.any((s) => s == PenChecklistStatus.comAlerta)) {
      return PenChecklistStatus.comAlerta;
    }
    if (statuses.every((s) => s == PenChecklistStatus.preenchido)) {
      return PenChecklistStatus.preenchido;
    }
    return PenChecklistStatus.parcial;
  }

  PenChecklistStatus statusForPenChecklistToday(
      {required String penId, required String checklistId}) {
    return _penChecklistStatusByPenIdToday[penId]?[checklistId] ??
        PenChecklistStatus.pendente;
  }

  void updatePenChecklistStatusToday(
      {required String penId,
      required String checklistId,
      required PenChecklistStatus status}) {
    final next = Map<String, PenChecklistStatus>.from(
        _penChecklistStatusByPenIdToday[penId] ?? const {});
    next[checklistId] = status;
    _penChecklistStatusByPenIdToday[penId] = next;
    notifyListeners();
  }

  ChecklistDayStatus statusForGeneralChecklistToday(String checklistId) =>
      _generalPecuariaChecklistStatusToday[checklistId] ??
      ChecklistDayStatus.pendente;

  void updateGeneralChecklistStatusToday(
      {required String checklistId, required ChecklistDayStatus status}) {
    _generalPecuariaChecklistStatusToday[checklistId] = status;
    notifyListeners();
  }

  List<String> _requiredPerPenChecklistIds() {
    return ChecklistsRepository.availableForArea(
            OperationalAreasRepository.pecuariaId)
        .where((c) => c.appliesPerPen)
        .map((c) => c.id)
        .toList();
  }

  bool hasShownInterstitial(String id) => _shownInterstitialIds.contains(id);

  void markInterstitialShown(String id) {
    _shownInterstitialIds.add(id);
  }

  void prepareSuccess(
      {String? title,
      String? message,
      required String returnLocation,
      required String returnLabel}) {
    _successTitleOverride = title;
    _successMessageOverride = message;
    _successReturnLocation = returnLocation;
    _successReturnLabel = returnLabel;
    notifyListeners();
  }

  void resetAll() {
    _selectedOperator = null;
    _selectedArea = null;
    _selectedPen = null;
    _selectedChecklist = null;
    _operationalResponsible = null;
    _startedAt = null;
    _finishedAt = null;
    _responsesByQuestionId.clear();
    _observation = null;
    _penChecklistStatusByPenIdToday.clear();
    _generalPecuariaChecklistStatusToday.clear();
    _shownInterstitialIds.clear();
    _successTitleOverride = null;
    _successMessageOverride = null;
    _successReturnLocation = '/';
    _successReturnLabel = 'Voltar';
    notifyListeners();
  }

  void resetChecklistRunOnly() {
    _selectedChecklist = null;
    _startedAt = null;
    _finishedAt = null;
    _responsesByQuestionId.clear();
    _observation = null;
    _shownInterstitialIds.clear();
    _successTitleOverride = null;
    _successMessageOverride = null;
    notifyListeners();
  }

  String buildObservationMockFilename() {
    final penId = _selectedPen?.id;
    final checklistId = _selectedChecklist?.id;

    if (checklistId == ChecklistsRepository.alimentacaoPecuariaId) {
      return 'audio_alimentacao_mock.mp3';
    }

    if (checklistId == ChecklistsRepository.aberturaDiariaPecuariaId) {
      return 'audio_abertura_diaria_mock.mp3';
    }

    if (checklistId == ChecklistsRepository.ultraDensoPecuariaId) {
      return 'audio_ultra_denso_mock.mp3';
    }

    if (checklistId == ChecklistsRepository.pocosArtesianosPecuariaId) {
      return 'audio_pocos_artesianos_mock.mp3';
    }

    if (checklistId == ChecklistsRepository.montagemNovaPastagemPecuariaId) {
      return 'audio_montagem_nova_pastagem_mock.mp3';
    }

    if (checklistId == ChecklistsRepository.analiseGadoPecuariaId) {
      return 'audio_analise_gado_mock.mp3';
    }

    if (penId == null) return 'audio_observacao_mock.mp3';
    if (checklistId == ChecklistsRepository.manutencaoPreventivaCurralId) {
      final digits = penId.replaceAll(RegExp(r'[^0-9]'), '');
      final suffix = digits.isEmpty ? penId : digits.padLeft(2, '0');
      return 'audio_manutencao_curral_${suffix}_mock.mp3';
    }
    if (checklistId == ChecklistsRepository.lavagemBebedouroCurralId) {
      final digits = penId.replaceAll(RegExp(r'[^0-9]'), '');
      final suffix = digits.isEmpty ? penId : digits.padLeft(2, '0');
      return 'audio_lavagem_bebedouro_curral_${suffix}_mock.mp3';
    }
    return 'audio_observacao_${penId}_mock.mp3';
  }

  int countAnswer(String value) =>
      _responsesByQuestionId.values.where((r) => r.answer == value).length;

  bool hasAnyAdditionalField() =>
      _responsesByQuestionId.values.any((r) => r.additionalFields.isNotEmpty);

  bool hasAnyPhoto() =>
      _responsesByQuestionId.values.any((r) => r.photo != null);

  int photoCount() =>
      _responsesByQuestionId.values.where((r) => r.photo != null).length;

  int alertCount() =>
      _responsesByQuestionId.values.where((r) => r.generatedAlert).length;

  bool hasAnyAlert() =>
      _responsesByQuestionId.values.any((r) => r.generatedAlert);

  Map<String, dynamic> buildFinalJson() {
    final operator = _selectedOperator;
    final checklist = _selectedChecklist;
    if (operator == null || checklist == null) {
      throw StateError('Missing operator/checklist to build final JSON');
    }

    final started = _startedAt ?? DateTime.now();
    final finished = _finishedAt ?? DateTime.now();

    final responses = <Map<String, dynamic>>[];
    for (final q in checklist.questions) {
      final r = _responsesByQuestionId[q.id];
      if (r == null) continue;

      final row = <String, dynamic>{
        'perguntaId': q.id,
        if ((q.stage ?? '').trim().isNotEmpty) 'etapa': q.stage,
        if ((q.block ?? '').trim().isNotEmpty) 'bloco': q.block,
        'pergunta': q.text,
        'resposta': r.answer,
      };

      if (r.level != null) {
        row['nivel'] = {'label': r.level!.label, 'valor': r.level!.value};
      }

      if (r.generatedAlert) {
        row['gerouAlerta'] = true;
      }
      if (r.additionalFields.isNotEmpty) {
        final additional = <String, dynamic>{};
        for (final entry in r.additionalFields.entries) {
          additional[entry.key] = entry.value.toJson();
        }
        row['campoAdicional'] = additional;
      }
      if (r.photo != null) {
        row['foto'] = r.photo!.toJson();
      }
      responses.add(row);
    }

    final observation = _observation;

    final area = _selectedArea;
    final pen = _selectedPen;
    final responsible = _operationalResponsible;
    final totalPhotos = photoCount();
    final totalAlerts = alertCount();
    final statusAfterSend = hasAnyAlert() ? 'com_alerta' : 'preenchido';

    final hasQuantidadePorCurral =
        _responsesByQuestionId['conferiu_quantidade_necessaria_por_curral']
                ?.additionalFields['quantidade_por_curral'] !=
            null;
    final hasVoltagemInformada = _responsesByQuestionId['conferiu_voltagem']
            ?.additionalFields['valor_voltagem_observada'] !=
        null;
    final hasAreaMedida = _responsesByQuestionId['medicao_dentro_padrao']
            ?.additionalFields['area_medida'] !=
        null;

    final hasEstadoGeralGado =
        _responsesByQuestionId['informou_estado_geral_gado']
                ?.additionalFields['estado_geral_gado'] !=
            null;
    final hasOcorrenciaGado =
        _responsesByQuestionId['registrou_ocorrencia']?.answer == 'sim';

    return {
      if (area != null) ...{
        'areaId': area.id,
        'areaTitulo': area.title,
      },
      'checklistId': checklist.id,
      'checklistTitulo': checklist.title,
      'aplicacaoPorCurral': checklist.appliesPerPen,
      if (checklist.appliesPerPen && pen != null)
        'curral': {'id': pen.id, 'nome': pen.name},
      if (responsible != null) 'responsavelOperacional': responsible.label,
      'funcionario': {'id': operator.id, 'nome': operator.name},
      'dataHoraInicio': _formatIsoWithOffset(started.toLocal()),
      'dataHoraFim': _formatIsoWithOffset(finished.toLocal()),
      if ((checklist.periodicity ?? '').trim().isNotEmpty)
        'periodicidade': checklist.periodicity,
      'respostas': responses,
      'observacao': observation == null
          ? {
              'possuiObservacao': false,
              'tipo': null,
              'arquivoLocal': null,
              'duracaoSegundos': null,
            }
          : {
              'possuiObservacao': true,
              'tipo': 'audio',
              'arquivoLocal': observation.localFile,
              'duracaoSegundos': observation.durationSeconds,
            },
      'resumo': {
        'totalPerguntasRespondidas': responses.length,
        'totalAlertas': totalAlerts,
        'totalFotos': totalPhotos,
        'statusChecklistAposEnvio': statusAfterSend,
        if (!checklist.appliesPerPen && hasQuantidadePorCurral)
          'possuiQuantidadePorCurral': true,
        if (!checklist.appliesPerPen &&
            checklist.id == ChecklistsRepository.ultraDensoPecuariaId)
          'possuiVoltagemInformada': hasVoltagemInformada,
        if (!checklist.appliesPerPen &&
            checklist.id == ChecklistsRepository.montagemNovaPastagemPecuariaId)
          'possuiAreaMedida': hasAreaMedida,
        if (!checklist.appliesPerPen &&
            checklist.id == ChecklistsRepository.analiseGadoPecuariaId) ...{
          'possuiEstadoGeralInformado': hasEstadoGeralGado,
          'possuiOcorrencia': hasOcorrenciaGado,
        },
      },
      'status': 'pronto_para_envio',
    };
  }

  String buildFinalJsonPretty() =>
      const JsonEncoder.withIndent('  ').convert(buildFinalJson());
}

String _formatIsoWithOffset(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');

  final y = dt.year.toString().padLeft(4, '0');
  final m = two(dt.month);
  final d = two(dt.day);
  final hh = two(dt.hour);
  final mm = two(dt.minute);
  final ss = two(dt.second);

  final off = dt.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final offAbs = off.abs();
  final offH = two(offAbs.inHours);
  final offM = two(offAbs.inMinutes.remainder(60));
  return '$y-$m-${d}T$hh:$mm:$ss$sign$offH:$offM';
}
