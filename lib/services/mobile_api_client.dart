import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class MobileApiError {
  final String code;
  final String detail;
  final String? field;

  const MobileApiError({required this.code, required this.detail, this.field});

  factory MobileApiError.fromJson(Map<String, dynamic> json) => MobileApiError(
    code: (json['code'] as String?) ?? 'unknown',
    detail: (json['detail'] as String?) ?? 'Erro desconhecido',
    field: json['field'] as String?,
  );
}

@immutable
class MobileApiException implements Exception {
  final int statusCode;
  final String message;
  final List<MobileApiError> errors;

  const MobileApiException({
    required this.statusCode,
    required this.message,
    this.errors = const [],
  });

  @override
  String toString() => 'MobileApiException($statusCode): $message';
}

@immutable
class MobileApiEnvelope<T> {
  final bool success;
  final T? data;
  final String? message;
  final List<MobileApiError> errors;

  const MobileApiEnvelope({
    required this.success,
    required this.data,
    required this.message,
    required this.errors,
  });
}

/// Minimal HTTP client for Fazenda Morro do Peão Mobile API v1.
///
/// - Uses `Authorization: Bearer <apiKey>`.
/// - Expects JSON envelope `{success,data,message,errors}`.
///
/// IMPORTANT: This client never logs the API key.
class MobileApiClient {
  final String apiBaseUrl;
  final String apiKey;
  final String? employeeCode;
  final Duration requestTimeout;
  final Duration uploadTimeout;
  final http.Client _http;

  MobileApiClient({
    required this.apiBaseUrl,
    required this.apiKey,
    this.employeeCode,
    this.requestTimeout = const Duration(seconds: 30),
    this.uploadTimeout = const Duration(seconds: 120),
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri buildUri(String path, [Map<String, String>? query]) {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath').replace(queryParameters: query);
  }

  Map<String, String> _headersJson() {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    if (employeeCode != null && employeeCode!.isNotEmpty) {
      h['X-Employee-Code'] = employeeCode!;
    }
    return h;
  }

  Map<String, String> _headersAcceptJson() {
    final h = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    if (employeeCode != null && employeeCode!.isNotEmpty) {
      h['X-Employee-Code'] = employeeCode!;
    }
    return h;
  }

  Future<MobileApiEnvelope<T>> getJson<T>({
    required String path,
    Map<String, String>? query,
    required T Function(dynamic json) decodeData,
  }) async {
    final res = await _http
        .get(buildUri(path, query), headers: _headersAcceptJson())
        .timeout(requestTimeout);
    return _decodeEnvelope<T>(res, decodeData: decodeData);
  }

  Future<MobileApiEnvelope<T>> postJson<T>({
    required String path,
    Map<String, String>? query,
    required Object body,
    required String idempotencyKey,
    required T Function(dynamic json) decodeData,
  }) async {
    final headers = _headersJson();
    headers['Idempotency-Key'] = idempotencyKey;
    final res = await _http
        .post(buildUri(path, query), headers: headers, body: jsonEncode(body))
        .timeout(requestTimeout);
    return _decodeEnvelope<T>(res, decodeData: decodeData);
  }

  Future<MobileApiEnvelope<T>> patchJson<T>({
    required String path,
    Map<String, String>? query,
    required Object body,
    required String idempotencyKey,
    required T Function(dynamic json) decodeData,
  }) async {
    final headers = _headersJson();
    headers['Idempotency-Key'] = idempotencyKey;
    final res = await _http
        .patch(buildUri(path, query), headers: headers, body: jsonEncode(body))
        .timeout(requestTimeout);
    return _decodeEnvelope<T>(res, decodeData: decodeData);
  }

  /// Multipart endpoint used for:
  /// - complete-with-evidence
  /// - occurrences attachments
  ///
  /// Do not set Content-Type manually; http will set the boundary.
  Future<MobileApiEnvelope<T>> postMultipart<T>({
    required String path,
    required String idempotencyKey,
    required List<MapEntry<String, String>> fields,
    List<http.MultipartFile> files = const [],
    required T Function(dynamic json) decodeData,
  }) async {
    final req = http.MultipartRequest('POST', buildUri(path));
    req.headers.addAll(_headersAcceptJson());
    req.headers['Idempotency-Key'] = idempotencyKey;

    // `http.MultipartRequest.fields` is a Map and does not support repeated keys.
    // The Morro do Peão API requires repeated keys for arrays (e.g., `photos` +
    // `photo_question_ids` per file). We therefore:
    // - send unique text fields via `req.fields` (standard form field)
    // - send repeated keys as multipart *text files* to preserve ordering
    final counts = <String, int>{};
    for (final f in fields) {
      counts[f.key] = (counts[f.key] ?? 0) + 1;
    }
    for (final f in fields) {
      if ((counts[f.key] ?? 0) <= 1) {
        req.fields[f.key] = f.value;
      } else {
        req.files.add(http.MultipartFile.fromString(f.key, f.value));
      }
    }

    req.files.addAll(files);
    final streamed = await req.send().timeout(uploadTimeout);
    final res = await http.Response.fromStream(streamed).timeout(requestTimeout);
    return _decodeEnvelope<T>(res, decodeData: decodeData);
  }

  Future<Uint8List> getBinaryAbsoluteUrl(String url) async {
    final uri = Uri.parse(url);
    final res = await _http
        .get(uri, headers: {'Authorization': 'Bearer $apiKey'})
        .timeout(requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    throw MobileApiException(
      statusCode: res.statusCode,
      message: 'Falha ao baixar arquivo (${res.statusCode}).',
    );
  }

  MobileApiEnvelope<T> _decodeEnvelope<T>(
    http.Response res, {
    required T Function(dynamic json) decodeData,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      throw MobileApiException(
        statusCode: res.statusCode,
        message: 'Resposta inválida do servidor (JSON).',
      );
    }

    if (decoded is! Map) {
      throw MobileApiException(
        statusCode: res.statusCode,
        message: 'Resposta inválida do servidor (envelope).',
      );
    }

    final map = decoded.cast<String, dynamic>();
    final success = (map['success'] as bool?) ?? false;
    final message = map['message'] as String?;
    final rawErrors = map['errors'];
    final errors = <MobileApiError>[];
    if (rawErrors is List) {
      for (final e in rawErrors) {
        if (e is Map<String, dynamic>) {
          errors.add(MobileApiError.fromJson(e));
        } else if (e is Map) {
          errors.add(MobileApiError.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

    if (!success) {
      throw MobileApiException(
        statusCode: res.statusCode,
        message:
            message ??
            (errors.isNotEmpty ? errors.first.detail : 'Falha na requisição.'),
        errors: errors,
      );
    }

    final data = decodeData(map['data']);
    return MobileApiEnvelope<T>(
      success: true,
      data: data,
      message: message,
      errors: errors,
    );
  }

  void dispose() {
    _http.close();
  }
}
