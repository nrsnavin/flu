import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/core/api_client.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;

class OrderDetailController extends GetxController {
  final String orderId;
  OrderDetailController(this.orderId);

  Dio get _dio => ApiClient.instance.dio;

  final isLoading   = true.obs;
  final isActioning = false.obs;
  final order       = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    super.onInit();
    fetchOrderDetail();
  }

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

  Future<void> approveOrder() async {
    try {
      isActioning.value = true;
      // 🪪 Actor attached so the backend records who approved
      await _dio.post("/order/approve", data: {
        "orderId": orderId,
        "actor":   buildActorPayload(),
      });
      Get.snackbar(
        "Order Approved", "Raw materials deducted from stock",
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

  Future<void> startProduction() async {
    try {
      isActioning.value = true;
      // 🪪 Actor attached so the backend records who started production
      await _dio.post("/order/start-production", data: {
        "orderId": orderId,
        "actor":   buildActorPayload(),
      });
      Get.snackbar(
        "Production Started", "Order is now In Progress",
        backgroundColor: const Color(0xFFD97706),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchOrderDetail();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to start production";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isActioning.value = false;
    }
  }

  /// Soft-delete an Open order (no jobs). Returns true on success
  /// so the caller can pop back to the list.
  Future<bool> deleteOrder({String? reason}) async {
    try {
      isActioning.value = true;
      await _dio.post('/order/delete-order', data: {
        'orderId': orderId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        'actor':   buildActorPayload(),
      });
      Get.snackbar(
        'Order Deleted', 'The order has been removed.',
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Delete failed';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isActioning.value = false;
    }
  }
}
