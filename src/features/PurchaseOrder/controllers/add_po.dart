import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/po_models.dart';
import '../services/api.dart';
import '../../../common_widgets/reason_dialog.dart';

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

  /// Set the material on a row and, if the form's supplier slot is
  /// still empty, auto-pick the material's default supplier. We never
  /// override a supplier the user has already chosen — POs are
  /// single-supplier and silently swapping it would invalidate other
  /// rows.
  void setRowMaterial(int rowIndex, MaterialMini? mat) {
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    rows[rowIndex].material = mat;
    rows.refresh();
    if (mat == null) return;
    if (selectedSupplier.value == null && mat.defaultSupplierId != null) {
      final match =
          suppliers.firstWhereOrNull((s) => s.id == mat.defaultSupplierId);
      if (match != null) selectedSupplier.value = match;
    }
  }

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

    // Editing an existing PO writes an audit fingerprint on the server,
    // which requires a reason. Prompt before we start submitting.
    String? auditReason;
    if (mode == POFormMode.edit) {
      auditReason = await showReasonDialog(
        title: 'Edit Purchase Order',
        message: 'Editing replaces the items. A reason is recorded in the audit log.',
        confirmLabel: 'Save changes',
      );
      if (auditReason == null) return; // cancelled
    }

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
        // Backend reads `poId` (not `_id`) and requires `auditReason`.
        // expectedVersion enables the optimistic lock — the server 409s
        // if someone else saved this PO since we loaded it.
        payload["poId"] = seedData!["_id"] as String;

        payload["auditReason"] = auditReason!;

        if (seedData!["expectedVersion"] != null) {
          payload["expectedVersion"] = seedData!["expectedVersion"];
        }
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        Get.snackbar("Edit conflict",
            "Someone else changed this PO while you were editing. Go back, reload it, and apply your change again.");
      } else {
        final msg = e.response?.data is Map ? e.response?.data["message"] : null;
        Get.snackbar("Error", msg?.toString() ?? "Failed to save Purchase Order");
      }
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