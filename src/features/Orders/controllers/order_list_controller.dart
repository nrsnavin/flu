import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/core/api_client.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;
import 'package:production/src/features/Orders/models/order_list_item.dart';

class OrderListController extends GetxController {
  // Use the shared singleton so the JWT cookie is attached automatically
  // and every action gets a server-side user fingerprint.
  Dio get _dio => ApiClient.instance.dio;

  final orders = <OrderListItem>[].obs;

  final statuses = const [
    "Open",
    "Approved",
    "InProgress",
    "Completed",
    "Cancelled",
  ];

  final selectedStatus = "Open".obs;
  final isLoading      = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      isLoading.value = true;
      final res = await _dio.get(
        "/order/list",
        queryParameters: {"status": selectedStatus.value},
      );
      orders.assignAll(
        (res.data["orders"] as List)
            .map((e) => OrderListItem.fromJson(e))
            .toList(),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to load orders";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void changeStatus(String status) {
    selectedStatus.value = status;
    fetchOrders();
  }

  Future<void> approveOrder(String id) async {
    try {
      await _dio.post("/order/approve",
          data: {"orderId": id, "actor": buildActorPayload()});
      Get.snackbar(
        "Order Approved",
        "Stock deducted successfully",
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      fetchOrders();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Approval failed";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> cancelOrder(String id) async {
    try {
      await _dio.post("/order/cancel",
          data: {"orderId": id, "actor": buildActorPayload()});
      Get.snackbar(
        "Order Cancelled",
        "",
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      fetchOrders();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Cancel failed";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// Soft-delete an Open order (no jobs allowed).
  Future<void> deleteOrder(String id, {String? reason}) async {
    try {
      await _dio.post("/order/delete-order", data: {
        "orderId": id,
        if (reason != null && reason.isNotEmpty) "reason": reason,
        "actor": buildActorPayload(),
      });
      Get.snackbar(
        "Order Deleted",
        "Order moved to Deleted status",
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      fetchOrders();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Delete failed";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
