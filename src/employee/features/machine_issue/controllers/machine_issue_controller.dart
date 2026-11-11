import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/emp_session.dart';

/// Lets the worker file a machine breakdown / maintenance request
/// and track its status. Backed by /machine-issue endpoints.
class EmpMachineIssueController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final issues          = <Map<String, dynamic>>[].obs;

  /// All distinct machines this worker currently has open shifts
  /// against. Each entry is the populated Machine sub-doc shape:
  /// `{ _id, ID, status, NoOfHead, NoOfHooks, orderRunning, ... }`.
  final activeMachines  = <Map<String, dynamic>>[].obs;

  final isLoading    = true.obs;
  final isSubmitting = false.obs;
  final errorMsg     = Rxn<String>();

  String get _empId => EmpSession.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  Future<void> fetchAll() async {
    if (_empId.isEmpty) {
      errorMsg.value = 'No employee record linked.';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      // Issues history.
      final histFut = _dio.get('/machine-issue/employee/$_empId');

      // ALL active machines (worker may be on multiple). The form
      // will let the worker pick which one they're reporting on.
      final activeFut = _dio.get('/shift/active-jobs/$_empId');

      final results = await Future.wait([histFut, activeFut]);
      issues.assignAll(
          SafeJson.asMapList(SafeJson.asMap(results[0].data)['data']));

      // De-duplicate by machine _id; a worker can have several
      // shifts on the SAME machine in a day.
      final seen = <String>{};
      final machines = <Map<String, dynamic>>[];
      for (final s in SafeJson.asMapList(
              SafeJson.asMap(results[1].data)['shifts'])) {
        final m = SafeJson.asMapOrNull(s['machine']);
        if (m == null) continue;
        final id = SafeJson.asString(m['_id']);
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        machines.add(m);
      }
      activeMachines.assignAll(machines);
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load issues';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submit({
    required String machineId,
    required String title,
    required String description,
    required String severity,
  }) async {
    if (machineId.isEmpty) {
      _snack('Validation', 'No machine to report against', error: true);
      return false;
    }
    if (title.trim().isEmpty || description.trim().isEmpty) {
      _snack('Validation', 'Title and description are required',
          error: true);
      return false;
    }
    // Guard against double-tap: the disabled-button Obx rebuild is
    // async, so two fast taps could otherwise fire two POSTs.
    if (isSubmitting.value) return false;
    isSubmitting.value = true;
    try {
      await _dio.post('/machine-issue', data: {
        'machineId':   machineId,
        'employeeId':  _empId,
        'title':       title.trim(),
        'description': description.trim(),
        'severity':    severity,
      });
      _snack('Reported', 'Maintenance team has been notified',
          error: false);
      await fetchAll();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          SafeJson.apiErrorMessage(e.response?.data) ?? 'Submit failed',
          error: true);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> withdraw(String id) async {
    try {
      await _dio.delete('/machine-issue/$id');
      _snack('Withdrawn', 'Issue removed', error: false);
      await fetchAll();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          SafeJson.apiErrorMessage(e.response?.data) ?? 'Cancel failed',
          error: true);
      return false;
    }
  }

  void _snack(String title, String msg, {required bool error}) {
    Get.snackbar(title, msg,
        backgroundColor:
            error ? ErpColors.errorRed : ErpColors.successGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
  }
}
