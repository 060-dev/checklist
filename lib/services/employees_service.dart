import 'package:flutter/foundation.dart';
import 'package:morro_do_peo/models/operator.dart';
import 'package:morro_do_peo/services/mobile_api_client.dart';

class EmployeesService {
  final MobileApiClient client;

  EmployeesService({required this.client});

  Future<List<Operator>> listEmployees({String? search, int page = 1, int pageSize = 100, String order = 'name_asc'}) async {
    final query = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'order': order,
      if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
    };

    final env = await client.getJson<Map<String, dynamic>>(
      path: '/employees',
      query: query,
      decodeData: (json) {
        if (json is! Map) return <String, dynamic>{};
        return json.cast<String, dynamic>();
      },
    );

    final items = env.data?['items'];
    if (items is! List) return const [];

    final list = <Operator>[];
    for (final item in items) {
      try {
        if (item is Map<String, dynamic>) {
          list.add(Operator.fromMobileApiEmployee(item));
        } else if (item is Map) {
          list.add(Operator.fromMobileApiEmployee(item.cast<String, dynamic>()));
        }
      } catch (e) {
        debugPrint('Skipping invalid employee item: $e');
      }
    }
    return list;
  }
}
