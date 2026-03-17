import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/api_service.dart';

class EditSupplierController extends GetxController {
  final Map supplier;

  EditSupplierController(this.supplier);

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final gstinCtrl = TextEditingController();
  final contactCtrl = TextEditingController();

  final paymentTerms = "30".obs;
  final status = "Active".obs;

  final loading = false.obs;

  final paymentOptions = ["15", "30", "45", "60"];
  final statusOptions = ["Active", "Inactive"];

  @override
  void onInit() {
    super.onInit();

    nameCtrl.text = supplier["name"] ?? "";
    emailCtrl.text = supplier["email"] ?? "";
    phoneCtrl.text = supplier["phoneNumber"] ?? "";
    gstinCtrl.text = supplier["gstin"] ?? "";
    contactCtrl.text = supplier["contactName"] ?? "";

    paymentTerms.value = supplier["paymentTerms"] ?? "30";
    status.value = supplier["status"] ?? "Active";
  }

  Future<void> updateSupplier() async {
    try {
      loading.value = true;

      await SupplierApiService.dio.put(
        "/edit-customer", // or /edit-supplier if separated
        data: {
          "_id": supplier["_id"],
          "name": nameCtrl.text.trim(),
          "email": emailCtrl.text.trim(),
          "phoneNumber": phoneCtrl.text.trim(),
          "gstin": gstinCtrl.text.trim(),
          "contactName": contactCtrl.text.trim(),
          "paymentTerms": paymentTerms.value,
          "status": status.value,
        },
      );

      Get.back(result: true);
      Get.snackbar("Success", "Supplier updated successfully");
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    gstinCtrl.dispose();
    contactCtrl.dispose();
    super.onClose();
  }
}
