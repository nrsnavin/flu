import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/emp_session.dart';

/// Loads the logged-in employee's open + pending-verification shifts
/// and submits production. A fresh `open` shift goes to
/// `/shift/enter-shift-production`; a `pending_verification` edit
/// (worker correcting before admin approval) goes to `/shift/update`,
/// which the backend gates on the same two statuses and re-lands the
/// values in the submitted* fields without cascading totals.
class EmpShiftProductionController extends GetxController {
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

  /// True when the currently selected shift is already in
  /// `pending_verification` (i.e. previously submitted, awaiting
  /// admin approval). The page uses this to swap CTA labels and the
  /// submit() method uses it to route to /shift/update vs the
  /// /enter-shift-production "close" route.
  bool get isEditingPending =>
      SafeJson.asString(selectedShift.value?['status']) ==
          'pending_verification';

  String get _employeeId =>
      EmpSession.find.user.value.employeeId ?? '';

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

  // ── Fetch open + pending-verification shifts ───────────────
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
      shifts.assignAll(
          SafeJson.asMapList(SafeJson.asMap(res.data)['shifts']));
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load open shifts';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Opens the sheet for a shift. For an `open` shift the form is
  /// blank; for `pending_verification` we pre-fill the existing
  /// submitted values so the worker can correct them in place.
  void selectShift(Map<String, dynamic> shift) {
    selectedShift.value = shift;
    if (SafeJson.asString(shift['status']) == 'pending_verification') {
      final prod = shift['submittedProductionMeters'];
      productionCtrl.text = prod == null ? '' : prod.toString();
      timerCtrl.text      = SafeJson.asString(shift['submittedTimer']);
      feedbackCtrl.text   = SafeJson.asString(shift['submittedFeedback']);
    } else {
      productionCtrl.clear();
      timerCtrl.clear();
      feedbackCtrl.clear();
    }
  }

  // ── Submit ────────────────────────────────────────────────
  Future<bool> submit() async {
    final s = selectedShift.value;
    if (s == null) return false;
    if (isSubmitting.value) return false;

    final production = double.tryParse(productionCtrl.text.trim());
    if (production == null || production < 0) {
      _snack('Validation', 'Enter a valid production number',
          error: true);
      return false;
    }
    final timer = runTime(timerCtrl.text);
    if (timer == null) {
      _snack('Validation', 'Run time must look like 7:30', error: true);
      return false;
    }

    isSubmitting.value = true;
    try {
      // The worker's own route: it takes the employee from the login and
      // finds the shift among their own, so a worker's phone sign-in can
      // use it — the office routes this screen used (enter-shift-
      // production, update) refuse a worker's login. The same route
      // takes a first entry and a change to one still waiting.
      final editing = isEditingPending;
      await _dio.post('/me/shifts/${s['_id']}/production', data: {
        'production': production,
        if (timer.isNotEmpty) 'timer': timer,
        'feedback':   feedbackCtrl.text.trim(),
      });
      _snack(
          editing ? 'Updated' : 'Sent',
          editing
              ? 'Submission updated — still waiting to be checked'
              : 'Sent to your supervisor to check',
          error: false);
      selectedShift.value = null;
      await fetchOpen();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          SafeJson.apiErrorMessage(e.response?.data) ?? 'Submission failed',
          error: true);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// The run time as the server takes it (7:30 or 07:30:00), from what
  /// a worker types: 7:30, 7.30, 7h 30m, 7h or 450m. '' when left
  /// empty; null when it is not a time at all.
  static String? runTime(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return '';
    if (RegExp(r'^\d{1,2}:[0-5]\d(:[0-5]\d)?$').hasMatch(t)) return t;
    final dot = RegExp(r'^(\d{1,2})\.([0-5]\d)$').firstMatch(t);
    if (dot != null) return '${dot.group(1)}:${dot.group(2)}';
    final hm = RegExp(r'^(?:(\d{1,2})\s*h)?\s*(?:(\d{1,4})\s*m)?$').firstMatch(t);
    if (hm != null && (hm.group(1) != null || hm.group(2) != null)) {
      final minutes =
          int.parse(hm.group(1) ?? '0') * 60 + int.parse(hm.group(2) ?? '0');
      if (minutes >= 100 * 60) return null;
      return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
    }
    return null;
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
