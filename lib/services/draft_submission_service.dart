import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Armazena, localmente, as respostas enquanto o operador navega pelo checklist.
///
/// Objetivos:
/// - evitar perda ao fechar/atualizar a página;
/// - permitir montar o payload final no envio.
class DraftSubmissionService {
  static final DraftSubmissionService _instance = DraftSubmissionService._internal();
  factory DraftSubmissionService() => _instance;
  DraftSubmissionService._internal();

  static const String _storageKeyPrefix = 'draft_checklist_';

  String _key(String checklistId, String operatorName) => '$_storageKeyPrefix${checklistId}_${operatorName.trim().toLowerCase()}';

  Future<Map<String, dynamic>> loadDraft({required String checklistId, required String operatorName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(checklistId, operatorName));
      if (raw == null) return <String, dynamic>{'answers': <dynamic>[]};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'answers': <dynamic>[]};
    } catch (e) {
      debugPrint('Failed to load draft: $e');
      return <String, dynamic>{'answers': <dynamic>[]};
    }
  }

  Future<void> upsertAnswer({
    required String checklistId,
    required String operatorName,
    required String questionId,
    required Map<String, dynamic> answer,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = await loadDraft(checklistId: checklistId, operatorName: operatorName);
      final answers = (draft['answers'] as List?)?.toList() ?? <dynamic>[];
      final idx = answers.indexWhere((a) => a is Map && a['questionId'] == questionId);
      final newAnswer = <String, dynamic>{'questionId': questionId, ...answer};
      if (idx >= 0) {
        answers[idx] = newAnswer;
      } else {
        answers.add(newAnswer);
      }
      draft['answers'] = answers;
      draft['updatedAt'] = DateTime.now().toIso8601String();
      await prefs.setString(_key(checklistId, operatorName), jsonEncode(draft));
    } catch (e) {
      debugPrint('Failed to save draft answer: $e');
    }
  }

  Future<void> clearDraft({required String checklistId, required String operatorName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(checklistId, operatorName));
    } catch (e) {
      debugPrint('Failed to clear draft: $e');
    }
  }
}
