import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';

class MobileApiServices {
  final MobileApiClient client;
  const MobileApiServices({required this.client});

  Future<PaginatedResult<ApiChecklistAssignment>> listAssignments({required String employeeId, String? search, int page = 1, int pageSize = 25, String order = 'title_asc'}) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/checklists',
      query: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': order,
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );

    final data = env.data ?? const <String, dynamic>{};
    final itemsRaw = data['items'];
    final items = <ApiChecklistAssignment>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        try {
          // Avoid double-adding when `it` is already `Map<String, dynamic>`.
          if (it is Map<String, dynamic>) {
            items.add(ApiChecklistAssignment.fromJson(it));
          } else if (it is Map) {
            items.add(ApiChecklistAssignment.fromJson(it.cast<String, dynamic>()));
          }
        } catch (e) {
          debugPrint('Skipping invalid assignment item: $e');
        }
      }
    }

    return PaginatedResult(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Map<String, dynamic>> getAssignmentDetail({required String employeeId, required String assignmentId}) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/checklists/$assignmentId',
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return env.data ?? const <String, dynamic>{};
  }

  Future<PaginatedResult<ApiExecutionSummary>> listExecutions({required String employeeId, String? status, String? assignmentId, String? dateFrom, String? dateTo, String order = 'due_asc', int page = 1, int pageSize = 25}) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions',
      query: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': order,
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
        if ((assignmentId ?? '').trim().isNotEmpty) 'assignment_id': assignmentId!.trim(),
        if ((dateFrom ?? '').trim().isNotEmpty) 'date_from': dateFrom!.trim(),
        if ((dateTo ?? '').trim().isNotEmpty) 'date_to': dateTo!.trim(),
      },
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );

    final data = env.data ?? const <String, dynamic>{};
    final itemsRaw = data['items'];
    final items = <ApiExecutionSummary>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        try {
          if (it is Map<String, dynamic>) {
            items.add(ApiExecutionSummary.fromJson(it));
          } else if (it is Map) {
            items.add(ApiExecutionSummary.fromJson(it.cast<String, dynamic>()));
          }
        } catch (e) {
          debugPrint('Skipping invalid execution item: $e');
        }
      }
    }

    return PaginatedResult(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<ApiExecutionDetail> getExecutionDetail({required String employeeId, required String executionId}) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId',
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return ApiExecutionDetail(env.data ?? const <String, dynamic>{});
  }

  Future<void> markExecutionStarted({required String employeeId, required String executionId, required String idempotencyKey}) async {
    await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId/start',
      body: const {},
      idempotencyKey: idempotencyKey,
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  Future<void> markExecutionPending({required String employeeId, required String executionId, required String idempotencyKey}) async {
    await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId/pending',
      body: const {},
      idempotencyKey: idempotencyKey,
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  Future<void> completeExecutionJson({required String employeeId, required String executionId, required String idempotencyKey, required Map<String, dynamic> payload}) async {
    await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId/complete',
      body: payload,
      idempotencyKey: idempotencyKey,
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  Future<void> completeExecutionWithEvidence({
    required String employeeId,
    required String executionId,
    required String idempotencyKey,
    required Map<String, dynamic> payload,
    http.MultipartFile? photo,
    http.MultipartFile? audio,
    List<http.MultipartFile> photos = const [],
    List<String> photoQuestionIds = const [],
    List<http.MultipartFile> audios = const [],
    List<String> audioQuestionIds = const [],
    List<http.MultipartFile> videos = const [],
    List<String> videoQuestionIds = const [],
  }) async {
    final fields = <MapEntry<String, String>>[MapEntry('payload', jsonEncode(payload))];

    // Structured evidence must be sent as repeated fields in the same order:
    // - photos + photo_question_ids
    // - audios + audio_question_ids
    // (The service validates 1:1 cardinality.)
    final files = <http.MultipartFile>[];

    if (photo != null) files.add(photo);
    if (audio != null) files.add(audio);

    if (photos.isNotEmpty) {
      for (var i = 0; i < photos.length; i++) {
        final qid = (i < photoQuestionIds.length) ? photoQuestionIds[i] : '';
        files.add(photos[i]);
        fields.add(MapEntry('photo_question_ids', qid));
      }
    }

    if (audios.isNotEmpty) {
      for (var i = 0; i < audios.length; i++) {
        final qid = (i < audioQuestionIds.length) ? audioQuestionIds[i] : '';
        files.add(audios[i]);
        fields.add(MapEntry('audio_question_ids', qid));
      }
    }

    if (videos.isNotEmpty) {
      for (var i = 0; i < videos.length; i++) {
        final qid = (i < videoQuestionIds.length) ? videoQuestionIds[i] : '';
        files.add(videos[i]);
        fields.add(MapEntry('video_question_ids', qid));
      }
    }

    await client.postMultipart<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId/complete-with-evidence',
      idempotencyKey: idempotencyKey,
      fields: fields,
      files: files,
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  Future<Uint8List> downloadEvidence({required String employeeId, required String executionId, required String evidenceId}) async {
    // This endpoint does not use JSON envelope.
    final url = client.buildUri('/employees/$employeeId/executions/$executionId/evidence/$evidenceId').toString();
    return client.getBinaryAbsoluteUrl(url);
  }

  Future<PaginatedResult<ApiOccurrenceSummary>> listOccurrences({required String employeeId, String? status, String? search, String order = 'due_desc', int page = 1, int pageSize = 25}) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences',
      query: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': order,
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );

    final data = env.data ?? const <String, dynamic>{};
    final itemsRaw = data['items'];
    final items = <ApiOccurrenceSummary>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        try {
          if (it is Map<String, dynamic>) {
            items.add(ApiOccurrenceSummary.fromJson(it));
          } else if (it is Map) {
            items.add(ApiOccurrenceSummary.fromJson(it.cast<String, dynamic>()));
          }
        } catch (e) {
          debugPrint('Skipping invalid occurrence item: $e');
        }
      }
    }

    return PaginatedResult(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<ApiOccurrenceDetail> getOccurrenceDetail({required String employeeId, required String occurrenceId}) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences/$occurrenceId',
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return ApiOccurrenceDetail(env.data ?? const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> createOccurrence({required String employeeId, required String idempotencyKey, required Map<String, dynamic> payload}) async {
    final env = await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences',
      body: payload,
      idempotencyKey: idempotencyKey,
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return env.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> attachOccurrenceImage({required String employeeId, required String occurrenceId, required String idempotencyKey, required http.MultipartFile file}) async {
    final env = await client.postMultipart<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences/$occurrenceId/attachments',
      idempotencyKey: idempotencyKey,
      fields: const [],
      files: [file],
      decodeData: (json) => (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return env.data ?? const <String, dynamic>{};
  }
}
