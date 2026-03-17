import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../models/shiftModel.dart';

class ShiftControllerView extends GetxController {
  var shifts = <ShiftModel>[].obs;
  var isLoading = false.obs;

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  void onInit() {
    super.onInit();
    fetchOpenShifts();
  }

  Future<void> fetchOpenShifts() async {
    try {
      isLoading.value = true;

      final response = await _dio.get("/shift/open");

      shifts.value = (response.data["shifts"] as List)
          .map((e) => ShiftModel.fromJson(e))
          .toList();
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load shifts",
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
      );
    } finally {
      isLoading.value = false;
    }
  }
}