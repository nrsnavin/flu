import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:production/src/features/shift/models/shift_detail_view_model.dart';

// ── import removed: shift_list_page (caused circular import) ──

class ShiftDetailController extends GetxController {
  final String shiftId;

  ShiftDetailController(this.shiftId);

  @override
  void onInit() {
    fetchDetail();
    super.onInit();
  }

  var productionController = TextEditingController();
  var timerController = TextEditingController(text: "00:00:00");
  var feedbackController = TextEditingController();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  var shift       = Rxn<ShiftDetailViewModel>();
  var isSaving    = false.obs;
  var isLoading   = false.obs;
  // FIX: screen watches this flag and calls Navigator.pop(context)
  var saveSuccess = false.obs;

  @override
  void onClose() {
    productionController.dispose();
    timerController.dispose();
    feedbackController.dispose();
    super.onClose();
  }

  Future<void> fetchDetail() async {
    try {
      isLoading.value = true;
      final response = await _dio.get("/shift/shiftDetail?id=$shiftId");
      shift.value =
          ShiftDetailViewModel.fromJson(response.data["shift"]);
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load shift details",
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveShift() async {
    // Validate before parsing
    final productionText  = productionController.text.trim();
    final productionValue = int.tryParse(productionText);
    if (productionValue == null) {
      Get.snackbar("Validation Error", "Enter a valid production number");
      return;
    }

    try {
      isSaving.value = true;
      await _dio.post(
        "/shift/enter-shift-production",
        data: {
          "id":         shiftId,
          "production": productionValue,
          "timer":      timerController.text,
          "feedback":   feedbackController.text,
        },
      );
      Get.snackbar(
        "Success",
        "Shift production saved",
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
      );
      // FIX: signal the screen to pop — no context needed in controller
      saveSuccess.value = true;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to update shift",
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
      );
    } finally {
      isSaving.value = false;
    }
  }
}