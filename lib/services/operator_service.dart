import 'package:flutter/foundation.dart';
import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/services/morro_api_client.dart';
import 'package:morro_do_peo/services/morro_api_config.dart';

class OperatorService {
  static final OperatorService _instance = OperatorService._internal();
  factory OperatorService() => _instance;
  OperatorService._internal();

  final MorroApiClient _api = MorroApiClient();

  Future<List<Operator>> listOperators({bool? active}) async {
    try {
      final json = await _api.getJson('/operators', query: {
        'farmId': MorroApiConfig.farmId,
        if (active != null) 'active': active.toString(),
      });

      final raw = (json['operators'] ?? json['data'] ?? json['items'] ?? json['results']);
      if (raw is List) {
        return raw.whereType<Map>().map((e) => Operator.fromJson(e.cast<String, dynamic>())).where((o) => o.id.isNotEmpty).toList();
      }
      if (json.isNotEmpty) {
        // Backend pode retornar diretamente uma lista como JSON; nosso client encapsula em {'data': ...}
        // então tentamos ler daqui.
        final d = json['data'];
        if (d is List) {
          return d.whereType<Map>().map((e) => Operator.fromJson(e.cast<String, dynamic>())).where((o) => o.id.isNotEmpty).toList();
        }
      }
      return const <Operator>[];
    } catch (e) {
      debugPrint('Failed to load operators: $e');
      return const <Operator>[];
    }
  }
}
