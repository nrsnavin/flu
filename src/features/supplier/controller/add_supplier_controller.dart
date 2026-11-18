import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/core/nav.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/api_service.dart';

// ══════════════════════════════════════════════════════════════
//  AddSupplierController — a new supplier
//
//  The fields are real text controllers now (they were plain strings fed
//  by onChanged), so "Verify" beside the GSTIN can fill the name, the
//  address and the PAN from the GST registration.
// ══════════════════════════════════════════════════════════════
class AddSupplierController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final gstinCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final contactPersonCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final panCtrl = TextEditingController();

  /// What GST they may charge: regular, composition or unregistered.
  final gstRegistration = 'regular'.obs;

  final loading = false.obs;

  Future<void> submit() async {
    if (loading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    try {
      loading.value = true;
      final gstin = gstinCtrl.text.trim().toUpperCase();

      await SupplierApiService.dio.post(
        "/create-supplier",
        data: {
          "name": nameCtrl.text.trim(),
          "phoneNumber": phoneCtrl.text.trim(),
          if (gstin.isNotEmpty) "gstin": gstin,
          "email": emailCtrl.text.trim(),
          "address": addressCtrl.text.trim(),
          "contactPerson": contactPersonCtrl.text.trim(),
          "pan": panCtrl.text.trim().toUpperCase(),
          "gstRegistration": gstRegistration.value,
        },
      );

      Get.snackbar("Success", "Supplier added successfully",
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      // closePage, not Get.back: with a notice showing, Get.back closes
      // the notice and leaves this form open for a second Save.
      closePage(true);
    } on DioException catch (e) {
      // The server's own words: "A supplier with this GSTIN is already
      // on file" is more use than "Failed to add supplier".
      final data = e.response?.data;
      final msg = data is Map && data['message'] != null ? data['message'].toString() : "Failed to add supplier";
      Get.snackbar("Error", msg,
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar("Error", "Failed to add supplier",
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [nameCtrl, phoneCtrl, gstinCtrl, emailCtrl, contactPersonCtrl, addressCtrl, panCtrl]) {
      c.dispose();
    }
    super.onClose();
  }
}
