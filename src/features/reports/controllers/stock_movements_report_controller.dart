import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  StockMovementsReportController
//
//  Mobile summary of the Stock movement ledger:
//    GET /api/v2/reports/stock-movements?preset=&groupBy=&compare=true
//
//  Raw-material inward/outward/net over a period. Read-only companion
//  to the full web report.
// ══════════════════════════════════════════════════════════════
class StockMovementsReportController extends GetxController {
  final summary    = Rxn<Map<String, dynamic>>();
  final comparison = Rxn<Map<String, dynamic>>();
  final rows       = <Map<String, dynamic>>[].obs;
  final series     = <Map<String, dynamic>>[].obs;
  final loading    = false.obs;
  final errorMsg   = Rxn<String>();

  final preset  = 'month'.obs;
  final groupBy = 'material'.obs;

  static const presets  = ['today', 'week', 'month', 'fy'];
  static const groupBys = ['material', 'day'];

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
        '/reports/stock-movements',
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
          'Failed to load movement ledger';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  num get inQty  => (summary.value?['inQty'] as num?) ?? 0;
  num get outQty => (summary.value?['outQty'] as num?) ?? 0;
  num get net    => (summary.value?['net'] as num?) ?? 0;
}
