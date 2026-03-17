import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/MachineRunningModel.dart';
import '../models/OperatorModel.dart';

// ══════════════════════════════════════════════════════════════
//  SHIFT PLAN CONTROLLER
// ══════════════════════════════════════════════════════════════

class CreateShiftPlanController extends GetxController {
  final VoidCallback? onSuccess;
  CreateShiftPlanController({this.onSuccess});
  // ── Form state ─────────────────────────────────────────────
  final selectedDate = DateTime.now().obs;
  final shiftType    = 'DAY'.obs;
  final description  = ''.obs;

  // ── Data ───────────────────────────────────────────────────
  final runningMachines = <MachineRunningModel>[].obs;
  final operators       = <OperatorModel>[].obs;

  /// machineId → selected operatorId (null = unassigned)
  final machineOperatorMap = <String, String?>{}.obs;

  // ── UI state ────────────────────────────────────────────────
  final isLoading  = true.obs;
  final isSaving   = false.obs;
  final errorMsg   = Rxn<String>();  // non-null means error state shown

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  // ── Data loading ───────────────────────────────────────────
  /// FIX: was sequential (await A; await B) — now parallel.
  /// FIX: was no try/catch → API failure left isLoading = true forever.
  Future<void> loadData() async {
    isLoading.value = true;
    errorMsg.value  = null;

    try {
      // FIX: run both fetches in parallel
      final results = await Future.wait([
        ShiftApiService.fetchRunningMachines(),
        ShiftApiService.fetchOperators(),
      ]);

      runningMachines.value = results[0] as List<MachineRunningModel>;
      operators.value       = results[1] as List<OperatorModel>;

      // Initialise operator assignment map — every machine starts unassigned
      machineOperatorMap.clear();
      for (final m in runningMachines) {
        machineOperatorMap[m.machineId] = null;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to load shift data';
      errorMsg.value = msg;
      Get.snackbar(
        'Load Error', msg,
        backgroundColor:  const Color(0xFFDC2626),
        colorText:        Colors.white,
        snackPosition:    SnackPosition.BOTTOM,
        duration:         const Duration(seconds: 4),
      );
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Operator assignment ─────────────────────────────────────
  void setOperator(String machineId, String? operatorId) {
    machineOperatorMap[machineId] = operatorId;
  }

  // ── Validation ─────────────────────────────────────────────
  /// Returns an error string, or null if everything is valid.
  String? validate() {
    if (runningMachines.isEmpty) {
      return 'No running machines found. Nothing to plan.';
    }

    final unassigned = machineOperatorMap.entries
        .where((e) => e.value == null)
        .length;

    if (unassigned > 0) {
      return 'Assign an operator to all $unassigned unassigned machine(s) before saving.';
    }

    return null;
  }

  // ── Number of unassigned machines (for live counter in UI) ──
  int get unassignedCount =>
      machineOperatorMap.values.where((v) => v == null).length;

  // ── Save ───────────────────────────────────────────────────
  /// FIX: validate() was never called before submitting.
  /// FIX: Get.off(Home()) replaced with onSuccess callback → Navigator.of(context).pop(true).
  /// FIX: duplicate snackbar — controller showed one, button showed another.
  ///      Now only the controller shows snackbars.
  Future<void> saveShiftPlan() async {
    // Validation gate
    final err = validate();
    if (err != null) {
      Get.snackbar(
        'Incomplete', err,
        backgroundColor: const Color(0xFFD97706),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.BOTTOM,
        duration:        const Duration(seconds: 4),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      );
      return;
    }

    isSaving.value = true;

    try {
      final machines = machineOperatorMap.entries.map((e) {
        final m = runningMachines.firstWhere((x) => x.machineId == e.key);
        return {
          'machine':    e.key,
          // FIX: was int.parse(m.jobOrderNo) — throws if non-numeric string.
          //      Use tryParse with fallback.
          'jobOrderNo': int.tryParse(m.jobOrderNo) ?? 0,
          'operator':   e.value,
        };
      }).toList();

      await ShiftApiService.createShiftPlan({
        'date':        DateUtils.dateOnly(selectedDate.value).toIso8601String(),
        'shiftType':   shiftType.value,
        'description': description.value.trim(),
        'machines':    machines,
      });

      Get.snackbar(
        'Shift Plan Created',
        '${shiftType.value} shift plan saved for $formattedDate',
        backgroundColor: const Color(0xFF16A34A),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.BOTTOM,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );

      // Pop back to caller and signal success
      onSuccess?.call();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final msg = e.response?.data?['message'] as String? ??
          'Failed to create shift plan';

      if (statusCode == 409) {
        Get.snackbar(
          'Duplicate Shift',
          'A ${shiftType.value} shift plan already exists for $formattedDate',
          backgroundColor: const Color(0xFFD97706),
          colorText:       Colors.white,
          snackPosition:   SnackPosition.BOTTOM,
          duration:        const Duration(seconds: 5),
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        );
      } else {
        Get.snackbar(
          'Save Failed', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText:       Colors.white,
          snackPosition:   SnackPosition.BOTTOM,
          icon: const Icon(Icons.error_outline, color: Colors.white),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error', e.toString(),
        backgroundColor: const Color(0xFFDC2626),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.BOTTOM,
      );
    } finally {
      isSaving.value = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  String get formattedDate =>
      DateFormat('dd MMM yyyy').format(selectedDate.value);

  OperatorModel? operatorForMachine(String machineId) {
    final opId = machineOperatorMap[machineId];
    if (opId == null) return null;
    return operators.firstWhereOrNull((o) => o.id == opId);
  }
}

// ══════════════════════════════════════════════════════════════
//  API SERVICE
// ══════════════════════════════════════════════════════════════

class ShiftApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<List<MachineRunningModel>> fetchRunningMachines() async {
    final res = await _dio.get('/machine/running-machines');
    return (res.data['data'] as List)
        .map((e) => MachineRunningModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<OperatorModel>> fetchOperators() async {
    final res = await _dio.get('/employee/get-employee-weave');
    return (res.data['employees'] as List)
        .map((e) => OperatorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createShiftPlan(Map<String, dynamic> body) async {
    await _dio.post('/shift/create-shift-plan', data: body);
  }
}