import 'package:flutter/foundation.dart';

/// A single media file attached to a queued API mutation, staged to a
/// permanent path (see `stageFileForQueue`) so it survives app restarts
/// while the mutation is pending.
@immutable
class QueuedMediaItem {
  final String stagedPath;

  /// Multipart field name this file is sent under, e.g. `photo`, `audio`,
  /// `photos`, `audios`, `videos`, or `file` (occurrence attachments).
  final String fieldName;

  /// For structured checklist evidence, the question this file answers.
  /// Null for simple-checklist evidence and occurrence attachments.
  final String? questionId;

  const QueuedMediaItem({
    required this.stagedPath,
    required this.fieldName,
    this.questionId,
  });

  factory QueuedMediaItem.fromJson(Map<String, dynamic> json) =>
      QueuedMediaItem(
        stagedPath: (json['stagedPath'] as String?) ?? '',
        fieldName: (json['fieldName'] as String?) ?? '',
        questionId: json['questionId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'stagedPath': stagedPath,
    'fieldName': fieldName,
    'questionId': questionId,
  };
}
