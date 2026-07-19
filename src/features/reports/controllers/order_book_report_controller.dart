import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  OrderBookReportController
//
//  Mobile summary of the Order book & fulfillment report:
//    GET /api/v2/reports/order-book?preset=&groupBy=&compare=true
//
//  Order intake + pending + on-time delivery over a period. Read-only
//  companion to the full web report.
// ══════════════════════════════════════════════════════════════
class OrderBookReportController extends GetxController {
  final summary    = Rxn<Map<String, dynamic>>();
  final comparison = Rxn<Map<String, dynamic>>();
  final rows       = <Map<String, dynamic>>[].obs;
  final loading    = false.obs;
  final errorMsg   = Rxn<String>();

  final preset  = 'month'.obs;
  final groupBy = 'customer'.obs;

  static const presets  = ['today', 'week', 'month', 'fy'];
  static const groupBys = ['customer', 'status', 'supplyMonth'];

  final _dio = ApiClient.buildClient(
    baseUrl: ApiConfig.baseUrl,
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
    ever(preset, (_) => fetch());
    ever(groupBy, (_) => fetch());
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get(
        '/reports/order-book',
        queryParameters: {
          'preset': preset.value,
          'groupBy': groupBy.value,
          'compare': true,
        },
      );
      final report = (res.data is Map ? res.data['report'] : null) as Map? ?? const {};
      summary.value = report['summary'] is Map
          ? Map<String, dynamic>.from(report['summary'] as Map)
          : null;
      comparison.value = report['comparison'] is Map
          ? Map<String, dynamic>.from(report['comparison'] as Map)
          : null;
      final raw = (report['rows'] as List?) ?? const [];
      rows.value = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on DioException catch (e) {
      errorMsg.value = (e.response?.data is Map
              ? e.response?.data['message']?.toString()
              : null) ??
          'Failed to load order book';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  num get orders     => (summary.value?['orders'] as num?) ?? 0;
  num get orderedQty => (summary.value?['orderedQty'] as num?) ?? 0;
  num get pendingQty => (summary.value?['pendingQty'] as num?) ?? 0;
  num get openOrders => (summary.value?['openOrders'] as num?) ?? 0;
  num get overdueOrders => (summary.value?['overdueOrders'] as num?) ?? 0;
  // null-safe: on-time % is null when no dispatches were considered.
  num? get onTimePct => summary.value?['onTimePct'] as num?;

  num? get ordersDelta {
    final d = comparison.value?['delta'];
    if (d is Map && d['orders'] is num) return d['orders'] as num;
    return null;
  }
}
