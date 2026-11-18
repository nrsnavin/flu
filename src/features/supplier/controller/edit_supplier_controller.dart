import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/core/nav.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/api_service.dart';

// ══════════════════════════════════════════════════════════════
//  EditSupplierController — an existing supplier
//
//  This form was written from the customer form and kept its field
//  names. A supplier has no "contactName", "paymentTerms" or "status":
//  it has contactPerson, paymentTermsDays and isActive. So three of the
//  form's fields opened blank whatever was on file, and saved nothing —
//  the server ignores names it does not know. They are the supplier's
//  own names now, with the address, PAN and GST registration the form
//  never had.
// ══════════════════════════════════════════════════════════════
class EditSupplierController extends GetxController {
  final Map supplier;

  EditSupplierController(this.supplier);

  final formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final gstinCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final panCtrl = TextEditingController();

  /// Days after a bill's date that it falls due.
  final paymentDaysCtrl = TextEditingController();

  /// What GST they may charge: regular, composition or unregistered.
  final gstRegistration = 'regular'.obs;
  final isActive = true.obs;

  final loading = false.obs;

  static const registrations = ['regular', 'composition', 'unregistered'];

  String _text(String key) => (supplier[key] ?? '').toString();

  @override
  void onInit() {
    super.onInit();

    nameCtrl.text = _text("name");
    emailCtrl.text = _text("email");
    phoneCtrl.text = _text("phoneNumber");
    gstinCtrl.text = _text("gstin");
    contactCtrl.text = _text("contactPerson");
    addressCtrl.text = _text("address");
    panCtrl.text = _text("pan");

    final days = supplier["paymentTermsDays"];
    paymentDaysCtrl.text = (days is num ? days.round() : 30).toString();
    final reg = _text("gstRegistration");
    gstRegistration.value = registrations.contains(reg) ? reg : 'regular';
    isActive.value = supplier["isActive"] != false;
  }

  Future<void> updateSupplier() async {
    if (loading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    try {
      loading.value = true;

      await SupplierApiService.dio.put(
        "/edit-supplier",
        data: {
          "_id": supplier["_id"],
          "name": nameCtrl.text.trim(),
          "email": emailCtrl.text.trim(),
          "phoneNumber": phoneCtrl.text.trim(),
          // Blank is "no GSTIN": the server keeps none, rather than "".
          "gstin": gstinCtrl.text.trim().toUpperCase(),
          "contactPerson": contactCtrl.text.trim(),
          "address": addressCtrl.text.trim(),
          "pan": panCtrl.text.trim().toUpperCase(),
          "gstRegistration": gstRegistration.value,
          "paymentTermsDays": int.tryParse(paymentDaysCtrl.text.trim()) ?? 30,
          "isActive": isActive.value,
        },
      );

      Get.snackbar("Success", "Supplier updated successfully",
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      // closePage, not Get.back: with a notice showing, Get.back closes
      // the notice and leaves this form open.
      closePage(true);
    } on DioException catch (e) {
      // There was no catch at all: a refused save ended the spinner and
      // said nothing.
      final data = e.response?.data;
      final msg = data is Map && data['message'] != null ? data['message'].toString() : "Failed to update supplier";
      Get.snackbar("Error", msg,
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar("Error", "Failed to update supplier",
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [nameCtrl, emailCtrl, phoneCtrl, gstinCtrl, contactCtrl, addressCtrl, panCtrl, paymentDaysCtrl]) {
      c.dispose();
    }
    super.onClose();
  }
}
