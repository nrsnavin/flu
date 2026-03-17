import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/features/Orders/models/elasticLite.dart';
import 'package:production/src/features/Orders/models/order_elastic_row.dart';
import '../models/po_models.dart';
import '../services/api.dart';

enum POFormMode { create, edit, clone }

/// A single row in the Add/Edit PO form
class POItemRow {
  MaterialMini? material;
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController quantityCtrl = TextEditingController();
  double receivedQuantity = 0; // preserved during edit

  POItemRow({this.material, double price = 0, double quantity = 0, this.receivedQuantity = 0}) {
    priceCtrl.text = price > 0 ? price.toString() : "";
    quantityCtrl.text = quantity > 0 ? quantity.toString() : "";
  }

  double get price => double.tryParse(priceCtrl.text) ?? 0;
  double get quantity => double.tryParse(quantityCtrl.text) ?? 0;
  double get lineTotal => price * quantity;

  void dispose() {
    priceCtrl.dispose();
    quantityCtrl.dispose();
  }
}

class AddPOController extends GetxController {
  // ─── Mode & seed data ───────────────────────────────────────
  final POFormMode mode;
  final Map<String, dynamic>? seedData; // editData or cloneData
  final VoidCallback? onSuccess;

  AddPOController({required this.mode, this.seedData, this.onSuccess});

  // ─── Dropdown data ──────────────────────────────────────────
  final suppliers = <SupplierMini>[].obs;
  final materials = <MaterialMini>[].obs;
  final isDataLoading = true.obs;

  // ─── Form state ─────────────────────────────────────────────
  Rx<SupplierMini?> selectedSupplier = Rx<SupplierMini?>(null);
  final rows = <POItemRow>[].obs;

  // ─── Computed ───────────────────────────────────────────────
  RxDouble get grandTotal => rows
      .fold<double>(0, (s, r) => s + r.lineTotal)
      .obs;

  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      isDataLoading.value = true;

      final results = await Future.wait([
        POApiService.supplierDio.get("/get-suppliers"),
        POApiService.materialDio.get("/get-raw-materials"),
      ]);

      suppliers.assignAll(
        (results[0].data["suppliers"] as List)
            .map((e) => SupplierMini.fromJson(e))
            .toList(),
      );

      materials.assignAll(
        (results[1].data["materials"] as List)
            .map((e) => MaterialMini.fromJson(e))
            .toList(),
      );

      // Prefill after data loads (clone / edit)
      if (seedData != null) _prefill(seedData!);

    } catch (e) {
      Get.snackbar("Error", "Failed to load form data");
    } finally {
      isDataLoading.value = false;
      // Always start with at least one row
      if (rows.isEmpty) addRow();
    }
  }

  void _prefill(Map<String, dynamic> data) {
    // Supplier
    final suppId = data["supplierId"] as String?;
    if (suppId != null) {
      selectedSupplier.value =
          suppliers.firstWhereOrNull((s) => s.id == suppId);
    }

    // Items
    rows.clear();
    for (final item in (data["items"] as List? ?? [])) {
      final matId = item["rawMaterialId"] as String?;
      final mat = matId != null
          ? materials.firstWhereOrNull((m) => m.id == matId)
          : null;

      rows.add(POItemRow(
        material: mat,
        price: (item["price"] ?? 0).toDouble(),
        quantity: (item["quantity"] ?? 0).toDouble(),
        receivedQuantity: (item["receivedQuantity"] ?? 0).toDouble(),
      ));
    }
  }

  void addRow() => rows.add(POItemRow());

  void removeRow(int index) {
    rows[index].dispose();
    rows.removeAt(index);
  }

  bool _validate() {
    if (selectedSupplier.value == null) {
      Get.snackbar("Validation", "Please select a supplier");
      return false;
    }
    if (rows.isEmpty) {
      Get.snackbar("Validation", "Add at least one item");
      return false;
    }
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.material == null) {
        Get.snackbar("Validation", "Select material for row ${i + 1}");
        return false;
      }
      if (r.quantity <= 0) {
        Get.snackbar("Validation", "Enter quantity for row ${i + 1}");
        return false;
      }
    }
    return true;
  }

  Future<void> submit() async {
    if (!_validate()) return;

    try {
      isSubmitting.value = true;

      final payload = {
        "supplier": selectedSupplier.value!.id,
        "items": rows
            .map((r) => {
          "rawMaterial": r.material!.id,
          "price": r.price,
          "quantity": r.quantity,
        })
            .toList(),
      };

      if (mode == POFormMode.edit) {
        payload["_id"] = seedData!["_id"] as String;
        await POApiService.dio.put("/edit-po", data: payload);
        Get.snackbar("Success", "Purchase Order updated");
      } else {
        // create or clone both hit /create-po
        await POApiService.dio.post("/create-po", data: payload);
        Get.snackbar(
          "Success",
          mode == POFormMode.clone ? "PO cloned successfully" : "Purchase Order created",
        );
      }
      onSuccess?.call();
    } catch (e) {
      Get.snackbar("Error", "Failed to save Purchase Order");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    for (final r in rows) {
      r.dispose();
    }
    super.onClose();
  }
}