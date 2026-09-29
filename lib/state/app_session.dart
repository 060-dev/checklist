import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/models/purchase_models.dart';
import 'package:morro_do_peo/services/api_config_store.dart';
import 'package:morro_do_peo/services/local_cache_service.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';
import 'package:morro_do_peo/services/mobile_api_services.dart';

class AppSession extends ChangeNotifier {
  Operator? _selectedOperator;

  // --- Mobile API v1 configuration -----------------------------------------
  ApiConfig? _apiConfig;
  bool _loaded = false;

  // static const String _origin =
  //     'https://homolog-morro-peao.yplanejamento.com.br';
  // static const String _apiBaseUrl =
  //     'https://homolog-morro-peao.yplanejamento.com.br/api/mobile/v1';

  static const String _origin = 'https://morropeao.yplanejamento.com.br';
  static const String _apiBaseUrl =
      'https://morropeao.yplanejamento.com.br/api/mobile/v1';

  /// Environment injection (build-time), e.g.:
  /// `--dart-define=MORROPEAO_API_KEY=...`
  static const String envApiKey = String.fromEnvironment('MORROPEAO_API_KEY');

  static const String _kLastEmployeeId = 'last_employee_id_v1';
  static const String _kLastEmployeeName = 'last_employee_name_v1';
  static const String _kEmployeeCode = 'employee_code_v1';

  // --- First-time app activation (QR code / manual PIN) --------------------
  static const String _kIsActivated = 'is_activated_v1';

  bool _isActivated = false;
  String? _employeeCode;
  PurchaseContext? _purchaseContext;

  bool get isActivated => _isActivated;
  String? get employeeCode => _employeeCode;

  Operator? get selectedOperator => _selectedOperator;
  PurchaseContext? get purchaseContext => _purchaseContext;
  
  PurchaseCapabilities get purchaseCapabilities =>
      _purchaseContext?.capabilities ??
      const PurchaseCapabilities(
        createRequests: false,
        editOwnRequests: false,
        manage: false,
        viewAll: false,
        configureApprovals: false,
      );
  PurchaseAccessProfile? get purchaseAccessProfile =>
      _purchaseContext?.accessProfile;
  PurchaseUser? get purchaseCurrentUser => _purchaseContext?.currentUser;

  /// For audio URLs (which are relative to origin, not the API base URL).
  String get origin => _origin;
  String get apiBaseUrl => _apiBaseUrl;

  /// Resolution order: secure storage -> `--dart-define` -> empty (no
  /// hardcoded fallback key). An empty key means the API-driven screens are
  /// unavailable until credentials are configured.
  String get apiKey {
    final injected = envApiKey.trim();
    if (injected.isNotEmpty) return injected;

    final stored = _apiConfig?.apiKey.trim() ?? '';
    if (stored.isNotEmpty) return stored;

    return '';
  }

  int get requestTimeoutSeconds => _apiConfig?.requestTimeoutSeconds ?? 30;
  int get uploadTimeoutSeconds => _apiConfig?.uploadTimeoutSeconds ?? 120;

  bool get hasApiConfig =>
      apiBaseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  bool get isLoaded => _loaded;

  /// Restores API config (secure storage) and the last selected employee
  /// (SharedPreferences) for the API-driven flow. Safe to call more than
  /// once; only runs once.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      _apiConfig = await ApiConfigStore.instance.load();

      final injectedKey = envApiKey.trim();
      if (_apiConfig == null && injectedKey.isNotEmpty) {
        final cfg = ApiConfig(
          apiBaseUrl: _apiBaseUrl,
          apiKey: injectedKey,
          requestTimeoutSeconds: 30,
          uploadTimeoutSeconds: 120,
        );
        await ApiConfigStore.instance.save(cfg);
        _apiConfig = cfg;
      }

      final prefs = await SharedPreferences.getInstance();
      _isActivated = prefs.getBool(_kIsActivated) ?? false;
      _employeeCode = prefs.getString(_kEmployeeCode);

      final id = (prefs.getString(_kLastEmployeeId) ?? '').trim();
      final name = (prefs.getString(_kLastEmployeeName) ?? '').trim();
      if (id.isNotEmpty && name.isNotEmpty && _selectedOperator == null) {
        _selectedOperator = Operator(
          id: id,
          farmId: 'morro-do-peao',
          name: name,
          active: true,
        );
      }

      // Try to load cached purchase context
      final cachedCtx = await LocalCacheService.instance.getPurchaseContext();
      if (cachedCtx != null) {
        _purchaseContext = cachedCtx.$2;
      }

      // Fetch fresh purchase context if online
      if (_employeeCode != null && hasApiConfig) {
        unawaited(refreshPurchaseContext());
      }
    } catch (e) {
      debugPrint('AppSession ensureLoaded failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<PurchaseContext?> refreshPurchaseContext() async {
    if (_employeeCode == null || !hasApiConfig) return _purchaseContext;
    try {
      final tempClient = MobileApiClient(
        apiBaseUrl: apiBaseUrl,
        apiKey: apiKey,
        employeeCode: _employeeCode,
      );
      final api = MobileApiServices(client: tempClient);
      final ctx = await api.getPurchaseContext();
      _purchaseContext = ctx;
      await LocalCacheService.instance.savePurchaseContext(ctx);
      notifyListeners();
      return ctx;
    } catch (e) {
      debugPrint('Failed to refresh purchase context: $e');
      return _purchaseContext;
    }
  }

  void selectOperator(Operator op) {
    _selectedOperator = op;
    unawaited(_persistSelectedOperator(op));
    notifyListeners();
  }

  Future<void> _persistSelectedOperator(Operator op) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastEmployeeId, op.id);
      await prefs.setString(_kLastEmployeeName, op.name);
    } catch (e) {
      debugPrint('Failed to persist selected employee: $e');
    }
  }

  Future<void> _clearSelectedOperator() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastEmployeeId);
      await prefs.remove(_kLastEmployeeName);
    } catch (e) {
      debugPrint('Failed to clear selected employee: $e');
    }
  }

  /// Clears the selected operator, including its persisted employee prefs.
  void resetAll() {
    _selectedOperator = null;
    _employeeCode = null;
    _purchaseContext = null;
    _isActivated = false;
    unawaited(_clearSelectedOperator());
    notifyListeners();
  }

  /// Validates [rawInput] against the API.
  /// On success, persists activation and the selected operator.
  Future<bool> activateWithCode(String rawInput) async {
    if (!hasApiConfig) return false;

    final tempClient = MobileApiClient(
      apiBaseUrl: apiBaseUrl,
      apiKey: apiKey,
      employeeCode: rawInput,
    );
    final api = MobileApiServices(client: tempClient);
    final op = await api.validateEmployeeCode(rawInput);

    if (op == null) return false;

    _isActivated = true;
    _employeeCode = rawInput;
    _selectedOperator = op;

    try {
      final ctx = await api.getPurchaseContext();
      _purchaseContext = ctx;
      await LocalCacheService.instance.savePurchaseContext(ctx);
    } catch (e) {
      debugPrint('Failed to fetch purchase context during activation: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsActivated, true);
      await prefs.setString(_kEmployeeCode, rawInput);
      await _persistSelectedOperator(op);
    } catch (e) {
      debugPrint('Failed to persist activation: $e');
    }
    notifyListeners();
    return true;
  }
}
