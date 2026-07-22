import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/models/pending_queue_item.dart';
import 'package:morro_do_peo/utils/connectivity.dart';

typedef SendAttempt = Future<void> Function(
    Map<String, dynamic> payload, Map<String, dynamic>? attachments);

/// Sends a single Mobile API v1 mutation item. Not implemented yet — wiring
/// this to `MobileApiClient`/`MobileApiServices` is a follow-up step. Until
/// then, items enqueued via [OfflineQueueService.enqueueApiMutation] simply
/// stay pending and retry with backoff instead of silently reporting success.
typedef ApiMutationSendAttempt = Future<void> Function(PendingQueueItem item);

Future<void> _unimplementedApiMutationSend(PendingQueueItem item) {
  throw UnimplementedError(
      'API mutation sending is not implemented yet (item ${item.id}, ${item.method} ${item.path}).');
}

/// Single offline queue for both the legacy offline-checklist submissions and
/// (in a follow-up step) Mobile API v1 mutations. Persists to
/// SharedPreferences, retries with exponential backoff, and auto-flushes when
/// connectivity returns.
class OfflineQueueService {
  static final OfflineQueueService instance = OfflineQueueService._internal();
  factory OfflineQueueService() => instance;
  OfflineQueueService._internal();

  static const String _storageKey = 'pending_submission_queue_v1';
  final Uuid _uuid = const Uuid();

  final List<PendingQueueItem> _queue = [];
  bool _initialized = false;
  bool _sendingNow = false;
  Timer? _timer;
  StreamSubscription<bool>? _onlineSub;

  SendAttempt? _sendAttempt;
  ApiMutationSendAttempt _sendApiMutation = _unimplementedApiMutationSend;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  Future<void> init({
    required SendAttempt sendAttempt,
    ApiMutationSendAttempt? sendApiMutation,
  }) async {
    if (_initialized) return;
    _sendAttempt = sendAttempt;
    _sendApiMutation = sendApiMutation ?? _unimplementedApiMutationSend;

    await _load();
    _initialized = true;
    pendingCountNotifier.value =
        _queue.where((e) => e.status != PendingQueueStatus.sent).length;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => flush());

    _onlineSub?.cancel();
    _onlineSub = Connectivity.instance.onOnlineChanged.listen((online) {
      if (online) flush();
    });

    unawaited(flush());
  }

  List<PendingQueueItem> get items => List.unmodifiable(_queue);

  Future<PendingQueueItem> enqueue({
    required Map<String, dynamic> payload,
    Map<String, dynamic>? attachments,
    String? checklistId,
    String? operatorId,
  }) async {
    final now = DateTime.now();
    final item = PendingQueueItem(
      id: _uuid.v4(),
      kind: PendingQueueKind.legacyChecklistSubmission,
      checklistId: checklistId,
      operatorId: operatorId,
      createdAt: now,
      updatedAt: now,
      status: PendingQueueStatus.pending,
      retryCount: 0,
      nextRetryAt: now,
      payload: payload,
      attachments: attachments,
    );
    return _enqueueItem(item);
  }

  /// Enqueues a Mobile API v1 mutation. Sending isn't wired up yet (see
  /// [ApiMutationSendAttempt]) — the item will stay pending and retry with
  /// backoff until a real `sendApiMutation` implementation is provided to
  /// [init].
  Future<PendingQueueItem> enqueueApiMutation({
    required String method,
    required String path,
    required Map<String, dynamic> jsonBody,
    String? idempotencyKey,
    List<String> mediaFilePaths = const [],
  }) async {
    final now = DateTime.now();
    final item = PendingQueueItem(
      id: _uuid.v4(),
      kind: PendingQueueKind.apiMutation,
      createdAt: now,
      updatedAt: now,
      status: PendingQueueStatus.pending,
      retryCount: 0,
      nextRetryAt: now,
      method: method,
      path: path,
      jsonBody: jsonBody,
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
      mediaFilePaths: mediaFilePaths,
    );
    return _enqueueItem(item);
  }

  Future<PendingQueueItem> _enqueueItem(PendingQueueItem item) async {
    _queue.insert(0, item);
    await _save();
    pendingCountNotifier.value =
        _queue.where((e) => e.status != PendingQueueStatus.sent).length;
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
          pendingCountNotifier.value =
              _queue.where((e) => e.status != PendingQueueStatus.sent).length;

          await _sendOne(_queue[idx]);

          _queue[idx] = _queue[idx].copyWith(
              status: PendingQueueStatus.sent, updatedAt: DateTime.now());
          await _save();
          pendingCountNotifier.value =
              _queue.where((e) => e.status != PendingQueueStatus.sent).length;
        } catch (e) {
          debugPrint('[QUEUE] Send failed for item ${next.id}: $e');
          final updated = _queue[idx];
          final retryCount = updated.retryCount + 1;
          _queue[idx] = updated.copyWith(
            status: PendingQueueStatus.failed,
            retryCount: retryCount,
            nextRetryAt: DateTime.now().add(_backoff(retryCount)),
            updatedAt: DateTime.now(),
          );
          await _save();
          pendingCountNotifier.value =
              _queue.where((e) => e.status != PendingQueueStatus.sent).length;
          break;
        }
      }
    } finally {
      _sendingNow = false;
    }
  }

  Future<void> _sendOne(PendingQueueItem item) {
    switch (item.kind) {
      case PendingQueueKind.legacyChecklistSubmission:
        return _sendAttempt!(item.payload, item.attachments);
      case PendingQueueKind.apiMutation:
        return _sendApiMutation(item);
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
  }
}
