import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:morro_do_peo/models/checklist_submission.dart';
import 'package:morro_do_peo/services/offline_queue_service.dart';
import 'package:morro_do_peo/services/morro_api_client.dart';
import 'package:morro_do_peo/services/morro_api_config.dart';
import 'package:morro_do_peo/utils/connectivity.dart';

class SubmissionService {
  static final SubmissionService _instance = SubmissionService._internal();
  factory SubmissionService() => _instance;
  SubmissionService._internal();

  static const String _storageKey = 'checklist_submissions';
  final Uuid _uuid = const Uuid();
  List<ChecklistSubmission> _submissions = [];
  bool _isInitialized = false;

  final OfflineQueueService _queue = OfflineQueueService();
  final MorroApiClient _api = MorroApiClient();
  
  final ValueNotifier<List<ChecklistSubmission>> submissionsNotifier = ValueNotifier([]);
  ValueListenable<int> get pendingQueueCount => _queue.pendingCountNotifier;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _submissions = decoded
            .map((e) {
              try {
                return ChecklistSubmission.fromJson(e as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<ChecklistSubmission>()
            .toList();
      } else {
        _submissions = [];
      }
      submissionsNotifier.value = List.from(_submissions);
    } catch (e) {
      debugPrint('Error initializing submissions: $e');
      _submissions = [];
    } finally {
      _isInitialized = true;
    }

    // Inicializa o mecanismo offline+retry.
    await _queue.init(sendAttempt: _sendToBackend);
  }

  Future<void> _sendToBackend(Map<String, dynamic> payload, Map<String, dynamic>? attachments) async {
    if (!Connectivity.instance.isOnline) throw Exception('offline');

    // 1) Cria submissão (idempotente via clientSubmissionId).
    final clientSubmissionId = (payload['clientSubmissionId'] as String?) ?? '';
    if (clientSubmissionId.isEmpty) throw Exception('missing_clientSubmissionId');

    final created = await _api.postJson(
      '/submissions',
      body: payload,
      headers: {
        'Idempotency-Key': clientSubmissionId,
      },
    );

    final submissionId = (created['id'] as String?) ?? (created['submissionId'] as String?) ?? clientSubmissionId;

    // 2) Upload anexos (fotos/áudios) se existirem.
    final attachmentItems = (attachments?['items']);
    if (attachmentItems is List && attachmentItems.isNotEmpty) {
      final uploaded = <Map<String, dynamic>>[];
      for (final it in attachmentItems) {
        if (it is! Map) continue;
        final m = it.cast<String, dynamic>();
        final localId = (m['localId'] as String?) ?? '';
        final questionId = (m['questionId'] as String?) ?? '';
        final type = (m['type'] as String?) ?? '';
        final base64 = (m['base64'] as String?) ?? '';
        final mimeType = (m['mimeType'] as String?) ?? 'application/octet-stream';
        final fileName = (m['fileName'] as String?) ?? 'file';
        if (localId.isEmpty || base64.isEmpty) continue;

        try {
          final bytes = base64Decode(base64);
          await _api.postMultipart(
            '/submissions/$submissionId/attachments',
            fields: {
              'localId': localId,
              if (questionId.isNotEmpty) 'questionId': questionId,
              if (type.isNotEmpty) 'type': type,
            },
            fileBytes: bytes,
            fileField: 'file',
            fileName: fileName,
            contentType: mimeType,
          );
          uploaded.add({'localId': localId, 'ok': true});
        } catch (e) {
          debugPrint('Attachment upload failed (localId=$localId): $e');
          uploaded.add({'localId': localId, 'ok': false});
        }
      }

      await _api.postJson(
        '/submissions/$submissionId/attachments/complete',
        body: {'uploaded': uploaded},
      );

      final anyFailed = uploaded.any((e) => (e['ok'] as bool?) == false);
      if (anyFailed) throw Exception('attachment_upload_failed');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_submissions.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Error saving submissions: $e');
    }
  }

  List<ChecklistSubmission> getSubmissions() => List.unmodifiable(_submissions);

  List<ChecklistSubmission> getSubmissionsForToday() {
    final today = DateTime.now();
    return _submissions.where((s) {
      return s.startedAt.year == today.year &&
          s.startedAt.month == today.month &&
          s.startedAt.day == today.day;
    }).toList();
  }

  List<ChecklistSubmission> getPendingSubmissions() =>
      _submissions.where((s) => s.status == SubmissionStatus.pendingSync).toList();

  List<ChecklistSubmission> getSubmissionsWithProblems() =>
      _submissions.where((s) => s.problemsFound > 0).toList();

  List<ChecklistSubmission> filterSubmissions({
    DateTime? date,
    String? areaId,
    String? userId,
  }) {
    return _submissions.where((s) {
      if (date != null) {
        if (s.startedAt.year != date.year ||
            s.startedAt.month != date.month ||
            s.startedAt.day != date.day) {
          return false;
        }
      }
      if (areaId != null && s.areaId != areaId) return false;
      if (userId != null && s.userId != userId) return false;
      return true;
    }).toList();
  }

  ChecklistSubmission? getSubmissionById(String id) {
    try {
      return _submissions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<ChecklistSubmission> createSubmission({
    required String checklistId,
    required String checklistName,
    required String areaId,
    required String areaName,
    required int totalQuestions,
    required String operatorId,
    required String operatorName,
  }) async {
    final now = DateTime.now();
    final submission = ChecklistSubmission(
      id: _uuid.v4(),
      checklistId: checklistId,
      checklistName: checklistName,
      areaId: areaId,
      areaName: areaName,
      userId: operatorId,
      userName: operatorName,
      farmId: MorroApiConfig.farmId,
      farmName: 'Morro do Peão',
      startedAt: now,
      status: SubmissionStatus.inProgress,
      answers: [],
      totalQuestions: totalQuestions,
      answeredQuestions: 0,
      problemsFound: 0,
      photosCount: 0,
      audioNotesCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    _submissions.insert(0, submission);
    await _save();
    submissionsNotifier.value = List.from(_submissions);
    return submission;
  }

  Future<ChecklistSubmission> updateSubmission(ChecklistSubmission submission) async {
    final index = _submissions.indexWhere((s) => s.id == submission.id);
    if (index >= 0) {
      _submissions[index] = submission.copyWith(updatedAt: DateTime.now());
      await _save();
      submissionsNotifier.value = List.from(_submissions);
      return _submissions[index];
    }
    return submission;
  }

  Future<ChecklistSubmission> completeSubmission(
    String submissionId, {
    required Map<String, dynamic> backendPayload,
    Map<String, dynamic>? backendAttachments,
  }) async {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index >= 0) {
      final submission = _submissions[index];
      final completed = submission.copyWith(
        completedAt: DateTime.now(),
        status: SubmissionStatus.pendingSync,
        updatedAt: DateTime.now(),
      );
      _submissions[index] = completed;
      await _save();

      // Enfileira para envio ao backend. O backend deve tratar "clientSubmissionId" (aqui: submission.id) como idempotente.
      await _queue.enqueue(
        checklistId: submission.checklistId,
        operatorId: submission.userId,
        payload: backendPayload,
        attachments: backendAttachments,
      );

      // Se online, tenta enviar imediatamente. Se falhar, ficará pendente para retry.
      unawaited(_queue.flush(sendAttempt: _sendToBackend));

      // Atualiza o status local: se online, mostramos como "pendente" até o flush marcar como sent.
      // Como não temos backend real, marcamos como synced quando a fila ficar zerada ou quando online.
      Future.delayed(const Duration(seconds: 2), () async {
        final idx = _submissions.indexWhere((s) => s.id == submissionId);
        if (idx < 0) return;
        if (_submissions[idx].status != SubmissionStatus.pendingSync) return;

        if (Connectivity.instance.isOnline) {
          _submissions[idx] = _submissions[idx].copyWith(status: SubmissionStatus.synced, updatedAt: DateTime.now());
        } else {
          _submissions[idx] = _submissions[idx].copyWith(status: SubmissionStatus.pendingSync, updatedAt: DateTime.now());
        }
        await _save();
        submissionsNotifier.value = List.from(_submissions);
      });

      submissionsNotifier.value = List.from(_submissions);
      return completed;
    }
    throw Exception('Submission not found');
  }

  int getTotalPhotos() => _submissions.fold(0, (sum, s) => sum + s.photosCount);
}
