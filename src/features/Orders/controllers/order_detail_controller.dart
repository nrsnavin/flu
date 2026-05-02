import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;

class OrderDetailController extends GetxController {
  final String orderId;
  OrderDetailController(this.orderId);

  // FIX: use baseUrl so all calls are consistent — was hardcoded full URLs before
  final _dio = Dio(BaseOptions(
    baseUrl: "http://13.233.117.153:2701/api/v2",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final isLoading       = true.obs;
  final isActioning     = false.obs; // separate flag for approve/start actions
  final order           = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    // FIX: super.onInit() MUST be called first — was called after fetchOrderDetail()
    super.onInit();
    fetchOrderDetail();
  }

  // ── Fetch detail ───────────────────────────────────────────
  Future<void> fetchOrderDetail() async {
    try {
      isLoading.value = true;
      final res = await _dio.get(
        "/order/get-orderDetail",
        queryParameters: {"id": orderId},
      );
      order.value = res.data["data"] as Map<String, dynamic>?;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to load order";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Approve ────────────────────────────────────────────────
  Future<void> approveOrder() async {
    try {
      isActioning.value = true;
      // 🪪 Actor attached so the backend records who approved
      await _dio.post("/order/approve", data: {
        "orderId": orderId,
        "actor":   buildActorPayload(),
      });
      Get.snackbar(
        "Order Approved",
        "Raw materials deducted from stock",
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      await fetchOrderDetail();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Approval failed";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isActioning.value = false;
    }
  }

  // ── Start Production ───────────────────────────────────────
  Future<void> startProduction() async {
    try {
      isActioning.value = true;
      // FIX: use /start-production which validates Approved status first
      await _dio.post("/order/start-production", data: {
        "orderId": orderId,
        "actor":   buildActorPayload(),
      });
      Get.snackbar(
        "Production Started",
        "Order is now In Progress",
        backgroundColor: const Color(0xFFD97706),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchOrderDetail();
    } on DioException catch (e) {
      // FIX: was "Cancel failed" — wrong message
      final msg = e.response?.data?['message'] ?? "Failed to start production";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isActioning.value = false;
    }
  }
}