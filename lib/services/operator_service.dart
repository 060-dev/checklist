import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/services/morro_api_client.dart';
import 'package:morro_do_peo/services/morro_api_config.dart';

class OperatorService {
  static final OperatorService _instance = OperatorService._internal();
  factory OperatorService() => _instance;
  OperatorService._internal();

  static const String _storageKey = 'cached_operators';
  final MorroApiClient _api = MorroApiClient();
  List<Operator> _operators = [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _operators = decoded.map((e) => Operator.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('[OperatorService] Loaded ${_operators.length} operators from cache');
      }
    } catch (e) {
      debugPrint('[OperatorService] Error loading cache: $e');
    } finally {
      _isInitialized = true;
    }
  }

  Future<List<Operator>> listOperators({bool? active}) async {
    if (!_isInitialized) await init();
    if (active != null) {
      return _operators.where((o) => o.active == active).toList();
    }
    return _operators;
  }

  Future<void> syncOperators() async {
    try {
      debugPrint('[SYNC] Starting operators sync...');
      final json = await _api.getJson('/operators', query: {
        'farmId': MorroApiConfig.farmId,
      });

      final raw = (json['operators'] ?? json['data'] ?? json['items'] ?? json['results']);
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (json['data'] is List) {
        items = json['data'];
      }

      if (items.isNotEmpty) {
        _operators = items.map((e) => Operator.fromJson(e.cast<String, dynamic>())).where((o) => o.id.isNotEmpty).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, jsonEncode(_operators.map((o) => o.toJson()).toList()));
        debugPrint('[SYNC] Operators updated: ${_operators.length} items');
      }
    } catch (e) {
      debugPrint('[SYNC] Operators sync failed: $e');
    }
  }
}
