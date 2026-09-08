import 'package:flutter/foundation.dart';

@immutable
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int pages;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.pages,
  });
}

@immutable
class ChecklistAssignment {
  final String assignmentId;
  final String checklistId;
  final String title;
  final String description;
  final String? location;
  final String? frequency;
  final int? interval;
  final List<int> weekdays;
  final int? dayOfMonth;
  final String? startDate;
  final String? endDate;
  final String? dueTime;
  final String? nextExecutionId;
  final DateTime? nextDueAt;
  final String? nextStatus;

  const ChecklistAssignment({
    required this.assignmentId,
    required this.checklistId,
    required this.title,
    required this.description,
    required this.location,
    required this.frequency,
    required this.interval,
    required this.weekdays,
    required this.dayOfMonth,
    required this.startDate,
    required this.endDate,
    required this.dueTime,
    required this.nextExecutionId,
    required this.nextDueAt,
    required this.nextStatus,
  });

  factory ChecklistAssignment.fromJson(Map<String, dynamic> json) =>
      ChecklistAssignment(
        assignmentId:
            (json['assignment_id'] as num?)?.toString() ??
            (json['assignment_id']?.toString() ?? ''),
        checklistId:
            (json['checklist_id'] as num?)?.toString() ??
            (json['checklist_id']?.toString() ?? ''),
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        location: json['location'] as String?,
        frequency: json['frequency'] as String?,
        interval: (json['interval'] as num?)?.toInt(),
        weekdays: (json['weekdays'] is List)
            ? (json['weekdays'] as List)
                  .whereType<num>()
                  .map((e) => e.toInt())
                  .toList()
            : const [],
        dayOfMonth: (json['day_of_month'] as num?)?.toInt(),
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        dueTime: json['due_time'] as String?,
        nextExecutionId:
            (json['next_execution_id'] as num?)?.toString() ??
            (json['next_execution_id']?.toString()),
        nextDueAt: (json['next_due_at'] is String)
            ? DateTime.tryParse(json['next_due_at'] as String)
            : null,
        nextStatus: json['next_status'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'assignment_id': assignmentId,
    'checklist_id': checklistId,
    'title': title,
    'description': description,
    'location': location,
    'frequency': frequency,
    'interval': interval,
    'weekdays': weekdays,
    'day_of_month': dayOfMonth,
    'start_date': startDate,
    'end_date': endDate,
    'due_time': dueTime,
    'next_execution_id': nextExecutionId,
    'next_due_at': nextDueAt?.toIso8601String(),
    'next_status': nextStatus,
  };
}

@immutable
class ExecutionSummary {
  final String executionId;
  final String assignmentId;
  final String checklistId;
  final String employeeId;
  final String title;
  final String? location;
  final DateTime? dueAt;
  final String status;
  final String? completionStatus;
  final DateTime? scheduledFor;

  const ExecutionSummary({
    required this.executionId,
    required this.assignmentId,
    required this.checklistId,
    required this.employeeId,
    required this.title,
    required this.location,
    required this.dueAt,
    required this.status,
    this.completionStatus,
    this.scheduledFor,
  });

  factory ExecutionSummary.fromJson(Map<String, dynamic> json) =>
      ExecutionSummary(
        executionId:
            (json['execution_id'] as num?)?.toString() ??
            (json['execution_id']?.toString() ?? ''),
        assignmentId:
            (json['assignment_id'] as num?)?.toString() ??
            (json['assignment_id']?.toString() ?? ''),
        checklistId:
            (json['checklist_id'] as num?)?.toString() ??
            (json['checklist_id']?.toString() ?? ''),
        employeeId:
            (json['employee_id'] as num?)?.toString() ??
            (json['employee_id']?.toString() ?? ''),
        title: (json['title'] as String?) ?? '',
        location: json['location'] as String?,
        dueAt: (json['due_at'] is String)
            ? DateTime.tryParse(json['due_at'] as String)
            : null,
        status: (json['status'] as String?) ?? 'pending',
        completionStatus: json['completion_status'] as String?,
        scheduledFor: (json['scheduled_for'] is String)
            ? DateTime.tryParse(json['scheduled_for'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'execution_id': executionId,
    'assignment_id': assignmentId,
    'checklist_id': checklistId,
    'employee_id': employeeId,
    'title': title,
    'location': location,
    'due_at': dueAt?.toIso8601String(),
    'status': status,
    'completion_status': completionStatus,
    'scheduled_for': scheduledFor?.toIso8601String(),
  };
}

@immutable
class ExecutionDetail {
  final Map<String, dynamic> raw;

  const ExecutionDetail(this.raw);

  String get executionId =>
      (raw['execution_id'] as num?)?.toString() ??
      (raw['execution_id']?.toString() ?? '');
  String get assignmentId =>
      (raw['assignment_id'] as num?)?.toString() ??
      (raw['assignment_id']?.toString() ?? '');
  String get checklistId =>
      (raw['checklist_id'] as num?)?.toString() ??
      (raw['checklist_id']?.toString() ?? '');
  String get employeeId =>
      (raw['employee_id'] as num?)?.toString() ??
      (raw['employee_id']?.toString() ?? '');
  String get title => (raw['title'] as String?) ?? '';
  String? get description => raw['description'] as String?;
  String? get instructions => raw['instructions'] as String?;
  String? get location => raw['location'] as String?;
  String get status => (raw['status'] as String?) ?? 'pending';
  String? get completionStatus => raw['completion_status'] as String?;
  DateTime? get dueAt => (raw['due_at'] is String)
      ? DateTime.tryParse(raw['due_at'] as String)
      : null;
  DateTime? get scheduledFor => (raw['scheduled_for'] is String)
      ? DateTime.tryParse(raw['scheduled_for'] as String)
      : null;
  Map<String, dynamic>? get narrationAudio =>
      (raw['narration_audio'] is Map)
          ? (raw['narration_audio'] as Map).cast<String, dynamic>()
          : null;

  bool get isSimpleBoolean =>
      raw['requirements'] is Map &&
      ((raw['requirements'] as Map)['boolean'] == true) &&
      ((raw['questions'] is List) ? (raw['questions'] as List).isEmpty : true);

  // --- Completed-execution result fields (MobileExecution schema) ----------

  String? get completedNotes => raw['notes'] as String?;

  bool? get completedBooleanAnswer => raw['boolean_answer'] as bool?;

  Map<String, dynamic> get completedAnswers => (raw['answers'] is Map)
      ? (raw['answers'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};

  List<Map<String, dynamic>> get completedEvidence => (raw['evidence'] is List)
      ? (raw['evidence'] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
      : const <Map<String, dynamic>>[];

  DateTime? get completedAt => (raw['completed_at'] is String)
      ? DateTime.tryParse(raw['completed_at'] as String)
      : null;
}

@immutable
class MobileEvidenceRef {
  final String id;
  final String kind;
  final String? questionId;
  final String originalName;
  final String url;
  final String sha256;
  final String? transcription;
  final DateTime? transcribedAt;

  const MobileEvidenceRef({
    required this.id,
    required this.kind,
    required this.questionId,
    required this.originalName,
    required this.url,
    required this.sha256,
    this.transcription,
    this.transcribedAt,
  });

  /// Checklist evidence (`MobileEvidence`) carries an explicit `kind`.
  /// Occurrence attachments (`MobileOccurrenceAttachment`) don't have a
  /// `kind` field at all, only `content_type` (e.g. `image/jpeg`,
  /// `audio/mp4`, `video/mp4`) — derive it from that instead when missing.
  static String kindFromContentType(String contentType) {
    final ct = contentType.trim().toLowerCase();
    if (ct.startsWith('image/')) return 'photo';
    if (ct.startsWith('audio/')) return 'audio';
    if (ct.startsWith('video/')) return 'video';
    return '';
  }

  factory MobileEvidenceRef.fromJson(Map<String, dynamic> json) =>
      MobileEvidenceRef(
        id: (json['id'] as num?)?.toString() ?? (json['id']?.toString() ?? ''),
        kind:
            (json['kind'] as String?) ??
            kindFromContentType((json['content_type'] as String?) ?? ''),
        questionId: json['question_id']?.toString(),
        originalName: (json['original_name'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        sha256: (json['sha256'] as String?) ?? '',
        transcription: json['transcription'] as String?,
        transcribedAt: (json['transcribed_at'] is String)
            ? DateTime.tryParse(json['transcribed_at'] as String)
            : null,
      );
}

@immutable
class OccurrenceSummary {
  final String occurrenceId;
  final String title;
  final String? location;
  final String status;
  final String? priority;
  final DateTime? dueAt;
  final bool isOverdue;

  const OccurrenceSummary({
    required this.occurrenceId,
    required this.title,
    required this.location,
    required this.status,
    required this.priority,
    required this.dueAt,
    required this.isOverdue,
  });

  factory OccurrenceSummary.fromJson(Map<String, dynamic> json) =>
      OccurrenceSummary(
        occurrenceId:
            (json['occurrence_id'] as num?)?.toString() ??
            (json['id'] as num?)?.toString() ??
            (json['occurrence_id']?.toString() ??
                (json['id']?.toString() ?? '')),
        title: (json['title'] as String?) ?? '',
        location: json['location'] as String?,
        status: (json['status'] as String?) ?? 'open',
        priority: json['priority'] as String?,
        dueAt: (json['due_at'] is String)
            ? DateTime.tryParse(json['due_at'] as String)
            : null,
        isOverdue: json['is_overdue'] == true,
      );

  Map<String, dynamic> toJson() => {
    'occurrence_id': occurrenceId,
    'title': title,
    'location': location,
    'status': status,
    'priority': priority,
    'due_at': dueAt?.toIso8601String(),
    'is_overdue': isOverdue,
  };
}

@immutable
class OccurrenceDetail {
  final Map<String, dynamic> raw;
  const OccurrenceDetail(this.raw);
  String get occurrenceId =>
      (raw['occurrence_id'] as num?)?.toString() ??
      (raw['id'] as num?)?.toString() ??
      (raw['occurrence_id']?.toString() ?? (raw['id']?.toString() ?? ''));
  String get title => (raw['title'] as String?) ?? '';
  String? get description => raw['description'] as String?;
  String? get location => raw['location'] as String?;
  String get status => (raw['status'] as String?) ?? 'open';
  String? get priority => raw['priority'] as String?;
  DateTime? get dueAt => (raw['due_at'] is String)
      ? DateTime.tryParse(raw['due_at'] as String)
      : null;
  bool get isOverdue => raw['is_overdue'] == true;
  DateTime? get createdAt => (raw['created_at'] is String)
      ? DateTime.tryParse(raw['created_at'] as String)
      : null;
  DateTime? get resolvedAt => (raw['resolved_at'] is String)
      ? DateTime.tryParse(raw['resolved_at'] as String)
      : null;
  String? get resolutionNotes => raw['resolution_notes'] as String?;
  Map<String, dynamic>? get narrationAudio =>
      (raw['narration_audio'] is Map)
          ? (raw['narration_audio'] as Map).cast<String, dynamic>()
          : null;

  List<Map<String, dynamic>> get attachments => (raw['attachments'] is List)
      ? (raw['attachments'] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
      : const <Map<String, dynamic>>[];
}
