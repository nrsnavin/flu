import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/shiftSummary.dart';
import '../../../core/api_client.dart';
import '../../../core/app_config.dart';


class ShiftController extends GetxController {
  final isLoading = false.obs;

  final Dio _dio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);


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
