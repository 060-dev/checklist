import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/models/pending_queue_item.dart';
import 'package:morro_do_peo/utils/connectivity.dart';

typedef SendAttempt = Future<void> Function(
    Map<String, dynamic> payload, Map<String, dynamic>? attachments);

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const String _storageKey = 'pending_submission_queue_v1';
  final Uuid _uuid = const Uuid();

  final List<PendingQueueItem> _queue = [];
  bool _initialized = false;
  bool _sendingNow = false;
  Timer? _timer;
  StreamSubscription<bool>? _onlineSub;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  Future<void> init({required SendAttempt sendAttempt}) async {
    if (_initialized) return;
    await _load();
    _initialized = true;
    pendingCountNotifier.value =
        _queue.where((e) => e.status != PendingQueueStatus.sent).length;

    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 15), (_) => flush(sendAttempt: sendAttempt));

    _onlineSub?.cancel();
    _onlineSub = Connectivity.instance.onOnlineChanged.listen((online) {
      if (online) flush(sendAttempt: sendAttempt);
    });

    // tenta já na inicialização
    unawaited(flush(sendAttempt: sendAttempt));
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
    _queue.insert(0, item);
    await _save();
    pendingCountNotifier.value =
        _queue.where((e) => e.status != PendingQueueStatus.sent).length;
    return item;
  }

  Future<void> flush({required SendAttempt sendAttempt}) async {
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
            payload: const <String, dynamic>{},
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

          await sendAttempt(_queue[idx].payload, _queue[idx].attachments);

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
          // Se falhou um, paramos o loop para respeitar o backoff ou esperar nova conexão
          break;
        }
      }
    } finally {
      _sendingNow = false;
    }
  }

  Duration _backoff(int retryCount) {
    // 1ª: 30s, 2ª: 1m, 3ª: 5m, demais: 15m
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
