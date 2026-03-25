// ══════════════════════════════════════════════════════════════
//  SHIFT PLAN DETAIL CONTROLLER
//  File: lib/src/features/shiftPlanView/controllers/shift_plan_detail_controller.dart
//
//  ADDED: confirmShiftPlan() — calls POST /shift/confirm-shift-plan
//         isConfirming state so the button shows a spinner
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/shiftPlanDetail.dart';

class ShiftPlanDetailController extends GetxController {
  final String shiftPlanId;
  ShiftPlanDetailController({required this.shiftPlanId});

  // ── State ──────────────────────────────────────────────────
  final isLoading    = true.obs;
  final isConfirming = false.obs;
  final errorMsg     = Rxn<String>();
  final shiftDetail  = Rxn<ShiftPlanDetailModel>();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  void onInit() {
    super.onInit();
    fetchShiftDetail();
  }

  // ── Fetch ──────────────────────────────────────────────────
  Future<void> fetchShiftDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get('/shift/shiftPlanById/?id=$shiftPlanId');
      shiftDetail.value = ShiftPlanDetailModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String?
          ?? 'Failed to load shift detail';
      Get.snackbar(
        'Error', errorMsg.value!,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Confirm ────────────────────────────────────────────────
  /// Sends POST /shift/confirm-shift-plan.
  /// Returns true on success so the dialog can close itself.
  Future<bool> confirmShiftPlan() async {
    isConfirming.value = true;
    try {
      await _dio.post(
        '/shift/confirm-shift-plan',
        data: {'id': shiftPlanId},
      );
      // Refresh detail so the status badge updates
      await fetchShiftDetail();
      Get.snackbar(
        'Confirmed',
        'Shift plan is now active',
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );
      return true;
    } on DioException catch (e) {
      Get.snackbar(
        'Confirm Failed',
        e.response?.data?['message'] as String? ?? 'Failed to confirm shift plan',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e) {
      Get.snackbar(
        'Error', e.toString(),
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isConfirming.value = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  bool get isDraft     => shiftDetail.value?.status == 'draft';
  bool get isConfirmed => shiftDetail.value?.status == 'confirmed';
}