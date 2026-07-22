import 'package:flutter/foundation.dart';

enum PendingQueueStatus { pending, sending, failed, sent }

/// What kind of work a queued item represents.
///
/// - [legacyChecklistSubmission]: the offline checklist flow's final JSON
///   (no backend endpoint wired yet — kept for backward compatibility with
///   the existing local-only staging behavior).
/// - [apiMutation]: a Mobile API v1 request (method/path/body/idempotency),
///   for the API-driven screens. Sending logic is not implemented yet; see
///   `OfflineQueueService._sendApiMutation`.
enum PendingQueueKind { legacyChecklistSubmission, apiMutation }

@immutable
class PendingQueueItem {
  final String id;
  final PendingQueueKind kind;
  final String? checklistId;
  final String? operatorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PendingQueueStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final DateTime? nextRetryAt;

  /// Legacy checklist submission payload (kind == legacyChecklistSubmission).
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? attachments;

  /// Mobile API v1 mutation fields (kind == apiMutation).
  final String? method;
  final String? path;
  final Map<String, dynamic>? jsonBody;
  final String? idempotencyKey;
  final List<String> mediaFilePaths;

  const PendingQueueItem({
    required this.id,
    this.kind = PendingQueueKind.legacyChecklistSubmission,
    this.checklistId,
    this.operatorId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.retryCount,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.payload = const {},
    this.attachments,
    this.method,
    this.path,
    this.jsonBody,
    this.idempotencyKey,
    this.mediaFilePaths = const [],
  });

  factory PendingQueueItem.fromJson(Map<String, dynamic> json) => PendingQueueItem(
        id: json['id'] as String,
        kind: PendingQueueKind.values.firstWhere(
          (e) => e.name == (json['kind'] as String?),
          orElse: () => PendingQueueKind.legacyChecklistSubmission,
        ),
        checklistId: json['checklistId'] as String?,
        operatorId: json['operatorId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: PendingQueueStatus.values.firstWhere((e) => e.name == (json['status'] as String)),
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        lastAttemptAt: json['lastAttemptAt'] != null ? DateTime.parse(json['lastAttemptAt'] as String) : null,
        nextRetryAt: json['nextRetryAt'] != null ? DateTime.parse(json['nextRetryAt'] as String) : null,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        attachments: (json['attachments'] as Map?)?.cast<String, dynamic>(),
        method: json['method'] as String?,
        path: json['path'] as String?,
        jsonBody: (json['jsonBody'] as Map?)?.cast<String, dynamic>(),
        idempotencyKey: json['idempotencyKey'] as String?,
        mediaFilePaths: (json['mediaFilePaths'] is List) ? (json['mediaFilePaths'] as List).whereType<String>().toList() : const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'checklistId': checklistId,
        'operatorId': operatorId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        'retryCount': retryCount,
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'payload': payload,
        'attachments': attachments,
        'method': method,
        'path': path,
        'jsonBody': jsonBody,
        'idempotencyKey': idempotencyKey,
        'mediaFilePaths': mediaFilePaths,
      };

  PendingQueueItem copyWith({
    String? id,
    PendingQueueKind? kind,
    String? checklistId,
    String? operatorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    PendingQueueStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    DateTime? nextRetryAt,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? attachments,
    String? method,
    String? path,
    Map<String, dynamic>? jsonBody,
    String? idempotencyKey,
    List<String>? mediaFilePaths,
  }) =>
      PendingQueueItem(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        checklistId: checklistId ?? this.checklistId,
        operatorId: operatorId ?? this.operatorId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        payload: payload ?? this.payload,
        attachments: attachments ?? this.attachments,
        method: method ?? this.method,
        path: path ?? this.path,
        jsonBody: jsonBody ?? this.jsonBody,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        mediaFilePaths: mediaFilePaths ?? this.mediaFilePaths,
      );
}
