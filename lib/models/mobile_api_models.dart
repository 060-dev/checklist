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
class ApiChecklistAssignment {
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

  const ApiChecklistAssignment({
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

  factory ApiChecklistAssignment.fromJson(Map<String, dynamic> json) =>
      ApiChecklistAssignment(
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
class ApiExecutionSummary {
  final String executionId;
  final String assignmentId;
  final String checklistId;
  final String employeeId;
  final String title;
  final String? location;
  final DateTime? dueAt;
  final String status;

  const ApiExecutionSummary({
    required this.executionId,
    required this.assignmentId,
    required this.checklistId,
    required this.employeeId,
    required this.title,
    required this.location,
    required this.dueAt,
    required this.status,
  });

  factory ApiExecutionSummary.fromJson(Map<String, dynamic> json) =>
      ApiExecutionSummary(
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
  };
}

@immutable
class ApiExecutionDetail {
  final Map<String, dynamic> raw;

  const ApiExecutionDetail(this.raw);

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
  DateTime? get dueAt => (raw['due_at'] is String)
      ? DateTime.tryParse(raw['due_at'] as String)
      : null;

  bool get isSimpleBoolean =>
      raw['requirements'] is Map &&
      ((raw['requirements'] as Map)['boolean'] == true) &&
      ((raw['questions'] is List) ? (raw['questions'] as List).isEmpty : true);

  // --- Completed-execution result fields (MobileExecution schema) ----------

  String? get completedNotes => raw['notes'] as String?;

  bool? get completedBooleanAnswer => raw['boolean_answer'] as bool?;

  Map<String, dynamic> get completedAnswers =>
      (raw['answers'] is Map) ? (raw['answers'] as Map).cast<String, dynamic>() : const <String, dynamic>{};

  List<Map<String, dynamic>> get completedEvidence => (raw['evidence'] is List)
      ? (raw['evidence'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const <Map<String, dynamic>>[];

  DateTime? get completedAt =>
      (raw['completed_at'] is String) ? DateTime.tryParse(raw['completed_at'] as String) : null;
}

@immutable
class MobileEvidenceRef {
  final String id;
  final String kind;
  final String? questionId;
  final String originalName;
  final String url;
  final String sha256;

  const MobileEvidenceRef({required this.id, required this.kind, required this.questionId, required this.originalName, required this.url, required this.sha256});

  factory MobileEvidenceRef.fromJson(Map<String, dynamic> json) => MobileEvidenceRef(
    id: (json['id'] as num?)?.toString() ?? (json['id']?.toString() ?? ''),
    kind: (json['kind'] as String?) ?? '',
    questionId: json['question_id']?.toString(),
    originalName: (json['original_name'] as String?) ?? '',
    url: (json['url'] as String?) ?? '',
    sha256: (json['sha256'] as String?) ?? '',
  );
}

@immutable
class ApiOccurrenceSummary {
  final String occurrenceId;
  final String title;
  final String? location;
  final String status;
  final String? priority;
  final DateTime? dueAt;

  const ApiOccurrenceSummary({
    required this.occurrenceId,
    required this.title,
    required this.location,
    required this.status,
    required this.priority,
    required this.dueAt,
  });

  factory ApiOccurrenceSummary.fromJson(Map<String, dynamic> json) =>
      ApiOccurrenceSummary(
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
      );

  Map<String, dynamic> toJson() => {
    'occurrence_id': occurrenceId,
    'title': title,
    'location': location,
    'status': status,
    'priority': priority,
    'due_at': dueAt?.toIso8601String(),
  };
}

@immutable
class ApiOccurrenceDetail {
  final Map<String, dynamic> raw;
  const ApiOccurrenceDetail(this.raw);
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
}
