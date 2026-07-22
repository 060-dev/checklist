import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class ApiConfig {
  final String apiBaseUrl;
  final String apiKey;
  final int requestTimeoutSeconds;
  final int uploadTimeoutSeconds;

  const ApiConfig({required this.apiBaseUrl, required this.apiKey, required this.requestTimeoutSeconds, required this.uploadTimeoutSeconds});
}

/// Secure storage for Mobile API v1 configuration.
///
/// - Uses Keychain/Keystore where supported.
/// - On unsupported platforms, calls may throw; callers must handle.
class ApiConfigStore {
  static final ApiConfigStore instance = ApiConfigStore._();
  ApiConfigStore._();

  static const _kBaseUrl = 'mobile_api_base_url_v1';
  static const _kApiKey = 'mobile_api_key_v1';
  static const _kReqTimeout = 'mobile_api_request_timeout_seconds_v1';
  static const _kUploadTimeout = 'mobile_api_upload_timeout_seconds_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<ApiConfig?> load() async {
    final baseUrl = (await _storage.read(key: _kBaseUrl))?.trim() ?? '';
    final apiKey = (await _storage.read(key: _kApiKey))?.trim() ?? '';
    if (baseUrl.isEmpty || apiKey.isEmpty) return null;

    final reqRaw = (await _storage.read(key: _kReqTimeout))?.trim() ?? '';
    final uploadRaw = (await _storage.read(key: _kUploadTimeout))?.trim() ?? '';

    final req = int.tryParse(reqRaw) ?? 30;
    final upload = int.tryParse(uploadRaw) ?? 120;

    return ApiConfig(apiBaseUrl: baseUrl, apiKey: apiKey, requestTimeoutSeconds: req, uploadTimeoutSeconds: upload);
  }

  Future<void> save(ApiConfig cfg) async {
    await _storage.write(key: _kBaseUrl, value: cfg.apiBaseUrl.trim());
    await _storage.write(key: _kApiKey, value: cfg.apiKey.trim());
    await _storage.write(key: _kReqTimeout, value: cfg.requestTimeoutSeconds.toString());
    await _storage.write(key: _kUploadTimeout, value: cfg.uploadTimeoutSeconds.toString());
  }

  Future<void> clear() async {
    await _storage.delete(key: _kBaseUrl);
    await _storage.delete(key: _kApiKey);
    await _storage.delete(key: _kReqTimeout);
    await _storage.delete(key: _kUploadTimeout);
  }
}
