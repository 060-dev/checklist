import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/models/pending_queue_item.dart';
import 'package:morro_do_peo/models/queued_media_item.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/utils/connectivity.dart';
import 'package:morro_do_peo/utils/file_staging.dart';

/// Sends a single Mobile API v1 mutation item. Not implemented yet — wiring
/// this to `MobileApiClient`/`MobileApiServices` is a follow-up step. Until
/// then, items enqueued via [OfflineQueueService.enqueueApiMutation] simply
/// stay pending and retry with backoff instead of silently reporting success.
typedef ApiMutationSendAttempt = Future<void> Function(PendingQueueItem item);

Future<void> _unimplementedApiMutationSend(PendingQueueItem item) {
  throw UnimplementedError(
    'API mutation sending is not implemented yet (item ${item.id}, ${item.method} ${item.path}).',
  );
}

/// Companion multipart field carrying the question ID for each structured
/// checklist-evidence field (matches `MobileApiServices.completeExecutionWithEvidence`).
const Map<String, String> _questionIdFieldFor = {
  'photos': 'photo_question_ids',
  'audios': 'audio_question_ids',
  'videos': 'video_question_ids',
};

/// Real sender: dispatches a queued item via a fresh `MobileApiClient` built
/// from the current session credentials, the same way every other screen's
/// `_mutate`-style helper does.
///
/// - Items with `mediaItems` go out as multipart (execution
///   complete-with-evidence, occurrence attachments); the JSON body (if any)
///   rides along as a `payload` field, matching how those endpoints already
///   expect it live.
/// - Items without media go out as plain JSON via POST or PATCH.
Future<void> sendQueuedMutation(
  PendingQueueItem item,
  AppSession session,
) async {
  final client = MobileApiClient(
    apiBaseUrl: session.apiBaseUrl.trim(),
    apiKey: session.apiKey.trim(),
    employeeCode: item.employeeCode ?? session.employeeCode,
    requestTimeout: Duration(seconds: session.requestTimeoutSeconds),
    uploadTimeout: Duration(seconds: session.uploadTimeoutSeconds),
  );
  try {
    if (item.mediaItems.isNotEmpty) {
      final fields = <MapEntry<String, String>>[];
      if (item.jsonBody.isNotEmpty) {
        fields.add(MapEntry('payload', jsonEncode(item.jsonBody)));
      }
      final files = <http.MultipartFile>[];
      for (final m in item.mediaItems) {
        files.add(await http.MultipartFile.fromPath(m.fieldName, m.stagedPath));
        final qidField = _questionIdFieldFor[m.fieldName];
        if (qidField != null) {
          fields.add(MapEntry(qidField, m.questionId ?? ''));
        }
      }
      await client.postMultipart<Map<String, dynamic>>(
        path: item.path,
        idempotencyKey: item.idempotencyKey,
        fields: fields,
        files: files,
        decodeData: (json) =>
            (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
      );
    } else if (item.method == 'PATCH') {
      await client.patchJson<Map<String, dynamic>>(
        path: item.path,
        body: item.jsonBody,
        idempotencyKey: item.idempotencyKey,
        decodeData: (json) =>
            (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
      );
    } else {
      await client.postJson<Map<String, dynamic>>(
        path: item.path,
        body: item.jsonBody,
        idempotencyKey: item.idempotencyKey,
        decodeData: (json) =>
            (json is Map) ? json.cast<String, dynamic>() : <String, dynamic>{},
      );
    }
  } finally {
    client.dispose();
  }
}

/// Offline queue for Mobile API v1 mutations (the API-driven screens).
/// Persists to SharedPreferences, retries with exponential backoff, and
/// auto-flushes when connectivity returns.
class OfflineQueueService {
  static final OfflineQueueService instance = OfflineQueueService._internal();
  factory OfflineQueueService() => instance;
  OfflineQueueService._internal();

  static const String _storageKey = 'pending_submission_queue_v1';

  /// After this many failed attempts, an item stops retrying automatically
  /// and [onItemFailed] fires so the screen that enqueued it can revert any
  /// optimistic UI state.
  static const int maxRetries = 5;

  /// Sentinel `nextRetryAt` marking an item as permanently given up on,
  /// without needing a new persisted status value — `flush()`'s existing
  /// "due for retry" filter already excludes anything this far out.
  static final DateTime _givenUpSentinel = DateTime.utc(9999);

  final Uuid _uuid = const Uuid();

  final List<PendingQueueItem> _queue = [];
  bool _initialized = false;
  bool _sendingNow = false;
  Timer? _timer;
  StreamSubscription<bool>? _onlineSub;

  ApiMutationSendAttempt _sendApiMutation = _unimplementedApiMutationSend;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  final StreamController<PendingQueueItem> _itemFailedController =
      StreamController<PendingQueueItem>.broadcast();

  /// Fires once per item that has permanently given up (max retries reached
  /// or a non-retryable 4xx response), after its staged files (if any) have
  /// already been cleaned up.
  Stream<PendingQueueItem> get onItemFailed => _itemFailedController.stream;

  Future<void> init({ApiMutationSendAttempt? sendApiMutation}) async {
    if (_initialized) return;
    _sendApiMutation = sendApiMutation ?? _unimplementedApiMutationSend;

    await _load();
    _initialized = true;
    pendingCountNotifier.value = _pendingCount();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => flush());

    _onlineSub?.cancel();
    _onlineSub = Connectivity.instance.onOnlineChanged.listen((online) {
      if (online) flush();
    });

    unawaited(flush());
  }

  List<PendingQueueItem> get items => List.unmodifiable(_queue);

  bool _hasGivenUp(PendingQueueItem item) =>
      item.status == PendingQueueStatus.failed &&
      item.nextRetryAt != null &&
      !item.nextRetryAt!.isBefore(_givenUpSentinel);

  int _pendingCount() => _queue
      .where((e) => e.status != PendingQueueStatus.sent && !_hasGivenUp(e))
      .length;

  int pendingCountFor(String? employeeId) => _queue
      .where((e) =>
          e.status != PendingQueueStatus.sent &&
          !_hasGivenUp(e) &&
          e.employeeId == employeeId)
      .length;

  bool _isNonRetryable(Object error) {
    if (error is! MobileApiException) return false;
    final code = error.statusCode;
    // 408 (timeout) and 429 (rate limit) are worth retrying; other 4xx
    // (validation, auth, not-found, etc.) won't succeed on their own.
    return code >= 400 && code < 500 && code != 408 && code != 429;
  }

  /// Enqueues a Mobile API v1 mutation.
  Future<PendingQueueItem> enqueueApiMutation({
    required String method,
    required String path,
    required Map<String, dynamic> jsonBody,
    String? idempotencyKey,
    List<QueuedMediaItem> mediaItems = const [],
    String? employeeId,
    String? employeeCode,
  }) async {
    final now = DateTime.now();
    final item = PendingQueueItem(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      status: PendingQueueStatus.pending,
      retryCount: 0,
      nextRetryAt: now,
      method: method,
      path: path,
      jsonBody: jsonBody,
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
      mediaItems: mediaItems,
      employeeId: employeeId,
      employeeCode: employeeCode,
    );
    _queue.insert(0, item);
    await _save();
    pendingCountNotifier.value = _pendingCount();
    return item;
  }

  Future<void> flush() async {
    if (!_initialized) return;
    if (_sendingNow) return;
    if (!Connectivity.instance.isOnline) return;

    _sendingNow = true;
    try {
      while (Connectivity.instance.isOnline) {
        final now = DateTime.now();
        final next = _queue.firstWhere(
          (e) =>
              e.status != PendingQueueStatus.sent &&
              (e.nextRetryAt == null || !e.nextRetryAt!.isAfter(now)),
          orElse: () => PendingQueueItem(
            id: '__none__',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            status: PendingQueueStatus.sent,
            retryCount: 0,
            method: 'POST',
            path: '',
            jsonBody: const {},
            idempotencyKey: '',
          ),
        );

        if (next.id == '__none__') break;

        final idx = _queue.indexWhere((e) => e.id == next.id);
        if (idx < 0) break;

        try {
          _queue[idx] = _queue[idx].copyWith(
            status: PendingQueueStatus.sending,
            lastAttemptAt: now,
            updatedAt: now,
          );
          await _save();
          pendingCountNotifier.value = _pendingCount();

          await _sendApiMutation(_queue[idx]);

          for (final m in _queue[idx].mediaItems) {
            unawaited(deleteStagedFile(m.stagedPath));
          }
          _queue[idx] = _queue[idx].copyWith(
            status: PendingQueueStatus.sent,
            updatedAt: DateTime.now(),
          );
          await _save();
          pendingCountNotifier.value = _pendingCount();
        } catch (e) {
          debugPrint('[QUEUE] Send failed for item ${next.id}: $e');
          final updated = _queue[idx];
          final retryCount = updated.retryCount + 1;
          final giveUp = _isNonRetryable(e) || retryCount >= maxRetries;
          _queue[idx] = updated.copyWith(
            status: PendingQueueStatus.failed,
            retryCount: retryCount,
            nextRetryAt: giveUp
                ? _givenUpSentinel
                : DateTime.now().add(_backoff(retryCount)),
            updatedAt: DateTime.now(),
          );
          await _save();
          pendingCountNotifier.value = _pendingCount();
          if (giveUp) {
            for (final m in updated.mediaItems) {
              unawaited(deleteStagedFile(m.stagedPath));
            }
            _itemFailedController.add(_queue[idx]);
          }
          break;
        }
      }
    } finally {
      _sendingNow = false;
    }
  }

  Duration _backoff(int retryCount) {
    if (retryCount <= 1) return const Duration(seconds: 30);
    if (retryCount == 2) return const Duration(minutes: 1);
    if (retryCount == 3) return const Duration(minutes: 5);
    return const Duration(minutes: 15);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _queue
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map((e) {
            try {
              return PendingQueueItem.fromJson(e.cast<String, dynamic>());
            } catch (_) {
              return null;
            }
          }).whereType<PendingQueueItem>(),
        );
    } catch (e) {
      debugPrint('[QUEUE] Failed to load queue from storage: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('[QUEUE] Failed to save queue to storage: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _onlineSub?.cancel();
    _onlineSub = null;
    pendingCountNotifier.dispose();
    unawaited(_itemFailedController.close());
  }
}
