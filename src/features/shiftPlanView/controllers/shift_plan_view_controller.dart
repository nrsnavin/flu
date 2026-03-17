import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/shiftSummary.dart';


class ShiftController extends GetxController {
  final isLoading = false.obs;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2", // 🔁 CHANGE
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );


  final dayShift = Rxn<ShiftSummaryModel>();
  final nightShift = Rxn<ShiftSummaryModel>();

  @override
  void onInit() {
    super.onInit();
    fetchTodayShifts();
  }

  Future<void> fetchTodayShifts() async {
    try {
      isLoading.value = true;

      final data = await _dio.get("/shift/today");

      dayShift.value = ShiftSummaryModel.fromJson(data.data['data']["dayShift"]);
      nightShift.value =ShiftSummaryModel.fromJson(data.data['data']["nightShift"]);
    } finally {
      isLoading.value = false;
    }
  }
}
