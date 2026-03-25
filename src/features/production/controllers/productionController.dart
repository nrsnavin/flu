// ══════════════════════════════════════════════════════════════
//  PRODUCTION CONTROLLER
//  File: lib/src/features/production/controllers/production_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/productionBrief.dart';

// ── Shared Dio instance ───────────────────────────────────────
final _dio = Dio(BaseOptions(
  baseUrl:        'http://13.233.117.153:2701/api/v2/production',
  connectTimeout: const Duration(seconds: 12),
  receiveTimeout: const Duration(seconds: 12),
));

// ══════════════════════════════════════════════════════════════
//  BULK ENTRY MODEL
//  One per open machine — holds TextEditingControllers
//  and live meter observable for real-time total display.
// ══════════════════════════════════════════════════════════════
class BulkEntry {
  final MachineShiftDetail machine;
  final TextEditingController productionCtrl;
  final TextEditingController timerCtrl;
  final TextEditingController remarksCtrl;
  final RxInt liveMeters; // updated on every keystroke for running total

  BulkEntry(this.machine)
      : productionCtrl = TextEditingController(),
        timerCtrl      = TextEditingController(text: '00:00:00'),
        remarksCtrl    = TextEditingController(),
        liveMeters     = 0.obs;

  void dispose() {
    productionCtrl.dispose();
    timerCtrl.dispose();
    remarksCtrl.dispose();
  }

  /// Returns null if valid, or an error message.
  String? validate() {
    final v = int.tryParse(productionCtrl.text.trim());
    if (v == null || v < 0)
      return '${machine.machineNo}: enter a valid production number';
    return null;
  }

  Map<String, dynamic> toPayload() => {
    'machineId':  machine.machineId,
    'rowIndex':   machine.rowIndex,
    'production': int.parse(productionCtrl.text.trim()),
    'timer':      timerCtrl.text.trim(),
    'remarks':    remarksCtrl.text.trim(),
  };
}

// ══════════════════════════════════════════════════════════════
//  PRODUCTION RANGE CONTROLLER
// ══════════════════════════════════════════════════════════════
class ProductionRangeController extends GetxController {
  final isLoading    = false.obs;
  final errorMsg     = Rxn<String>();
  final dailyList    = <DailyProduction>[].obs;
  final startDate    = Rxn<DateTime>();
  final endDate      = Rxn<DateTime>();
  final expandedDate = RxnString();

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    endDate.value   = DateTime(now.year, now.month, now.day);
    startDate.value = endDate.value!.subtract(const Duration(days: 6));
    fetchRange();
  }

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
          .map((e) => DailyProduction.fromJson(e as Map<String, dynamic>))
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

  void setDateRange(DateTime start, DateTime end) {
    startDate.value    = start;
    endDate.value      = end;
    expandedDate.value = null;
    fetchRange();
  }

  void toggleDate(String date) =>
      expandedDate.value = expandedDate.value == date ? null : date;

  void applyPreset(String preset) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case 'today':   setDateRange(today, today); break;
      case 'week':    setDateRange(today.subtract(const Duration(days: 6)), today); break;
      case 'month':   setDateRange(DateTime(now.year, now.month, 1), today); break;
      case 'last30':  setDateRange(today.subtract(const Duration(days: 29)), today); break;
    }
  }

  int    get rangeTotalProduction => dailyList.fold(0,   (s, d) => s + d.totalProduction);
  int    get rangeActiveDays      => dailyList.where((d) => d.hasData).length;
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
//  + Bulk production entry support
// ══════════════════════════════════════════════════════════════
class ShiftDetailController extends GetxController {
  final String shiftPlanId;
  ShiftDetailController({required this.shiftPlanId});

  // ── View state ─────────────────────────────────────────────
  final isLoading    = true.obs;
  final errorMsg     = Rxn<String>();
  final detail       = Rxn<ShiftPlanDetail>();
  final sortBy       = 'rowIndex'.obs;
  final filterStatus = 'all'.obs;

  // ── Bulk entry state ───────────────────────────────────────
  final bulkEntries    = <BulkEntry>[].obs;
  final isBulkUpdating = false.obs;
  // Drives the running total shown in the bulk sheet header
  final bulkTotalMeters = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  @override
  void onClose() {
    _disposeBulkEntries();
    super.onClose();
  }

  // ── Fetch ──────────────────────────────────────────────────
  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get('/shift-detail/$shiftPlanId');
      detail.value = ShiftPlanDetail.fromJson(
          res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString()
          ?? 'Failed to load shift detail';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Sorted + filtered list ─────────────────────────────────
  List<MachineShiftDetail> get filteredMachines {
    if (detail.value == null) return [];
    var list = [...detail.value!.machines];
    if (filterStatus.value != 'all')
      list = list.where((m) => m.status == filterStatus.value).toList();
    switch (sortBy.value) {
      case 'production': list.sort((a, b) => b.production.compareTo(a.production)); break;
      case 'efficiency': list.sort((a, b) => b.efficiency.compareTo(a.efficiency)); break;
      default:           list.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    }
    return list;
  }

  void changeSort(String by)    => sortBy.value = by;
  void changeFilter(String val) => filterStatus.value = val;

  // ── Open machines (eligible for bulk entry) ────────────────
  List<MachineShiftDetail> get openMachines =>
      (detail.value?.machines ?? [])
          .where((m) => m.status == 'open')
          .toList()
        ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));

  bool get hasOpenMachines => openMachines.isNotEmpty;

  // ── Bulk entry helpers ─────────────────────────────────────

  /// Call this before opening the bulk entry sheet.
  void initBulkEntries() {
    _disposeBulkEntries();
    final entries = openMachines.map((m) => BulkEntry(m)).toList();
    for (final e in entries) {
      // Keep running total reactive
      e.productionCtrl.addListener(() {
        e.liveMeters.value = int.tryParse(e.productionCtrl.text.trim()) ?? 0;
        _updateBulkTotal();
      });
    }
    bulkEntries.assignAll(entries);
    bulkTotalMeters.value = 0;
  }

  void _updateBulkTotal() {
    bulkTotalMeters.value =
        bulkEntries.fold(0, (s, e) => s + e.liveMeters.value);
  }

  void _disposeBulkEntries() {
    for (final e in bulkEntries) {
      e.dispose();
    }
    bulkEntries.clear();
  }

  /// Validates all entries, then POSTs to the bulk endpoint.
  /// Returns true on success.
  Future<bool> bulkSave() async {
    // Validate all
    for (final e in bulkEntries) {
      final err = e.validate();
      if (err != null) {
        Get.snackbar('Validation', err,
            backgroundColor: const Color(0xFFD97706),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    }

    isBulkUpdating.value = true;
    try {
      await _dio.post('/bulk-enter-production', data: {
        'shiftPlanId': shiftPlanId,
        'entries': bulkEntries.map((e) => e.toPayload()).toList(),
      });
      Get.snackbar(
        'Production Saved',
        '${bulkEntries.length} machines updated',
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      _disposeBulkEntries();
      await fetchDetail(); // refresh cards
      return true;
    } on DioException catch (e) {
      Get.snackbar(
        'Save Failed',
        e.response?.data?['message']?.toString() ?? 'Failed to save production',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isBulkUpdating.value = false;
    }
  }
}