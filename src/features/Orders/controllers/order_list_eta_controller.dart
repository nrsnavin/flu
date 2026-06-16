import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';

/// Compact ETA summary for a single order row — what the list chip needs.
class OrderEtaSummary {
  final DateTime expectedDate;
  final int workingDays;
  final bool late;
  final int lateWorkingDays;
  final int posteriorElastics;   // how many pairs used learned posterior
  final int totalElastics;       // total pairs scored — denominator for the badge

  const OrderEtaSummary({
    required this.expectedDate,
    required this.workingDays,
    required this.late,
    required this.lateWorkingDays,
    required this.posteriorElastics,
    required this.totalElastics,
  });

  factory OrderEtaSummary.fromJson(Map<String, dynamic> j) {
    final sources = (j['rateSources'] as Map?) ?? const {};
    int sum(String k) => (sources[k] as num?)?.toInt() ?? 0;
    return OrderEtaSummary(
      expectedDate:    DateTime.parse(j['expectedDate'].toString()),
      workingDays:     (j['workingDays']     as num?)?.toInt() ?? 0,
      late:            j['late'] == true,
      lateWorkingDays: (j['lateWorkingDays'] as num?)?.toInt() ?? 0,
      posteriorElastics: sum('posterior'),
      totalElastics:
          sum('posterior') + sum('plant') + sum('coldstart') + sum('missing'),
    );
  }
}

/// Drives the per-row ETA chip on the order list. Fetches ETAs for
/// many orders in one bulk request after the list loads. Lives
/// alongside the OrderListController so a status-tab change can
/// re-fetch only the ETAs that matter.
class OrderListEtaController extends GetxController {
  final byOrderId = <String, OrderEtaSummary>{}.obs;
  final loading   = false.obs;

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/order',
  );

  /// Trigger a bulk fetch for the visible set of orders. Filters to
  /// in-flight statuses before hitting the network so we don't ask
  /// the backend for ETAs that'll come back NOT_RUNNING anyway.
  Future<void> fetchForOrders(
    List<({String id, String status})> orders,
  ) async {
    final ids = [
      for (final o in orders)
        if (o.status == 'Approved' || o.status == 'InProgress') o.id,
    ];
    if (ids.isEmpty) {
      byOrderId.clear();
      return;
    }
    loading.value = true;
    try {
      // Backend caps at 50 per call — chunk if the visible list is bigger.
      final all = <String, OrderEtaSummary>{};
      for (var i = 0; i < ids.length; i += 50) {
        final chunk = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
        final res = await _dio.post('/running-eta-bulk', data: {'orderIds': chunk});
        final data = res.data is Map ? res.data as Map<String, dynamic> : const {};
        final etas = (data['etas'] as Map?) ?? const {};
        etas.forEach((k, v) {
          if (v is Map && v['ok'] == true) {
            all[k.toString()] =
                OrderEtaSummary.fromJson(Map<String, dynamic>.from(v));
          }
        });
      }
      byOrderId.assignAll(all);
    } on DioException catch (_) {
      // Silent — the chip is decorative; surfacing an error toast on
      // the list page would be more disruptive than helpful.
    } catch (_) {
      // Same.
    } finally {
      loading.value = false;
    }
  }

  void clear() => byOrderId.clear();
}
