import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  ProductionReportController
//
//  Mobile summary of the Production report:
//    GET /api/v2/reports/production?preset=&groupBy=&compare=true
//
//  Returns { summary, rows, series, comparison }. This drives a
//  read-only summary screen — the full report (custom ranges, CSV,
//  print) lives on the web. Gated to production/sales/stores/accounts;
//  ApiClient.buildClient ships the cookie so it authorises.
// ══════════════════════════════════════════════════════════════
class ProductionReportController extends GetxController {
  final summary    = Rxn<Map<String, dynamic>>();
  final comparison = Rxn<Map<String, dynamic>>();
  final rows       = <Map<String, dynamic>>[].obs;
  final loading    = false.obs;
  final errorMsg   = Rxn<String>();

  final preset  = 'today'.obs;
  final groupBy = 'machine'.obs;

  static const presets  = ['today', 'week', 'month', 'fy'];
  static const groupBys = ['machine', 'shift', 'elastic', 'operator', 'day'];

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
        '/reports/production',
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
          'Failed to load production report';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  // Convenience getters with safe fallbacks for the view.
  num get meters      => (summary.value?['meters'] as num?) ?? 0;
  num get shifts      => (summary.value?['shifts'] as num?) ?? 0;
  num get avgPerShift => (summary.value?['avgPerShift'] as num?) ?? 0;
  num get wastageMeters => (summary.value?['wastageMeters'] as num?) ?? 0;
  num get wastagePct  => (summary.value?['wastagePct'] as num?) ?? 0;

  // Signed % change in meters vs the previous period, or null.
  num? get metersDeltaPct {
    final d = comparison.value?['delta'];
    if (d is Map && d['metersPct'] is num) return d['metersPct'] as num;
    return null;
  }
}
