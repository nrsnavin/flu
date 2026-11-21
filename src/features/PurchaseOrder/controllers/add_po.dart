import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/po_models.dart';
import '../models/po_tax.dart';
import '../services/api.dart';
import '../../../common_widgets/reason_dialog.dart';

enum POFormMode { create, edit, clone }

/// A single row in the Add/Edit PO form
class POItemRow {
  MaterialMini? material;
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController quantityCtrl = TextEditingController();
  // The line's GST: filled from the material when it is picked, either
  // typed over. A blank rate is sent as "not stated", and the server
  // takes the material's, else the default.
  final TextEditingController hsnCtrl = TextEditingController();
  final TextEditingController gstCtrl = TextEditingController();
  double receivedQuantity = 0; // preserved during edit

  POItemRow({this.material, double price = 0, double quantity = 0, this.receivedQuantity = 0, String hsn = "", double? gstPercent}) {
    priceCtrl.text = price > 0 ? price.toString() : "";
    quantityCtrl.text = quantity > 0 ? quantity.toString() : "";
    hsnCtrl.text = hsn;
    gstCtrl.text = gstPercent == null ? "" : pct(gstPercent).replaceAll('%', '');
  }

  double get price => double.tryParse(priceCtrl.text) ?? 0;
  double get quantity => double.tryParse(quantityCtrl.text) ?? 0;
  double get lineTotal => price * quantity;
  String get hsn => hsnCtrl.text.trim();
  /// null when blank.
  double? get gstPercent => rateOf(gstCtrl.text);

  void dispose() {
    priceCtrl.dispose();
    quantityCtrl.dispose();
    hsnCtrl.dispose();
    gstCtrl.dispose();
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

  // ─── GST ────────────────────────────────────────────────────
  // Our state and the default rate, off Settings → Invoice. Read once;
  // if it cannot be read the preview takes 5% and CGST + SGST, and the
  // server prices the PO for real either way.
  final ourState = ''.obs;
  final defaultGst = 5.0.obs;

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
      _loadTaxSettings();

    } catch (e) {
      Get.snackbar("Error", "Failed to load form data");
    } finally {
      isDataLoading.value = false;
      // Always start with at least one row
      if (rows.isEmpty) addRow();
    }
  }

  Future<void> _loadTaxSettings() async {
    try {
      final res = await POApiService.settingsDio.get('/document');
      final s = (res.data is Map ? res.data['settings'] : null) as Map?;
      final inv = (s?['invoice'] as Map?) ?? const {};
      final code = inv['stateCode']?.toString() ?? '';
      ourState.value = code.isNotEmpty ? code : stateCodeFromGstin(s?['gstin']?.toString());
      final d = inv['defaultGstPercent'];
      if (d is num) defaultGst.value = d.toDouble();
    } catch (_) {
      // Not fatal: see above.
    }
  }

  /// A line's rate for the preview: its own, else its material's, else
  /// the default — the server's order.
  double _lineRate(POItemRow r) => r.gstPercent ?? r.material?.gstPercent ?? defaultGst.value;

  /// What the PO comes to with GST, worked out the way the server will.
  PoTax get taxPreview {
    final s = selectedSupplier.value;
    return pricePoLines(
      rows.where((r) => r.material != null).map((r) => PoTaxLine(quantity: r.quantity, rate: r.price, gstPercent: _lineRate(r))).toList(),
      supplierGstin: s?.gstin,
      ourState: ourState.value,
      noGst: noGstReason(s?.name, s?.gstRegistration),
    );
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
        hsn: item["hsn"]?.toString() ?? "",
        gstPercent: (item["gstPercent"] as num?)?.toDouble(),
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
    final row = rows[rowIndex];
    row.material = mat;
    // The material brings its HSN and rate (else the default), as on the
    // web form; either can be typed over.
    if (mat != null) {
      row.hsnCtrl.text = mat.hsn;
      row.gstCtrl.text = pct(mat.gstPercent ?? defaultGst.value).replaceAll('%', '');
    }
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
      if (r.hsn.isNotEmpty && !hsnPattern.hasMatch(r.hsn)) {
        Get.snackbar("Validation", "Row ${i + 1}: an HSN is 4 to 8 digits");
        return false;
      }
      final g = r.gstCtrl.text.trim();
      if (g.isNotEmpty && (r.gstPercent == null || r.gstPercent! < 0 || r.gstPercent! > 100)) {
        Get.snackbar("Validation", "Row ${i + 1}: GST % is from 0 to 100");
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
          "hsn": r.hsn,
          "gstPercent": r.gstPercent,
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