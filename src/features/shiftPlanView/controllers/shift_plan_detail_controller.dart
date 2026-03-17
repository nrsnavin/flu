import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/shiftPlanDetail.dart';

class ShiftPlanDetailController extends GetxController {
  var isLoading = true.obs;
  var shiftDetail = Rxn<ShiftPlanDetailModel>();

  late String shiftId;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // BUG FIX: Added missing @override annotation
  @override
  void onInit() {
    super.onInit();
    shiftId = Get.arguments as String;
    fetchShiftDetail();
  }

  Future<void> fetchShiftDetail() async {
    try {
      isLoading.value = true;
      final res = await _dio.get("/shift/shiftPlanById/?id=$shiftId");
      final data = ShiftPlanDetailModel.fromJson(res.data['data']);
      shiftDetail.value = data;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load shift detail",
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
      );
    } finally {
      isLoading.value = false;
    }
  }
}