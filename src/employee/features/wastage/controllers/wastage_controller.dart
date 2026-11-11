import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../auth/controllers/emp_session.dart';

class EmpWastageController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final items     = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final errorMsg  = Rxn<String>();

  String get _empId => EmpSession.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  Future<void> refresh() async {
    if (_empId.isEmpty) {
      errorMsg.value = 'No employee record linked.';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get(
        '/wastage/get-by-employee',
        queryParameters: {'id': _empId},
      );
      items.assignAll(
          SafeJson.asMapList(SafeJson.asMap(res.data)['wastage']));
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load wastage records';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Aggregates for the summary card ────────────────────────
  double get totalQuantity =>
      items.fold(0.0, (s, w) => s + SafeJson.asDouble(w['quantity']));
  double get totalPenalty =>
      items.fold(0.0, (s, w) => s + SafeJson.asDouble(w['penalty']));
}
