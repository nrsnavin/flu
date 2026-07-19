import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:production/src/features/shift/models/shift_detail_view_model.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;
import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

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

  static final Dio _dio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

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

  var isCorrecting = false.obs;

  /// Corrects a verified (closed) production entry to a new total. The
  /// server re-derives the order/job cascade and stamps a
  /// SHIFT_PRODUCTION_EDITED fingerprint. Requires an audit reason.
  Future<bool> correctProduction(int newMeters, String auditReason) async {
    try {
      isCorrecting.value = true;
      await _dio.put(
        "/shift/production-entry/$shiftId",
        data: {"productionMeters": newMeters, "auditReason": auditReason},
      );
      await fetchDetail();
      Get.snackbar("Corrected", "Production entry updated",
          backgroundColor: const Color(0xFF16A34A), colorText: const Color(0xFFFFFFFF));
      return true;
    } catch (e) {
      Get.snackbar("Error", _msg(e, "Failed to correct entry"),
          backgroundColor: const Color(0xFFDC2626), colorText: const Color(0xFFFFFFFF));
      return false;
    } finally {
      isCorrecting.value = false;
    }
  }

  /// Deletes (reverses + un-verifies) a closed production entry so it can
  /// be re-entered. Requires an audit reason.
  Future<bool> deleteProduction(String auditReason) async {
    try {
      isCorrecting.value = true;
      await _dio.delete(
        "/shift/production-entry/$shiftId",
        queryParameters: {"auditReason": auditReason},
      );
      await fetchDetail();
      Get.snackbar("Deleted", "Production entry reversed and un-verified",
          backgroundColor: const Color(0xFF16A34A), colorText: const Color(0xFFFFFFFF));
      return true;
    } catch (e) {
      Get.snackbar("Error", _msg(e, "Failed to delete entry"),
          backgroundColor: const Color(0xFFDC2626), colorText: const Color(0xFFFFFFFF));
      return false;
    } finally {
      isCorrecting.value = false;
    }
  }

  String _msg(Object e, String fallback) {
    if (e is DioException && e.response?.data is Map) {
      final m = (e.response!.data as Map)["message"];
      if (m != null) return m.toString();
    }
    return fallback;
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
          "actor":      buildActorPayload(),
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