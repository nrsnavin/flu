// ══════════════════════════════════════════════════════════════
//  PRODUCTION CONTROLLER
//  File: lib/src/features/production/controllers/production_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/productionBrief.dart';


// ── Shared Dio instance ───────────────────────────────────────
final _dio = Dio(BaseOptions(
  baseUrl:         'http://13.233.117.153:2701/api/v2/production',
  connectTimeout:  const Duration(seconds: 12),
  receiveTimeout:  const Duration(seconds: 12),
));

// ══════════════════════════════════════════════════════════════
//  PRODUCTION RANGE CONTROLLER
//  Manages the date-range picker + daily list
// ══════════════════════════════════════════════════════════════
class ProductionRangeController extends GetxController {
  // ── State ──────────────────────────────────────────────────
  final isLoading   = false.obs;
  final errorMsg    = Rxn<String>();
  final dailyList   = <DailyProduction>[].obs;

  // Selected date range (default: last 7 days)
  final startDate   = Rxn<DateTime>();
  final endDate     = Rxn<DateTime>();

  // Expanded day (which date is showing its shift cards)
  final expandedDate = RxnString();

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    // Default range: last 7 days
    final now = DateTime.now();
    endDate.value   = DateTime(now.year, now.month, now.day);
    startDate.value = endDate.value!.subtract(const Duration(days: 6));
    fetchRange();
  }

  // ── API call ───────────────────────────────────────────────
  Future<void> fetchRange() async {
    if (startDate.value == null || endDate.value == null) return;

    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get('/date-range', queryParameters: {
        'startDate': _fmt(startDate.value!),
        'endDate':   _fmt(endDate.value!),
      });
      final raw = (res.data['data'] as List<dynamic>?) ?? [];
      dailyList.value = raw
          .map((e) => DailyProduction.fromJson(e as Map<String,dynamic>))
          .toList();
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString()
          ?? 'Failed to fetch production data';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Date selection ─────────────────────────────────────────
  void setDateRange(DateTime start, DateTime end) {
    startDate.value = start;
    endDate.value   = end;
    expandedDate.value = null;
    fetchRange();
  }

  void toggleDate(String date) {
    expandedDate.value = expandedDate.value == date ? null : date;
  }

  // ── Quick range presets ────────────────────────────────────
  void applyPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case 'today':
        setDateRange(today, today);
      case 'week':
        setDateRange(today.subtract(const Duration(days: 6)), today);
      case 'month':
        setDateRange(DateTime(now.year, now.month, 1), today);
      case 'last30':
        setDateRange(today.subtract(const Duration(days: 29)), today);
    }
  }

  // ── Computed stats for the range ──────────────────────────
  int get rangeTotalProduction =>
      dailyList.fold(0, (s, d) => s + d.totalProduction);
  int get rangeActiveDays =>
      dailyList.where((d) => d.hasData).length;
  double get rangeAvgEfficiency {
    final active = dailyList.where((d) => d.hasData).toList();
    if (active.isEmpty) return 0;
    return active.fold(0.0, (s, d) => s + d.efficiency) / active.length;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

// ══════════════════════════════════════════════════════════════
//  SHIFT DETAIL CONTROLLER
//  Fetches full details for one shift plan
// ══════════════════════════════════════════════════════════════
class ShiftDetailController extends GetxController {
  final String shiftPlanId;
  ShiftDetailController({required this.shiftPlanId});

  // ── State ──────────────────────────────────────────────────
  final isLoading  = true.obs;
  final errorMsg   = Rxn<String>();
  final detail     = Rxn<ShiftPlanDetail>();

  // Filter/sort
  final sortBy         = 'rowIndex'.obs; // rowIndex | production | efficiency
  final filterStatus   = 'all'.obs;      // all | completed | in_progress | open

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  // ── API call ───────────────────────────────────────────────
  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get('/shift-detail/$shiftPlanId');
      detail.value = ShiftPlanDetail.fromJson(
          res.data['data'] as Map<String,dynamic>);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString()
          ?? 'Failed to load shift detail';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Sorted + filtered machine list ─────────────────────────
  List<MachineShiftDetail> get filteredMachines {
    if (detail.value == null) return [];
    var list = [...detail.value!.machines];

    // Filter
    if (filterStatus.value != 'all') {
      list = list.where((m) => m.status == filterStatus.value).toList();
    }

    // Sort
    switch (sortBy.value) {
      case 'production':
        list.sort((a, b) => b.production.compareTo(a.production));
      case 'efficiency':
        list.sort((a, b) => b.efficiency.compareTo(a.efficiency));
      default:
        list.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    }
    return list;
  }

  void changeSort(String by)    => sortBy.value = by;
  void changeFilter(String val) => filterStatus.value = val;
}