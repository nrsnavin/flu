import 'package:get/get.dart';
import '../services/api_service.dart';

class AddSupplierController extends GetxController {
  // Fields
  final nameCtrl = ''.obs;
  final phoneCtrl = ''.obs;
  final gstinCtrl = ''.obs;
  final emailCtrl = ''.obs;
  final addressCtrl = ''.obs;
  final contactPersonCtrl = ''.obs;

  final loading = false.obs;

  // ───────────────────────────────
  bool validate() {
    if (nameCtrl.value.isEmpty) {
      Get.snackbar("Validation Error", "Supplier name is required");
      return false;
    }
    if (phoneCtrl.value.isEmpty) {
      Get.snackbar("Validation Error", "Phone number is required");
      return false;
    }
    if (gstinCtrl.value.isEmpty) {
      Get.snackbar("Validation Error", "GSTIN is required");
      return false;
    }
    return true;
  }

  // ───────────────────────────────
  Future<void> submit() async {
    if (!validate()) return;

    try {
      loading.value = true;

      await SupplierApiService.dio.post(
        "/create-supplier",
        data: {
          "name": nameCtrl.value,
          "phoneNumber": phoneCtrl.value,
          "gstin": gstinCtrl.value,
          "email": emailCtrl.value,
          "address": addressCtrl.value,
          "contactPerson": contactPersonCtrl.value,
        },
      );

      Get.back(result: true);
      Get.snackbar("Success", "Supplier added successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to add supplier");
    } finally {
      loading.value = false;
    }
  }
}
