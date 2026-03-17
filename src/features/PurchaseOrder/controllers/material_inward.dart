import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/screens/home.dart';
import '../models/po_models.dart';
import '../services/api.dart';


class InwardItemRow {
  final POItem poItem; // source PO item (read-only ref)
  final TextEditingController quantityCtrl;
  final TextEditingController remarksCtrl;

  InwardItemRow(this.poItem)
      : quantityCtrl = TextEditingController(),
        remarksCtrl = TextEditingController();

  double get receivingQty => double.tryParse(quantityCtrl.text) ?? 0;

  bool get hasError =>
      receivingQty > 0 && receivingQty > poItem.pendingQuantity;

  void dispose() {
    quantityCtrl.dispose();
    remarksCtrl.dispose();
  }
}

class MaterialInwardController extends GetxController {
  final POModel po;
  MaterialInwardController(this.po);

  late final List<InwardItemRow> inwardRows;
  final isSubmitting = false.obs;
  final inwardDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    // Only show items that still have pending quantity
    inwardRows = po.items
        .where((i) => i.pendingQuantity > 0)
        .map((i) => InwardItemRow(i))
        .toList();
  }

  void pickDate(DateTime picked) => inwardDate.value = picked;

  bool _validate() {
    if (inwardRows.every((r) => r.receivingQty <= 0)) {
      Get.snackbar("Validation", "Enter quantity for at least one item");
      return false;
    }
    for (final row in inwardRows) {
      if (row.hasError) {
        Get.snackbar(
          "Validation",
          "${row.poItem.rawMaterial?.name}: received quantity cannot exceed pending (${row.poItem.pendingQuantity})",
        );
        return false;
      }
    }
    return true;
  }

  Future<void> submit() async {
    if (!_validate()) return;

    try {
      isSubmitting.value = true;

      final items = inwardRows
          .where((r) => r.receivingQty > 0)
          .map((r) => {
        "rawMaterial": r.poItem.rawMaterial!.id,
        "quantity": r.receivingQty,
        "inwardDate": inwardDate.value.toIso8601String(),
        "remarks": r.remarksCtrl.text.trim(),
      })
          .toList();

      final res = await POApiService.dio.post(
        "/inward-stock",
        data: {"poId": po.id, "items": items},
      );

      Get.offAll(Home());
      Get.snackbar(
        "Success",
        res.data["message"] ?? "Stock inward recorded",
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to record inward");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    for (final r in inwardRows) {
      r.dispose();
    }
    super.onClose();
  }
}