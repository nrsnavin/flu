import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/login_controller.dart';

class PayrollController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final slip      = Rxn<Map<String, dynamic>>();
  final advances  = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final isRequesting = false.obs;
  final errorMsg  = Rxn<String>();

  // Selected month / year for the slip — defaults to current.
  final selectedYear  = DateTime.now().year.obs;
  final selectedMonth = DateTime.now().month.obs;

  String get _empId => LoginController.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    if (_empId.isEmpty) {
      errorMsg.value = 'No employee record linked.';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      // Fire both in parallel; tolerate the slip 404 (not generated yet).
      final slipFut = _dio.get(
        '/payroll/slip/$_empId',
        queryParameters: {
          'year':  selectedYear.value,
          'month': selectedMonth.value,
        },
      ).then<Map<String, dynamic>?>((res) =>
          (res.data['data'] as Map?)?.cast<String, dynamic>())
          .catchError((_) => null);

      final advFut = _dio.get(
        '/payroll/advance',
        queryParameters: {'employeeId': _empId},
      ).then<List<Map<String, dynamic>>>((res) =>
          ((res.data['data'] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList())
          .catchError((_) => const <Map<String, dynamic>>[]);

      final results = await Future.wait([slipFut, advFut]);
      slip.value     = results[0] as Map<String, dynamic>?;
      advances.assignAll(results[1] as List<Map<String, dynamic>>);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString() ??
          'Failed to load payroll';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void changeMonth(int year, int month) {
    selectedYear.value  = year;
    selectedMonth.value = month;
    refreshAll();
  }

  Future<bool> requestAdvance({
    required double amount,
    required String reason,
  }) async {
    if (amount <= 0) {
      _snack('Validation', 'Amount must be greater than zero', error: true);
      return false;
    }
    isRequesting.value = true;
    try {
      await _dio.post('/payroll/advance', data: {
        'employeeId': _empId,
        'amount':     amount,
        'reason':     reason,
      });
      _snack('Submitted', 'Advance request sent for approval', error: false);
      await refreshAll();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message']?.toString() ??
              'Could not submit request',
          error: true);
      return false;
    } finally {
      isRequesting.value = false;
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
