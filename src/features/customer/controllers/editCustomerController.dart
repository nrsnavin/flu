import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';


class EditCustomerController extends GetxController {
  final Map customer;
  final VoidCallback? onSuccess;

  EditCustomerController({required this.customer, this.onSuccess});

  final formKey = GlobalKey<FormState>();
  final loading = false.obs;

  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController gstinCtrl;
  late TextEditingController contactNameCtrl;
  late TextEditingController phoneCtrl;

  final status = "".obs;
  final paymentTerms = "".obs;

  final dio = Dio(  BaseOptions(baseUrl: "http://13.233.117.153:2701/api/v2/customer"),);

  @override
  void onInit() {
    super.onInit();

    nameCtrl = TextEditingController(text: customer['name']);
    emailCtrl = TextEditingController(text: customer['email']);
    gstinCtrl = TextEditingController(text: customer['gstin']);
    contactNameCtrl =
        TextEditingController(text: customer['contactName']);
    phoneCtrl =
        TextEditingController(text: customer['phoneNumber']);

    status.value = customer['status'];
    paymentTerms.value = customer['paymentTerms'];
  }

  Future<void> updateCustomer() async {
    if (!formKey.currentState!.validate()) return;

    try {
      loading.value = true;

      final payload = {
        "_id": customer['_id'],
        "name": nameCtrl.text,
        "email": emailCtrl.text,
        "gstin": gstinCtrl.text,
        "contactName": contactNameCtrl.text,
        "phoneNumber": phoneCtrl.text,
        "status": status.value,
        "paymentTerms": paymentTerms.value,
      };

      final res=await dio.put("/update", data: payload);

      Get.snackbar("Updated", "Customer updated successfully");
      onSuccess?.call(); // caller handles navigation
    } catch (e) {
      Get.snackbar("Error", "Failed to update customer");
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    gstinCtrl.dispose();
    contactNameCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }
}