import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/emp_session.dart';

/// Manages the worker's leave requests:
///   - List (bucketed pending / approved / rejected)
///   - Submit a new request
///   - Cancel a pending one
class EmpLeaveController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final pending  = <Map<String, dynamic>>[].obs;
  final approved = <Map<String, dynamic>>[].obs;
  final rejected = <Map<String, dynamic>>[].obs;

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
      final res = await _dio.get('/leave/employee/$_empId');
      final list =
          SafeJson.asMapList(SafeJson.asMap(res.data)['data']);

      pending.assignAll(list.where((e) => e['status'] == 'pending'));
      approved.assignAll(list.where((e) => e['status'] == 'approved'));
      rejected.assignAll(list.where((e) => e['status'] == 'rejected'));

      // Surface any status the backend invented that we don't bucket
      // yet — silently dropping them masks schema drift.
      final dropped = list
          .where((e) => !{'pending', 'approved', 'rejected'}
              .contains(e['status']))
          .toList();
      if (dropped.isNotEmpty) {
        // ignore: avoid_print
        print('[leave] unknown statuses dropped: '
            '${dropped.map((e) => e['status']).toSet()}');
      }
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load leave history';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submit({
    required DateTime date,
    required String shift,        // DAY | NIGHT | BOTH
    required String leaveType,    // casual | sick | unpaid
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      _snack('Validation', 'Reason is required', error: true);
      return false;
    }
    isSubmitting.value = true;
    try {
      await _dio.post('/leave/request', data: {
        'employeeId': _empId,
        'date':       date.toIso8601String(),
        'shift':      shift,
        'leaveType':  leaveType,
        'reason':     reason.trim(),
      });
      _snack('Submitted', 'Leave request sent for approval', error: false);
      await fetchAll();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          SafeJson.apiErrorMessage(e.response?.data) ??
              'Could not submit request',
          error: true);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      await _dio.delete('/leave/$id');
      _snack('Cancelled', 'Leave request withdrawn', error: false);
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
