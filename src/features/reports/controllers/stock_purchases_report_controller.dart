import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  StockPurchasesReportController
//
//  Mobile summary of the Stock & purchases report:
//    GET /api/v2/reports/stock-purchases?preset=&groupBy=&compare=true
//
//  Raw-material stock valuation (snapshot) + windowed PO purchases.
//  Read-only companion to the full web report.
// ══════════════════════════════════════════════════════════════
class StockPurchasesReportController extends GetxController {
  final summary    = Rxn<Map<String, dynamic>>();
  final comparison = Rxn<Map<String, dynamic>>();
  final rows       = <Map<String, dynamic>>[].obs;
  final series     = <Map<String, dynamic>>[].obs;
  final loading    = false.obs;
  final errorMsg   = Rxn<String>();

  final preset  = 'month'.obs;
  final groupBy = 'material'.obs;

  static const presets  = ['today', 'week', 'month', 'fy'];
  static const groupBys = ['material', 'category', 'supplier'];

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
        '/reports/stock-purchases',
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
          'Failed to load stock report';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  num get stockValue    => (summary.value?['stockValue'] as num?) ?? 0;
  num get materials     => (summary.value?['materials'] as num?) ?? 0;
  num get lowStock      => (summary.value?['lowStock'] as num?) ?? 0;
  num get purchaseValue => (summary.value?['purchaseValue'] as num?) ?? 0;
  num get pendingValue  => (summary.value?['pendingValue'] as num?) ?? 0;
  num get pos           => (summary.value?['pos'] as num?) ?? 0;

  num? get purchaseDeltaPct {
    final d = comparison.value?['delta'];
    if (d is Map && d['purchaseValuePct'] is num) return d['purchaseValuePct'] as num;
    return null;
  }
}
