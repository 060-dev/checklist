import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';

class MobileApiServices {
  final MobileApiClient client;
  const MobileApiServices({required this.client});

  Future<PaginatedResult<ChecklistAssignment>> listAssignments({
    required String employeeId,
    String? search,
    int page = 1,
    int pageSize = 25,
    String order = 'title_asc',
  }) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/checklists',
      query: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': order,
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );

    final data = env.data ?? const <String, dynamic>{};
    final itemsRaw = data['items'];
    final items = <ChecklistAssignment>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        try {
          // Avoid double-adding when `it` is already `Map<String, dynamic>`.
          if (it is Map<String, dynamic>) {
            items.add(ChecklistAssignment.fromJson(it));
          } else if (it is Map) {
            items.add(ChecklistAssignment.fromJson(it.cast<String, dynamic>()));
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

  Future<Map<String, dynamic>> getAssignmentDetail({
    required String employeeId,
    required String assignmentId,
  }) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/checklists/$assignmentId',
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return env.data ?? const <String, dynamic>{};
  }

  Future<PaginatedResult<ExecutionSummary>> listExecutions({
    required String employeeId,
    String? status,
    String? assignmentId,
    String? dateFrom,
    String? dateTo,
    String order = 'due_asc',
    int page = 1,
    int pageSize = 25,
  }) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions',
      query: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': order,
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
        if ((assignmentId ?? '').trim().isNotEmpty)
          'assignment_id': assignmentId!.trim(),
        if ((dateFrom ?? '').trim().isNotEmpty) 'date_from': dateFrom!.trim(),
        if ((dateTo ?? '').trim().isNotEmpty) 'date_to': dateTo!.trim(),
      },
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );

    final data = env.data ?? const <String, dynamic>{};
    final itemsRaw = data['items'];
    final items = <ExecutionSummary>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        try {
          if (it is Map<String, dynamic>) {
            items.add(ExecutionSummary.fromJson(it));
          } else if (it is Map) {
            items.add(ExecutionSummary.fromJson(it.cast<String, dynamic>()));
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

  Future<ExecutionDetail> getExecutionDetail({
    required String employeeId,
    required String executionId,
  }) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId',
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return ExecutionDetail(env.data ?? const <String, dynamic>{});
  }

  Future<void> markExecutionStarted({
    required String employeeId,
    required String executionId,
    required String idempotencyKey,
  }) async {
    await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId/start',
      body: const {},
      idempotencyKey: idempotencyKey,
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  Future<void> markExecutionPending({
    required String employeeId,
    required String executionId,
    required String idempotencyKey,
  }) async {
    await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId/pending',
      body: const {},
      idempotencyKey: idempotencyKey,
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  Future<void> completeExecutionJson({
    required String employeeId,
    required String executionId,
    required String idempotencyKey,
    required Map<String, dynamic> payload,
  }) async {
    await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/executions/$executionId/complete',
      body: payload,
      idempotencyKey: idempotencyKey,
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
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
    final fields = <MapEntry<String, String>>[
      MapEntry('payload', jsonEncode(payload)),
    ];

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
      path:
          '/employees/$employeeId/executions/$executionId/complete-with-evidence',
      idempotencyKey: idempotencyKey,
      fields: fields,
      files: files,
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  Future<Uint8List> downloadEvidence({
    required String employeeId,
    required String executionId,
    required String evidenceId,
  }) async {
    // This endpoint does not use JSON envelope.
    final url = client
        .buildUri(
          '/employees/$employeeId/executions/$executionId/evidence/$evidenceId',
        )
        .toString();
    return client.getBinaryAbsoluteUrl(url);
  }

  Future<PaginatedResult<OccurrenceSummary>> listOccurrences({
    required String employeeId,
    String? status,
    String? search,
    String order = 'due_desc',
    int page = 1,
    int pageSize = 25,
  }) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences',
      query: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': order,
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );

    final data = env.data ?? const <String, dynamic>{};
    final itemsRaw = data['items'];
    final items = <OccurrenceSummary>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        try {
          if (it is Map<String, dynamic>) {
            items.add(OccurrenceSummary.fromJson(it));
          } else if (it is Map) {
            items.add(OccurrenceSummary.fromJson(it.cast<String, dynamic>()));
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

  Future<OccurrenceDetail> getOccurrenceDetail({
    required String employeeId,
    required String occurrenceId,
  }) async {
    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences/$occurrenceId',
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return OccurrenceDetail(env.data ?? const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> createOccurrence({
    required String employeeId,
    required String idempotencyKey,
    required Map<String, dynamic> payload,
  }) async {
    final env = await client.postJson<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences',
      body: payload,
      idempotencyKey: idempotencyKey,
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return env.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> attachOccurrenceFile({
    required String employeeId,
    required String occurrenceId,
    required String idempotencyKey,
    required http.MultipartFile file,
  }) async {
    final env = await client.postMultipart<Map<String, dynamic>>(
      path: '/employees/$employeeId/occurrences/$occurrenceId/attachments',
      idempotencyKey: idempotencyKey,
      fields: const [],
      files: [file],
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return env.data ?? const <String, dynamic>{};
  }

  /// Not documented in the OpenAPI spec yet — mirrors the same path pattern
  /// as [getOccurrenceDetail] (`/employees/{employeeId}/occurrences/{occurrenceId}`)
  /// with PATCH and the `OccurrenceUpdate`-shaped body used by the (admin-only)
  /// web endpoint, sent here against the mobile-scoped path instead. Since
  /// `assigned_to_user_id` isn't part of the mobile occurrence schema at all,
  /// it's omitted rather than guessed.
  ///
  /// [resolveOccurrencePath]/[resolveOccurrencePayload] are exposed as the
  /// single source of truth for this guessed shape so the offline queue can
  /// build an identical request when this call is deferred — if this path
  /// turns out to be wrong once the backend team confirms the real one,
  /// there's exactly one place to change it.
  static String resolveOccurrencePath({
    required String employeeId,
    required String occurrenceId,
  }) => '/employees/$employeeId/occurrences/$occurrenceId';

  static Map<String, dynamic> resolveOccurrencePayload({
    required OccurrenceDetail currentDetail,
    String? resolutionNotes,
  }) {
    final notes = (resolutionNotes ?? '').trim();
    return <String, dynamic>{
      'status': 'resolved',
      if (notes.isNotEmpty) 'resolution_notes': notes,
    };
  }

  Future<OccurrenceDetail> resolveOccurrence({
    required String employeeId,
    required String occurrenceId,
    required String idempotencyKey,
    required OccurrenceDetail currentDetail,
    String? resolutionNotes,
  }) async {
    final env = await client.patchJson<Map<String, dynamic>>(
      path: resolveOccurrencePath(
        employeeId: employeeId,
        occurrenceId: occurrenceId,
      ),
      body: resolveOccurrencePayload(
        currentDetail: currentDetail,
        resolutionNotes: resolutionNotes,
      ),
      idempotencyKey: idempotencyKey,
      decodeData: (json) =>
          (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
    );
    return OccurrenceDetail(env.data ?? const <String, dynamic>{});
  }
}
