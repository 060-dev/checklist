import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morro_do_peo/models/checklist.dart';
import 'package:morro_do_peo/models/checklist_question.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/services/morro_api_client.dart';
import 'package:morro_do_peo/services/morro_api_config.dart';

class ChecklistService {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  static const String _storageKey = 'cached_catalog';
  final MorroApiClient _api = MorroApiClient();
  List<Checklist> _checklists = [];
  bool _isInitialized = false;
  Future<void>? _syncFuture;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        
        final rawAreas = decoded['areas'] as List<dynamic>? ?? [];
        if (rawAreas.isNotEmpty) {
          ChecklistArea.setAreas(rawAreas.map((e) => ChecklistArea.fromJson(e as Map<String, dynamic>)).toList());
        }

        final rawChecklists = decoded['checklists'] as List<dynamic>? ?? [];
        if (rawChecklists.isNotEmpty) {
          _checklists = rawChecklists.map((e) => Checklist.fromJson(e as Map<String, dynamic>)).toList();
          debugPrint('[ChecklistService] Loaded ${_checklists.length} checklists from cache');
        } else {
          _checklists = [];
        }
      } else {
        _checklists = [];
      }
    } catch (e) {
      debugPrint('[ChecklistService] Error loading cache: $e');
      _checklists = [];
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> syncCatalog() async {
    if (_syncFuture != null) return _syncFuture;
    
    _syncFuture = _performSyncCatalog().then((_) => _syncFuture = null);
    return _syncFuture;
  }

  Future<void> _performSyncCatalog() async {
    try {
      debugPrint('[SYNC] Starting catalog sync...');
      final json = await _api.getJson('/catalog', query: {
        'farmId': MorroApiConfig.farmId,
      });

      final rawAreas = json['areas'] as List<dynamic>? ?? [];
      final rawChecklists = json['checklists'] as List<dynamic>? ?? [];
      final rawQuestions = json['questions'] as List<dynamic>? ?? [];

      if (rawAreas.isNotEmpty) {
        final areas = rawAreas.map((e) => ChecklistArea.fromJson(e as Map<String, dynamic>)).toList();
        ChecklistArea.setAreas(areas);
      }

      if (rawChecklists.isNotEmpty) {
        // Parse all questions
        final allQuestions = rawQuestions
            .map((e) => ChecklistQuestion.fromJson(e as Map<String, dynamic>))
            .toList();

        // Group questions by checklistId for efficient lookup
        final questionsByChecklist = <String, List<ChecklistQuestion>>{};
        for (var q in allQuestions) {
          final rqMatch = rawQuestions.firstWhere(
            (rq) => rq['id'] == q.id,
            orElse: () => null,
          );
          final checklistId = rqMatch != null ? rqMatch['checklistId'] as String? : null;
          if (checklistId != null) {
            questionsByChecklist.putIfAbsent(checklistId, () => []).add(q);
          }
        }

        // Parse checklists and attach their questions
        _checklists = rawChecklists.map((c) {
          final map = c as Map<String, dynamic>;
          final id = map['id'] as String;
          final base = Checklist.fromJson(map);
          
          return Checklist(
            id: base.id,
            areaId: base.areaId,
            name: base.name,
            simpleName: base.simpleName,
            description: base.description,
            estimatedMinutes: base.estimatedMinutes,
            icon: base.icon,
            version: base.version,
            questions: questionsByChecklist[id] ?? [],
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
          );
        }).toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, jsonEncode({
          'areas': rawAreas,
          'checklists': _checklists.map((e) => e.toJson()).toList(),
        }));
        debugPrint('[SYNC] Catalog updated: ${_checklists.length} checklists, ${rawAreas.length} areas');
      }
    } catch (e) {
      debugPrint('[SYNC] Catalog sync failed: $e');
    }
  }

  List<Checklist> getChecklistsByArea(String areaId) {
    return _checklists.where((c) => c.areaId == areaId).toList();
  }

  Checklist? getChecklistById(String id) {
    try {
      return _checklists.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
