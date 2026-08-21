import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../Orders/models/elasticLite.dart' show CustomerLite;

// ══════════════════════════════════════════════════════════════
//  SEARCH THE CUSTOMER MASTER
//
//  Pulled out of AddOrderController, which owned the only copy. It
//  is a GET and a map — nothing about it belongs to raising an
//  order — and the sample form needs the same list. Copying it would
//  have given the two screens their own idea of what a customer
//  search returns, which is how they start disagreeing about
//  archived customers, or about the page size.
//
//  Returns [] on failure rather than throwing. The caller is a
//  picker sheet with a search box: an empty result reads as "no
//  matches", the user types something else, and nothing is lost. A
//  thrown exception there would close the sheet and discard the form
//  behind it.
// ══════════════════════════════════════════════════════════════

final _dio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

Future<List<CustomerLite>> searchCustomerMaster(String query) async {
  try {
    final res = await _dio.get(
      '/customer/all-customers',
      queryParameters: query.trim().isEmpty
          ? <String, dynamic>{}
          : <String, dynamic>{'search': query.trim()},
    );
    final list = res.data['customers'] as List? ?? [];
    return list
        .whereType<Map>()
        .where((c) => c['_id'] != null && c['name'] != null)
        .map((c) => CustomerLite(
              id: c['_id'].toString(),
              name: c['name'].toString(),
            ))
        .toList();
  } on DioException {
    return const [];
  } catch (_) {
    return const [];
  }
}
