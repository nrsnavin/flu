import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/pdf_preview_page.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/emp_session.dart';

/// Loads the worker's own yearly bonus from
/// `GET /bonus/employee/:id?year=` and downloads the certificate
/// PDF from `GET /bonus/employee/:id/pdf?year=`.
class EmpBonusController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final selectedYear = DateTime.now().year.obs;
  final record       = Rxn<Map<String, dynamic>>();
  final config       = Rxn<Map<String, dynamic>>();
  final isLoading    = true.obs;
  final isDownloading = false.obs;
  final errorMsg     = Rxn<String>();

  String get _empId => EmpSession.find.user.value.employeeId ?? '';
  String get _empName => EmpSession.find.user.value.name;

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
      final res = await _dio.get(
        '/bonus/employee/$_empId',
        queryParameters: {'year': selectedYear.value},
      );
      final body = SafeJson.asMap(res.data);
      record.value = SafeJson.asMapOrNull(body['record']);
      config.value = SafeJson.asMapOrNull(body['config']);
    } on DioException catch (e) {
      errorMsg.value =
          SafeJson.asStringOrNull(SafeJson.asMap(e.response?.data)['message'])
              ?? 'Failed to load bonus';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void changeYear(int year) {
    selectedYear.value = year;
    fetch();
  }

  Future<void> downloadPdf() async {
    if (_empId.isEmpty || record.value == null) return;
    isDownloading.value = true;
    try {
      final res = await _dio.get<List<int>>(
        '/bonus/employee/$_empId/pdf',
        queryParameters: {'year': selectedYear.value},
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        throw 'Empty PDF response';
      }
      // Shown in the app's PDF page, whose own buttons share and print
      // it — on the web too, where there is no file system to save into
      // first (the employee app wrote a temporary file and shared that).
      final who = _empName.isNotEmpty ? _empName : 'employee';
      await Get.to(() => DocumentPdfPage(
            bytes: Uint8List.fromList(bytes),
            title: 'Bonus certificate ${selectedYear.value}',
            subtitle: who,
          ));
    } on DioException catch (e) {
      _snack('Error',
          SafeJson.asStringOrNull(SafeJson.asMap(e.response?.data)['message'])
              ?? 'Could not download PDF',
          error: true);
    } catch (e) {
      _snack('Error', e.toString(), error: true);
    } finally {
      isDownloading.value = false;
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
