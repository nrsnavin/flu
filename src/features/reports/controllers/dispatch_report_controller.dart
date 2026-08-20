import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  DispatchReportController
//
//  Mobile summary of the Dispatch & customer-sales report:
//    GET /api/v2/reports/dispatch?preset=&groupBy=&compare=true
//
//  Delivery-challan value/quantity over a period (real dispatches
//  only). Read-only companion to the full web report.
// ══════════════════════════════════════════════════════════════
class DispatchReportController extends GetxController {
  final summary    = Rxn<Map<String, dynamic>>();
  final comparison = Rxn<Map<String, dynamic>>();
  final rows       = <Map<String, dynamic>>[].obs;
  final series     = <Map<String, dynamic>>[].obs;
  final loading    = false.obs;
  final errorMsg   = Rxn<String>();

  final preset  = 'month'.obs;
  final groupBy = 'customer'.obs;

  static const presets  = ['today', 'week', 'month', 'fy'];
  static const groupBys = ['customer', 'elastic', 'day'];

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
        '/reports/dispatch',
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
      // The daily points behind the chart. The server omits days on
      // which nothing happened, so buildReportBars() fills the gaps
      // before anything is drawn.
      final rawSeries = (report['series'] as List?) ?? const [];
      series.value = rawSeries
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on DioException catch (e) {
      errorMsg.value = (e.response?.data is Map
              ? e.response?.data['message']?.toString()
              : null) ??
          'Failed to load dispatch report';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  num get amount    => (summary.value?['amount'] as num?) ?? 0;
  num get quantity  => (summary.value?['quantity'] as num?) ?? 0;
  num get dcs       => (summary.value?['dcs'] as num?) ?? 0;
  num get customers => (summary.value?['customers'] as num?) ?? 0;
  num get avgRate   => (summary.value?['avgRate'] as num?) ?? 0;

  num? get amountDeltaPct {
    final d = comparison.value?['delta'];
    if (d is Map && d['amountPct'] is num) return d['amountPct'] as num;
    return null;
  }
}
