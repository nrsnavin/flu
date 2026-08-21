import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  DashboardController
//  Fetches the consolidated KPI roll-up from the backend so the
//  admin home renders in one round-trip, plus a tiny second call
//  for the count of shifts pending admin verification.
// ══════════════════════════════════════════════════════════════
class DashboardController extends GetxController {
  final loading  = false.obs;
  final errorMsg = Rxn<String>();

  final openJobs      = 0.obs;
  final pendingLeaves = 0.obs;
  final pendingShifts = 0.obs;

  final attTotalMarked    = 0.obs;
  final attTotalEmployees = 0.obs;
  final attUnmarked       = 0.obs;
  final attPct            = 0.obs;
  final attPresent        = 0.obs;
  final attLate           = 0.obs;
  final attHalfDay        = 0.obs;
  final attAbsent         = 0.obs;
  final attOnLeave        = 0.obs;

  final lowStockCount = 0.obs;
  final lowStockItems = <Map<String, dynamic>>[].obs;

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/dashboard',
  );
  // Pending-shifts count is on the shift router — separate client so
  // we hit the right base URL without changing the existing /kpis call.
  final _shiftDio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/shift',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    try {
      loading.value  = true;
      errorMsg.value = null;

      // Fetch the consolidated KPIs and the pending-shifts count in
      // parallel. Pending-shifts failure must not block the rest of
      // the dashboard — catch separately.
      final results = await Future.wait([
        _dio.get('/kpis'),
        _shiftDio.get('/pending-verification').catchError((_) => null),
      ]);

      final kpiRes = results[0]!;
      final data   = (kpiRes.data['data'] as Map?) ?? {};

      openJobs.value      = (data['openJobs']      as num?)?.toInt() ?? 0;
      pendingLeaves.value = (data['pendingLeaves'] as num?)?.toInt() ?? 0;

      final low = (data['lowStock'] as Map?) ?? {};
      lowStockCount.value = (low['count'] as num?)?.toInt() ?? 0;
      lowStockItems.value =
          List<Map<String, dynamic>>.from((low['items'] as List?) ?? []);

      final att = (data['attendanceToday'] as Map?) ?? {};
      final breakdown = (att['breakdown'] as Map?) ?? {};
      attTotalMarked.value    = (att['totalMarked']    as num?)?.toInt() ?? 0;
      attTotalEmployees.value = (att['totalEmployees'] as num?)?.toInt() ?? 0;
      attUnmarked.value       = (att['unmarked']       as num?)?.toInt() ?? 0;
      attPct.value            = (att['attendancePct'] as num?)?.toInt() ?? 0;
      attPresent.value  = (breakdown['present']  as num?)?.toInt() ?? 0;
      attLate.value     = (breakdown['late']     as num?)?.toInt() ?? 0;
      attHalfDay.value  = (breakdown['half_day'] as num?)?.toInt() ?? 0;
      attAbsent.value   = (breakdown['absent']   as num?)?.toInt() ?? 0;
      attOnLeave.value  = (breakdown['on_leave'] as num?)?.toInt() ?? 0;

      final shiftsRes = results[1];
      if (shiftsRes != null) {
        final list = (shiftsRes.data['shifts'] as List?) ??
            (shiftsRes.data['data'] as List?) ?? [];
        pendingShifts.value = list.length;
      }
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load KPIs';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}
