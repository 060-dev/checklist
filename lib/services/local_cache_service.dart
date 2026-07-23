import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morro_do_peo/models/mobile_api_models.dart';
import 'package:morro_do_peo/models/operator.dart';

@immutable
class CachedList<T> {
  final List<T> items;
  final DateTime updatedAt;

  const CachedList({required this.items, required this.updatedAt});
}

/// Persists the last known-good API responses on disk so the app can show
/// real data (never fake/demo data) when offline, with a timestamp so the UI
/// can tell the user how stale it is.
class LocalCacheService {
  static final LocalCacheService instance = LocalCacheService._internal();
  factory LocalCacheService() => instance;
  LocalCacheService._internal();

  static const String _employeesKey = 'cache_employees_v1';
  static String _assignmentsKey(String employeeId) =>
      'cache_assignments_v1_$employeeId';
  static String _executionsKey(String employeeId, String scope) =>
      'cache_executions_v1_${scope}_$employeeId';
  static String _executionDetailKey(String employeeId, String executionId) =>
      'cache_execution_detail_v1_${employeeId}_$executionId';
  static String _assignmentDetailKey(String employeeId, String assignmentId) =>
      'cache_assignment_detail_v1_${employeeId}_$assignmentId';
  static String _occurrencesKey(String employeeId) =>
      'cache_occurrences_v1_$employeeId';

  Future<void> _writeEntry(String key, Object? data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = {
        'updatedAt': DateTime.now().toIso8601String(),
        'data': data,
      };
      await prefs.setString(key, jsonEncode(envelope));
    } catch (e) {
      debugPrint('[LocalCache] Failed to write $key: $e');
    }
  }

  Future<(DateTime, dynamic)?> _readEntry(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final updatedAt = DateTime.tryParse(
        (decoded['updatedAt'] as String?) ?? '',
      );
      if (updatedAt == null) return null;
      return (updatedAt, decoded['data']);
    } catch (e) {
      debugPrint('[LocalCache] Failed to read $key: $e');
      return null;
    }
  }

  Future<void> saveEmployees(List<Operator> employees) =>
      _writeEntry(_employeesKey, employees.map((e) => e.toJson()).toList());

  Future<CachedList<Operator>?> getEmployees() async {
    final entry = await _readEntry(_employeesKey);
    if (entry == null) return null;
    final (updatedAt, data) = entry;
    if (data is! List) return null;
    final items = data
        .whereType<Map>()
        .map((e) => Operator.fromJson(e.cast<String, dynamic>()))
        .toList();
    return CachedList(items: items, updatedAt: updatedAt);
  }

  Future<void> saveAssignments(
    String employeeId,
    List<ChecklistAssignment> assignments,
  ) => _writeEntry(
    _assignmentsKey(employeeId),
    assignments.map((e) => e.toJson()).toList(),
  );

  Future<CachedList<ChecklistAssignment>?> getAssignments(
    String employeeId,
  ) async {
    final entry = await _readEntry(_assignmentsKey(employeeId));
    if (entry == null) return null;
    final (updatedAt, data) = entry;
    if (data is! List) return null;
    final items = data
        .whereType<Map>()
        .map((e) => ChecklistAssignment.fromJson(e.cast<String, dynamic>()))
        .toList();
    return CachedList(items: items, updatedAt: updatedAt);
  }

  /// [scope] distinguishes independent execution lists for the same employee,
  /// e.g. "today" vs "history" (different date ranges/filters).
  Future<void> saveExecutions(
    String employeeId,
    List<ExecutionSummary> executions, {
    required String scope,
  }) => _writeEntry(
    _executionsKey(employeeId, scope),
    executions.map((e) => e.toJson()).toList(),
  );

  Future<CachedList<ExecutionSummary>?> getExecutions(
    String employeeId, {
    required String scope,
  }) async {
    final entry = await _readEntry(_executionsKey(employeeId, scope));
    if (entry == null) return null;
    final (updatedAt, data) = entry;
    if (data is! List) return null;
    final items = data
        .whereType<Map>()
        .map((e) => ExecutionSummary.fromJson(e.cast<String, dynamic>()))
        .toList();
    return CachedList(items: items, updatedAt: updatedAt);
  }

  Future<void> saveExecutionDetail(
    String employeeId,
    String executionId,
    Map<String, dynamic> rawDetail,
  ) => _writeEntry(_executionDetailKey(employeeId, executionId), rawDetail);

  Future<(DateTime, Map<String, dynamic>)?> getExecutionDetail(
    String employeeId,
    String executionId,
  ) async {
    final entry = await _readEntry(
      _executionDetailKey(employeeId, executionId),
    );
    if (entry == null) return null;
    final (updatedAt, data) = entry;
    if (data is! Map) return null;
    return (updatedAt, data.cast<String, dynamic>());
  }

  Future<void> saveAssignmentDetail(
    String employeeId,
    String assignmentId,
    Map<String, dynamic> rawDetail,
  ) => _writeEntry(_assignmentDetailKey(employeeId, assignmentId), rawDetail);

  Future<(DateTime, Map<String, dynamic>)?> getAssignmentDetail(
    String employeeId,
    String assignmentId,
  ) async {
    final entry = await _readEntry(
      _assignmentDetailKey(employeeId, assignmentId),
    );
    if (entry == null) return null;
    final (updatedAt, data) = entry;
    if (data is! Map) return null;
    return (updatedAt, data.cast<String, dynamic>());
  }

  Future<void> saveOccurrences(
    String employeeId,
    List<OccurrenceSummary> occurrences,
  ) => _writeEntry(
    _occurrencesKey(employeeId),
    occurrences.map((e) => e.toJson()).toList(),
  );

  Future<CachedList<OccurrenceSummary>?> getOccurrences(
    String employeeId,
  ) async {
    final entry = await _readEntry(_occurrencesKey(employeeId));
    if (entry == null) return null;
    final (updatedAt, data) = entry;
    if (data is! List) return null;
    final items = data
        .whereType<Map>()
        .map((e) => OccurrenceSummary.fromJson(e.cast<String, dynamic>()))
        .toList();
    return CachedList(items: items, updatedAt: updatedAt);
  }
}
