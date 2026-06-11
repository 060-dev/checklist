import 'package:flutter/foundation.dart';

enum PendingQueueStatus { pending, sending, failed, sent }

@immutable
class PendingQueueItem {
  final String id;
  final String? checklistId;
  final String? operatorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PendingQueueStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final DateTime? nextRetryAt;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? attachments;

  const PendingQueueItem({
    required this.id,
    this.checklistId,
    this.operatorId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.retryCount,
    this.lastAttemptAt,
    this.nextRetryAt,
    required this.payload,
    this.attachments,
  });

  factory PendingQueueItem.fromJson(Map<String, dynamic> json) => PendingQueueItem(
        id: json['id'] as String,
        checklistId: json['checklistId'] as String?,
        operatorId: json['operatorId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: PendingQueueStatus.values.firstWhere((e) => e.name == (json['status'] as String)),
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        lastAttemptAt: json['lastAttemptAt'] != null ? DateTime.parse(json['lastAttemptAt'] as String) : null,
        nextRetryAt: json['nextRetryAt'] != null ? DateTime.parse(json['nextRetryAt'] as String) : null,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
        attachments: (json['attachments'] as Map?)?.cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
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
      };

  PendingQueueItem copyWith({
    String? id,
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
  }) =>
      PendingQueueItem(
        id: id ?? this.id,
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
      );
}
