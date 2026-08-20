import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/service_analytics.dart';

// ══════════════════════════════════════════════════════════════
//  SERVICE SPEND AND THE PATTERNS WORTH CHECKING
//
//  The phone already had predictive health, maintenance-due and the
//  AI health advice. What it did not have was the money: what the
//  floor costs to keep running, which machines eat the most of it,
//  and the patterns in the service history that are worth a look.
//
//  ── Read-only, and that is the point ───────────────────────────
//  Dismissing a finding is a judgement recorded against somebody's
//  work, with a written reason, and it suppresses that pattern for 90
//  days. That belongs where the person can sit with it, not on a
//  phone between two machines. The web keeps the dismiss action; this
//  shows what there is to see.
// ══════════════════════════════════════════════════════════════

String analyticsMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

bool isForbidden(Object e) =>
    e is DioException && e.response?.statusCode == 403;

class ServiceAnalyticsApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/machine');

  /// Plant-wide: spend, findings, costliest machines.
  static Future<ServiceAnalytics> plant({int days = 365}) async {
    final res = await _dio.get('/service-analytics',
        queryParameters: {'days': days});
    return ServiceAnalytics.fromJson(res.data as Map<String, dynamic>);
  }

  /// One machine's spend over the same window.
  static Future<ServiceSpend> machineSpend(String machineId,
      {int days = 365}) async {
    final res = await _dio.get('/service-analytics/$machineId',
        queryParameters: {'days': days});
    return ServiceSpend.fromJson(
        Map<String, dynamic>.from(res.data['spend'] as Map));
  }

  /// One machine's output, month by month, over the same window — so
  /// the two charts can be read against each other.
  static Future<ProductionSeries> production(String machineId,
      {int days = 365}) async {
    final res = await _dio.get('/production-series/$machineId',
        queryParameters: {'days': days});
    return ProductionSeries.fromJson(res.data as Map<String, dynamic>);
  }
}

class ServiceAnalyticsController extends GetxController {
  final data = Rxn<ServiceAnalytics>();
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final days = 365.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      data.value = await ServiceAnalyticsApi.plant(days: days.value);
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to machine analytics.'
          : analyticsMessage(e, 'Could not load service analytics');
    } finally {
      isLoading.value = false;
    }
  }

  void setWindow(int d) {
    days.value = d;
    fetch();
  }
}

/// Spend and output for ONE machine, fetched together so the two
/// charts always cover the same months.
class MachineTrendController extends GetxController {
  MachineTrendController(this.machineId);

  final String machineId;

  final spend = Rxn<ServiceSpend>();
  final production = Rxn<ProductionSeries>();
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final days = 365.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      // Together, not in sequence: two round trips on a mill connection
      // is the difference between a screen that opens and one somebody
      // backs out of.
      final results = await Future.wait([
        ServiceAnalyticsApi.machineSpend(machineId, days: days.value),
        ServiceAnalyticsApi.production(machineId, days: days.value),
      ]);
      spend.value = results[0] as ServiceSpend;
      production.value = results[1] as ProductionSeries;
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to machine analytics.'
          : analyticsMessage(e, 'Could not load this machine\'s trend');
    } finally {
      isLoading.value = false;
    }
  }
}
