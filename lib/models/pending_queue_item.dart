import 'package:flutter/foundation.dart';

import 'package:morro_do_peo/models/queued_media_item.dart';

enum PendingQueueStatus { pending, sending, failed, sent }

/// A queued Mobile API v1 mutation (method/path/body/idempotency) awaiting
/// send. See `OfflineQueueService` for how these are sent, retried, and
/// eventually given up on.
@immutable
class PendingQueueItem {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PendingQueueStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final DateTime? nextRetryAt;

  final String method;
  final String path;
  final Map<String, dynamic> jsonBody;
  final String idempotencyKey;
  final List<QueuedMediaItem> mediaItems;

  const PendingQueueItem({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.retryCount,
    this.lastAttemptAt,
    this.nextRetryAt,
    required this.method,
    required this.path,
    required this.jsonBody,
    required this.idempotencyKey,
    this.mediaItems = const [],
  });

  factory PendingQueueItem.fromJson(
    Map<String, dynamic> json,
  ) => PendingQueueItem(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    status: PendingQueueStatus.values.firstWhere(
      (e) => e.name == (json['status'] as String),
    ),
    retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    lastAttemptAt: json['lastAttemptAt'] != null
        ? DateTime.parse(json['lastAttemptAt'] as String)
        : null,
    nextRetryAt: json['nextRetryAt'] != null
        ? DateTime.parse(json['nextRetryAt'] as String)
        : null,
    method: (json['method'] as String?) ?? 'POST',
    path: (json['path'] as String?) ?? '',
    jsonBody: (json['jsonBody'] as Map?)?.cast<String, dynamic>() ?? const {},
    idempotencyKey: (json['idempotencyKey'] as String?) ?? '',
    mediaItems: (json['mediaItems'] is List)
        ? (json['mediaItems'] as List)
              .whereType<Map>()
              .map((e) => QueuedMediaItem.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.name,
    'retryCount': retryCount,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'nextRetryAt': nextRetryAt?.toIso8601String(),
    'method': method,
    'path': path,
    'jsonBody': jsonBody,
    'idempotencyKey': idempotencyKey,
    'mediaItems': mediaItems.map((e) => e.toJson()).toList(),
  };

  PendingQueueItem copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    PendingQueueStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    DateTime? nextRetryAt,
    String? method,
    String? path,
    Map<String, dynamic>? jsonBody,
    String? idempotencyKey,
    List<QueuedMediaItem>? mediaItems,
  }) => PendingQueueItem(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    method: method ?? this.method,
    path: path ?? this.path,
    jsonBody: jsonBody ?? this.jsonBody,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    mediaItems: mediaItems ?? this.mediaItems,
  );
}
