import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

const _kBase = "http://13.233.117.153:2701/api/v2/dashboard";

// ══════════════════════════════════════════════════════════════
//  DashboardController
//  Fetches the consolidated KPI roll-up from the backend so the
//  admin home renders in one round-trip.
// ══════════════════════════════════════════════════════════════
class DashboardController extends GetxController {
  final loading  = false.obs;
  final errorMsg = Rxn<String>();

  final openJobs      = 0.obs;
  final pendingLeaves = 0.obs;

  // Attendance roll-up for today
  final attTotalMarked    = 0.obs;
  final attTotalEmployees = 0.obs;
  final attUnmarked       = 0.obs;
  final attPct            = 0.obs;
  final attPresent        = 0.obs;
  final attLate           = 0.obs;
  final attHalfDay        = 0.obs;
  final attAbsent         = 0.obs;
  final attOnLeave        = 0.obs;

  // Low-stock roll-up
  final lowStockCount = 0.obs;
  final lowStockItems = <Map<String, dynamic>>[].obs;

  final _dio = Dio(BaseOptions(
    baseUrl: _kBase,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    try {
      loading.value  = true;
      errorMsg.value = null;
      final res = await _dio.get('/kpis');
      final data = (res.data['data'] as Map?) ?? {};

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
