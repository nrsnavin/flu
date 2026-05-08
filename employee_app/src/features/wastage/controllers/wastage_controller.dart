import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../auth/controllers/login_controller.dart';

class WastageController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final items     = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final errorMsg  = Rxn<String>();

  String get _empId => LoginController.find.user.value.employeeId ?? '';

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
      final list = (res.data['wastage'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      items.assignAll(list);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString() ??
          'Failed to load wastage records';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Aggregates for the summary card ────────────────────────
  double get totalQuantity =>
      items.fold(0.0, (s, w) => s + ((w['quantity'] as num?)?.toDouble() ?? 0));
  double get totalPenalty =>
      items.fold(0.0, (s, w) => s + ((w['penalty']  as num?)?.toDouble() ?? 0));
}
