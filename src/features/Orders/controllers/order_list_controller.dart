import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/core/api_client.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;
import 'package:production/src/features/Orders/models/order_list_item.dart';
import 'package:production/src/features/Orders/widgets/force_approval_dialog.dart';

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
    // Deleted is hidden from the default browsing flow but listed
    // here so admins can audit soft-deleted orders.
    "Deleted",
  ];

  final selectedStatus = "Open".obs;
  final isLoading      = false.obs;

  /// Per-row action lock — keyed by order id while approve / cancel /
  /// delete is in flight. Dialog buttons read this so they can show
  /// a spinner and refuse double-clicks.
  final actioningId    = RxnString();
  bool isActioningOn(String id) => actioningId.value == id;

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
      final list = (res.data is Map ? res.data["orders"] : null) as List? ?? [];
      orders.assignAll(
        list.map((e) => OrderListItem.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to load orders";
      Get.snackbar("Error", msg,
          backgroundColor: ErpColors.solidError,
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

  Future<void> approveOrder(String id,
      {bool force = false, String? forceReason}) async {
    actioningId.value = id;
    try {
      await _dio.post("/order/approve", data: {
        "orderId": id,
        "actor":   buildActorPayload(),
        if (force) "force": true,
        if (force && forceReason != null) "forceReason": forceReason,
      });
      Get.snackbar(
        force ? "Order Force-Approved" : "Order Approved",
        force
            ? "Approval forced despite insufficient raw stock"
            : "Stock deducted successfully",
        backgroundColor: force
            ? ErpColors.warningAmber
            : ErpColors.successGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      await fetchOrders();
    } on DioException catch (e) {
      // Mirror order_detail_controller: strict match on the
      // structured code, with a message-substring fallback so the
      // alert still fires against backends that predate the
      // code/shortfall payload.
      final data = e.response?.data;
      final isMap = data is Map;
      final code = isMap ? data['code'] : null;
      final emsg = (isMap ? data['message']?.toString() : null) ?? '';
      final shortfall = isMap && data['shortfall'] is Map
          ? Map<String, dynamic>.from(data['shortfall'] as Map)
          : null;
      final looksLikeStockShort = code == 'INSUFFICIENT_STOCK' ||
          emsg.toLowerCase().contains('insufficient stock');

      final ctx = Get.overlayContext ?? Get.context;
      if (looksLikeStockShort && ctx != null) {
        actioningId.value = null;
        final reason = await showForceApprovalDialog(
          context: ctx,
          shortfall: shortfall ??
              {
                'materialName': 'Raw materials',
                'available':    0,
                'required':     0,
                'short':        0,
              },
          originalMessage: emsg.isNotEmpty
              ? emsg
              : 'Raw-material stock is short of the order requirement.',
        );
        if (reason != null) {
          await approveOrder(id, force: true, forceReason: reason);
        }
        return;
      }
      final msg = (data is Map ? data['message']?.toString() : null) ??
          "Approval failed";
      Get.snackbar("Error", msg,
          backgroundColor: ErpColors.solidError,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      actioningId.value = null;
    }
  }

  Future<void> cancelOrder(String id) async {
    actioningId.value = id;
    try {
      await _dio.post("/order/cancel",
          data: {"orderId": id, "actor": buildActorPayload()});
      Get.snackbar(
        "Order Cancelled",
        "The order has been moved to Cancelled.",
        backgroundColor: ErpColors.solidError,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchOrders();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Cancel failed";
      Get.snackbar("Error", msg,
          backgroundColor: ErpColors.solidError,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      actioningId.value = null;
    }
  }

  /// Soft-delete an Open order (no jobs allowed).
  Future<void> deleteOrder(String id, {String? reason}) async {
    actioningId.value = id;
    try {
      await _dio.post("/order/delete-order", data: {
        "orderId": id,
        if (reason != null && reason.isNotEmpty) "reason": reason,
        "actor": buildActorPayload(),
      });
      Get.snackbar(
        "Order Deleted",
        "Order moved to Deleted status",
        backgroundColor: ErpColors.solidSuccess,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchOrders();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Delete failed";
      Get.snackbar("Error", msg,
          backgroundColor: ErpColors.solidError,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      actioningId.value = null;
    }
  }
}
