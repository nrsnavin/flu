import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/emp_session.dart';

/// Manages worker-filed complaints + suggestions through
/// /feedback endpoints.
class EmpFeedbackController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final items        = <Map<String, dynamic>>[].obs;
  final isLoading    = true.obs;
  final isSubmitting = false.obs;
  final errorMsg     = Rxn<String>();

  String get _empId => EmpSession.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    if (_empId.isEmpty) {
      errorMsg.value = 'No employee record linked.';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get('/feedback/employee/$_empId');
      items.assignAll(
          SafeJson.asMapList(SafeJson.asMap(res.data)['data']));
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load feedback';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submit({
    required String type,         // complaint | suggestion
    required String category,
    required String subject,
    required String body,
    required bool isAnonymous,
  }) async {
    if (subject.trim().isEmpty || body.trim().isEmpty) {
      _snack('Validation', 'Subject and body are required', error: true);
      return false;
    }
    // Reject re-entry while a previous submit is still in flight.
    // The disabled-button Obx rebuild is async, so a fast double tap
    // can otherwise fire two POSTs.
    if (isSubmitting.value) return false;
    isSubmitting.value = true;
    try {
      await _dio.post('/feedback', data: {
        'employeeId':  _empId,
        'type':        type,
        'category':    category,
        'subject':     subject.trim(),
        'body':        body.trim(),
        'isAnonymous': isAnonymous,
      });
      _snack('Submitted', 'HR will review your submission', error: false);
      await fetch();
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
      await _dio.delete('/feedback/$id');
      _snack('Withdrawn', 'Submission removed', error: false);
      await fetch();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          SafeJson.apiErrorMessage(e.response?.data) ?? 'Withdraw failed',
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
