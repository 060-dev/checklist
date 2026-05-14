import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morro_do_peo/services/morro_api_config.dart';

class MorroApiException implements Exception {
  final int? statusCode;
  final String message;
  final Object? details;

  const MorroApiException({required this.message, this.statusCode, this.details});

  @override
  String toString() => 'MorroApiException(statusCode=$statusCode, message=$message, details=$details)';
}

class MorroApiClient {
  static final MorroApiClient _instance = MorroApiClient._internal();
  factory MorroApiClient() => _instance;
  MorroApiClient._internal();

  static const _accessTokenKey = 'morro_api_access_token';
  static const _refreshTokenKey = 'morro_api_refresh_token';

  final http.Client _client = http.Client();

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final base = Uri.parse(MorroApiConfig.baseUrl);
    return base.replace(
      path: _joinPath(base.path, path),
      queryParameters: query.map((k, v) => MapEntry(k, v)).cast<String, String?>()..removeWhere((k, v) => v == null),
    );
  }

  String _joinPath(String basePath, String path) {
    final a = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
    final b = path.startsWith('/') ? path : '/$path';
    return '$a$b';
  }

  Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    } catch (e) {
      debugPrint('Failed to read access token: $e');
      return null;
    }
  }

  Future<void> setTokens({String? accessToken, String? refreshToken}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (accessToken != null) await prefs.setString(_accessTokenKey, accessToken);
      if (refreshToken != null) await prefs.setString(_refreshTokenKey, refreshToken);
    } catch (e) {
      debugPrint('Failed to persist tokens: $e');
    }
  }

  Future<Map<String, String>> _headers({Map<String, String>? extra}) async {
    final token = await getAccessToken();
    final h = <String, String>{
      'accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['authorization'] = 'Bearer $token';
    }
    if (extra != null) h.addAll(extra);
    return h;
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String?> query = const {}}) async {
    final uri = _uri(path, query);
    debugPrint('[API] GET $path');
    try {
      final resp = await _client.get(uri, headers: await _headers()).timeout(const Duration(seconds: 20));
      debugPrint('[API] ${resp.statusCode} GET $path');
      return _decodeJsonResponse(resp);
    } on TimeoutException {
      throw const MorroApiException(message: 'timeout');
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Object body,
    Map<String, String?> query = const {},
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path, query);
    debugPrint('[API] POST $path');
    try {
      final resp = await _client
          .post(
            uri,
            headers: await _headers(extra: {
              'content-type': 'application/json; charset=utf-8',
              if (headers != null) ...headers,
            }),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      debugPrint('[API] ${resp.statusCode} POST $path');
      return _decodeJsonResponse(resp);
    } on TimeoutException {
      throw const MorroApiException(message: 'timeout');
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Uint8List fileBytes,
    required String fileField,
    required String fileName,
    required String contentType,
  }) async {
    final uri = _uri(path);
    try {
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(await _headers());
      req.fields.addAll(fields);
      req.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
        contentType: http_parser.MediaType.parse(contentType),
      ));

      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final resp = await http.Response.fromStream(streamed);
      return _decodeJsonResponse(resp);
    } on TimeoutException {
      throw const MorroApiException(message: 'timeout');
    }
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response resp) {
    final status = resp.statusCode;
    final raw = utf8.decode(resp.bodyBytes);
    final isOk = status >= 200 && status < 300;
    if (raw.isEmpty) {
      if (isOk) return <String, dynamic>{};
      throw MorroApiException(statusCode: status, message: 'http_error', details: raw);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      if (isOk) return <String, dynamic>{'raw': raw};
      throw MorroApiException(statusCode: status, message: 'http_error_non_json', details: raw);
    }

    if (!isOk) {
      throw MorroApiException(statusCode: status, message: 'http_error', details: decoded);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }
}
