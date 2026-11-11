import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../auth/controllers/emp_session.dart';

/// Loads two shift lists for the logged-in employee — currently
/// open shifts and the last 30 closed ones — used by the Shift
/// History screen's two tabs.
class EmpShiftHistoryController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final openShifts   = <Map<String, dynamic>>[].obs;
  final closedShifts = <Map<String, dynamic>>[].obs;
  final isLoading    = true.obs;
  final errorMsg     = Rxn<String>();

  String get _empId => EmpSession.find.user.value.employeeId ?? '';

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
      final results = await Future.wait([
        _dio.get('/shift/employee-open-shifts',   queryParameters: {'id': _empId}),
        _dio.get('/shift/employee-closed-shifts', queryParameters: {'id': _empId}),
      ]);
      openShifts.assignAll(_parse(results[0].data, 'shifts'));
      closedShifts.assignAll(_parse(results[1].data, 'shifts'));
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load shift history';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> _parse(dynamic body, String key) =>
      SafeJson.asMapList(SafeJson.asMap(body)[key]);
}
