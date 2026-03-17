// ══════════════════════════════════════════════════════════════
//  ANALYTICS CONTROLLER  v2
//  File: lib/src/features/production/controllers/analytics_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/analytics_model.dart';


final _dio = Dio(BaseOptions(
  baseUrl:        'http://13.233.117.153:2701/api/v2/production',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
));

enum AnalyticsTab { overview, byMachine, byEmployee, arena, anomalies }

class AnalyticsController extends GetxController {
  // ── State ──────────────────────────────────────────────────
  final isLoading  = false.obs;
  final errorMsg   = Rxn<String>();
  final data       = Rxn<AnalyticsData>();

  // ── Date range ────────────────────────────────────────────
  late final Rx<DateTime> startDate;
  late final Rx<DateTime> endDate;

  // ── Filters ───────────────────────────────────────────────
  final shiftFilter      = 'all'.obs;
  final activeTab        = AnalyticsTab.overview.obs;
  final filterMachineId  = RxnString();
  final filterEmployeeId = RxnString();
  final anomalySeverity  = 'all'.obs;

  // ── Expanded XP breakdown card ────────────────────────────
  final expandedXpId = RxnString();

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    final now  = DateTime.now();
    final t    = DateTime(now.year, now.month, now.day);
    endDate    = t.obs;
    startDate  = t.subtract(const Duration(days: 29)).obs;
    fetch();
  }

  // ── API ────────────────────────────────────────────────────
  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final params = <String, dynamic>{
        'startDate': _fmt(startDate.value),
        'endDate':   _fmt(endDate.value),
        'shift':     shiftFilter.value,
      };
      if (filterMachineId.value  != null) params['machineId']  = filterMachineId.value;
      if (filterEmployeeId.value != null) params['employeeId'] = filterEmployeeId.value;

      final res = await _dio.get('/analytics', queryParameters: params);
      data.value = AnalyticsData.fromJson(res.data['data'] as Map<String,dynamic>);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString() ?? 'Failed to fetch analytics';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Date helpers ──────────────────────────────────────────
  void setDateRange(DateTime s, DateTime e) {
    startDate.value = s;
    endDate.value   = e;
    fetch();
  }

  void applyPreset(String preset) {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    switch (preset) {
      case 'today':   setDateRange(today, today);
      case 'week':    setDateRange(today.subtract(const Duration(days: 6)), today);
      case 'month':   setDateRange(today.subtract(const Duration(days: 29)), today);
      case 'quarter': setDateRange(today.subtract(const Duration(days: 89)), today);
    }
  }

  // ── Filter setters ────────────────────────────────────────
  void setShift(String s)         { shiftFilter.value = s; fetch(); }

  void drillMachine(String id) {
    filterMachineId.value  = id;
    filterEmployeeId.value = null;
    activeTab.value = AnalyticsTab.byMachine;
    fetch();
  }

  void drillEmployee(String id) {
    filterEmployeeId.value = id;
    filterMachineId.value  = null;
    activeTab.value = AnalyticsTab.byEmployee;
    fetch();
  }

  void clearMachineFilter()  { filterMachineId.value  = null; fetch(); }
  void clearEmployeeFilter() { filterEmployeeId.value = null; fetch(); }
  void clearAllFilters() {
    filterMachineId.value  = null;
    filterEmployeeId.value = null;
    shiftFilter.value      = 'all';
    fetch();
  }

  void toggleXpBreakdown(String empId) {
    expandedXpId.value = expandedXpId.value == empId ? null : empId;
  }

  // ── Computed getters ──────────────────────────────────────
  int get trendMax {
    final t = data.value?.trend ?? [];
    if (t.isEmpty) return 1;
    return t.map((p)=>p.production).reduce((a,b)=>a>b?a:b);
  }

  int get machineMax {
    final m = data.value?.byMachine ?? [];
    if (m.isEmpty) return 1;
    return m.map((m)=>m.totalProduction).reduce((a,b)=>a>b?a:b);
  }

  int get weeklyPatternMax {
    final w = data.value?.weeklyPattern ?? [];
    if (w.isEmpty) return 1;
    return w.map((p)=>p.avgProduction).reduce((a,b)=>a>b?a:b);
  }

  List<ProductionAnomaly> get filteredAnomalies {
    final all = data.value?.anomalies ?? [];
    if (anomalySeverity.value == 'all') return all;
    return all.where((a)=>a.severity==anomalySeverity.value).toList();
  }

  int get highAnomalyCount =>
      (data.value?.anomalies ?? []).where((a)=>a.isHigh).length;

  bool get hasActiveFilters =>
      filterMachineId.value != null ||
          filterEmployeeId.value != null ||
          shiftFilter.value != 'all';

  /// Top employee by XP for Arena header
  EmployeeAnalytics? get xpLeader {
    final list = data.value?.byEmployee ?? [];
    if (list.isEmpty) return null;
    return list.reduce((a,b)=>a.xp>b.xp?a:b);
  }

  /// Get level colour as Flutter Color int from hex string
  static int levelColorInt(String hex) {
    final h = hex.replaceAll('#','');
    if (h.length==6) return int.parse('FF$h', radix:16);
    return 0xFF94A3B8;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}