import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/features/Job/models/order_model.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;


class ElasticInput {
  final String elasticId;
  final String elasticName;
  final int maxQty;
  final TextEditingController qtyController = TextEditingController();

  ElasticInput({
    required this.elasticId,
    required this.elasticName,
    required this.maxQty,
  });

  void dispose() => qtyController.dispose();
}

class AddJobOrderController extends GetxController {
  final VoidCallback? onSuccess;
  AddJobOrderController({this.onSuccess});

  static final _dio = Dio(BaseOptions(
    baseUrl: "http://13.233.117.153:2701/api/v2",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final elasticInputs = <ElasticInput>[].obs;
  final isSubmitting = false.obs;
  // FIX: track initialised flag so initFromOrder doesn't re-run in build()
  bool _initialised = false;
  late OrderModel order;

  // FIX: guard prevents reset on every build() rebuild
  void initFromOrder(OrderModel o) {
    if (_initialised) return;
    _initialised = true;
    order = o;
    elasticInputs.clear();
    for (final e in o.pendingElastic) {
      if (e.quantity > 0) {
        elasticInputs.add(ElasticInput(
          elasticId: e.elasticId,
          elasticName: e.elasticName,
          maxQty: e.quantity,
        ));
      }
    }
  }

  Future<void> submitJobOrder() async {
    final items = <Map<String, dynamic>>[];
    for (final e in elasticInputs) {
      final qty = double.tryParse(e.qtyController.text) ?? 0;
      if (qty > 0) {
        if (qty > e.maxQty) {
          Get.snackbar(
            "Validation Error",
            "Qty for ${e.elasticName} exceeds pending ${e.maxQty}",
            backgroundColor: const Color(0xFFD97706),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
        items.add({"elastic": e.elasticId, "quantity": qty});
      }
    }

    if (items.isEmpty) {
      Get.snackbar(
        "Validation Error",
        "Enter at least one elastic quantity",
        backgroundColor: const Color(0xFFD97706),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    bool success = false;
    try {
      isSubmitting.value = true;
      // FIX: was using JobApi static class — consolidated into _dio directly
      await _dio.post("/job/create", data: {
        "orderId":  order.id,
        "date":     DateTime.now().toIso8601String().split('T')[0],
        "elastics": items,
        // 🪪 Actor attached so the backend records who created the job
        "actor":    buildActorPayload(),
      });
      success = true;
      Get.snackbar(
        "Job Order Created",
        "Preparatory (Warping & Covering) programs generated",
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on DioException catch (e) {
      // FIX: was missing catch — silent failure before
      final msg = e.response?.data?['message'] ?? "Failed to create job order";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
      // FIX: was Get.back() BEFORE snackbar — snackbar never showed
      if (success) onSuccess?.call();
    }
  }

  @override
  void onClose() {
    for (final e in elasticInputs) e.dispose();
    super.onClose();
  }
}