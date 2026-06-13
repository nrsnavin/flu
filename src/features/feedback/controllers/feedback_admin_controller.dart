import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';

// ══════════════════════════════════════════════════════════════
//  FeedbackAdminController
//  Lists employee feedback (complaints + suggestions) for admin
//  with filtering by status / type / category.
// ══════════════════════════════════════════════════════════════
class FeedbackAdminController extends GetxController {
  final items   = <Map<String, dynamic>>[].obs;
  final loading = false.obs;
  final errorMsg = Rxn<String>();

  final status   = "all".obs;
  final type     = "all".obs;
  final category = "all".obs;

  // Cookie-attaching factory — the GET /api/v2/feedback admin route is
  // gated by isAdmin('admin'); a bare Dio() request 401s.
  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/feedback',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    try {
      loading.value = true;
      errorMsg.value = null;
      final res = await _dio.get("/", queryParameters: {
        "status":   status.value,
        "type":     type.value,
        "category": category.value,
      });
      final raw = (res.data is Map ? res.data['data'] : null) as List? ?? const [];
      items.value = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load feedback';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  void setStatus(String v)   { status.value   = v; fetch(); }
  void setType(String v)     { type.value     = v; fetch(); }
  void setCategory(String v) { category.value = v; fetch(); }
}

// ══════════════════════════════════════════════════════════════
//  FeedbackRespondController
//  Used inside the detail / respond dialog.
// ══════════════════════════════════════════════════════════════
class FeedbackRespondController extends GetxController {
  final String feedbackId;
  final String initialStatus;
  final String initialResponse;
  final VoidCallback? onSuccess;

  FeedbackRespondController({
    required this.feedbackId,
    required this.initialStatus,
    required this.initialResponse,
    this.onSuccess,
  });

  final responseCtrl = TextEditingController();
  final status  = "in_review".obs;
  final loading = false.obs;

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/feedback',
  );

  @override
  void onInit() {
    super.onInit();
    responseCtrl.text = initialResponse;
    status.value = initialStatus.isEmpty ? "in_review" : initialStatus;
  }

  Future<void> submit() async {
    try {
      loading.value = true;
      await _dio.put("/$feedbackId/respond", data: {
        "response": responseCtrl.text.trim(),
        "status":   status.value,
      });
      Get.snackbar(
        "Updated", "Response saved",
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to save response";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    responseCtrl.dispose();
    super.onClose();
  }
}
