import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/core/api_client.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;
import 'package:production/src/features/Orders/widgets/force_approval_dialog.dart';

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

  Future<void> approveOrder({
    bool force = false,
    String? forceReason,
    BuildContext? alertContext,
  }) async {
    isActioning.value = true;
    try {
      // 🪪 Actor attached so the backend records who approved
      await _dio.post("/order/approve", data: {
        "orderId": orderId,
        "actor":   buildActorPayload(),
        if (force) "force": true,
        if (force && forceReason != null) "forceReason": forceReason,
      });
      Get.snackbar(
        force ? "Order Force-Approved" : "Order Approved",
        force
            ? "Approval forced despite insufficient raw stock"
            : "Raw materials deducted from stock",
        backgroundColor: force
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      await fetchOrderDetail();
    } on DioException catch (e) {
      // Backend returns `code: "INSUFFICIENT_STOCK"` + a structured
      // `shortfall` payload when raw material is short. Surface the
      // dialog so the admin can confirm + supply a reason; on
      // confirm, retry with force.
      //
      // Fallback: older backends without the structured payload would
      // just send a message — match on the substring as a safety net
      // so the alert still fires in mixed-deploy windows.
      final data = e.response?.data;
      final isMap = data is Map;
      final code = isMap ? data['code'] : null;
      final msg  = (isMap ? data['message']?.toString() : null) ?? '';
      final shortfall = isMap && data['shortfall'] is Map
          ? Map<String, dynamic>.from(data['shortfall'] as Map)
          : null;
      final looksLikeStockShort = code == 'INSUFFICIENT_STOCK' ||
          msg.toLowerCase().contains('insufficient stock');

      final ctx = alertContext ?? Get.overlayContext ?? Get.context;
      if (looksLikeStockShort && ctx != null) {
        // Free the spinner so the page reads "Approve again" while
        // the dialog is up.
        isActioning.value = false;
        final reason = await showForceApprovalDialog(
          context: ctx,
          shortfall: shortfall ??
              {
                // Backend didn't send the structured payload; render a
                // generic placeholder so the dialog still works.
                'materialName': 'Raw materials',
                'available':    0,
                'required':     0,
                'short':        0,
              },
          originalMessage: msg.isNotEmpty
              ? msg
              : 'Raw-material stock is short of the order requirement.',
        );
        if (reason != null) {
          await approveOrder(
            force: true,
            forceReason: reason,
            alertContext: alertContext,
          );
        }
        return;
      }
      Get.snackbar(
        "Error",
        msg.isNotEmpty ? msg : "Approval failed",
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
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

  /// Cancel an Open or Approved order. Stock isn't auto-refunded;
  /// the confirmation dialog warns the user.
  Future<void> cancelOrder() async {
    try {
      isActioning.value = true;
      await _dio.post('/order/cancel', data: {
        'orderId': orderId,
        'actor':   buildActorPayload(),
      });
      Get.snackbar(
        'Order Cancelled', 'The order has been moved to Cancelled.',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchOrderDetail();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Cancel failed';
      Get.snackbar('Error', msg,
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
