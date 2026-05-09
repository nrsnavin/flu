import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/login_controller.dart';

/// Loads the logged-in employee's open shifts and submits the
/// production count for the selected one. Re-uses the existing
/// admin endpoints (`/shift/employee-open-shifts`, `/shift/enter-shift-production`).
class ShiftProductionController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  // ── State ──────────────────────────────────────────────────
  final shifts        = <Map<String, dynamic>>[].obs;
  final isLoading     = true.obs;
  final isSubmitting  = false.obs;
  final selectedShift = Rxn<Map<String, dynamic>>();
  final productionCtrl = TextEditingController();
  final timerCtrl      = TextEditingController();
  final feedbackCtrl   = TextEditingController();
  final errorMsg       = Rxn<String>();

  String get _employeeId =>
      LoginController.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    fetchOpen();
  }

  @override
  void onClose() {
    productionCtrl.dispose();
    timerCtrl.dispose();
    feedbackCtrl.dispose();
    super.onClose();
  }

  // ── Fetch open shifts ──────────────────────────────────────
  Future<void> fetchOpen() async {
    if (_employeeId.isEmpty) {
      errorMsg.value =
          'No employee record linked to your login. Contact your supervisor.';
      isLoading.value = false;
      return;
    }
    try {
      isLoading.value = true;
      errorMsg.value = null;
      final res = await _dio.get(
        '/shift/employee-open-shifts',
        queryParameters: {'id': _employeeId},
      );
      final list = (res.data['shifts'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      shifts.assignAll(list);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString() ??
          'Failed to load open shifts';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void selectShift(Map<String, dynamic> shift) {
    selectedShift.value = shift;
    productionCtrl.clear();
    timerCtrl.clear();
    feedbackCtrl.clear();
  }

  // ── Submit ────────────────────────────────────────────────
  Future<bool> submit() async {
    final s = selectedShift.value;
    if (s == null) return false;

    final production = double.tryParse(productionCtrl.text.trim());
    if (production == null || production < 0) {
      _snack('Validation', 'Enter a valid production number',
          error: true);
      return false;
    }

    isSubmitting.value = true;
    try {
      await _dio.post('/shift/enter-shift-production', data: {
        'id':         s['_id'],
        'production': production,
        'timer':      timerCtrl.text.trim(),
        'feedback':   feedbackCtrl.text.trim(),
      });
      _snack('Saved', 'Shift production recorded', error: false);
      selectedShift.value = null;
      await fetchOpen();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message']?.toString() ?? 'Submission failed',
          error: true);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  void _snack(String title, String msg, {required bool error}) {
    Get.snackbar(
      title,
      msg,
      backgroundColor:
          error ? ErpColors.errorRed : ErpColors.successGreen,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
