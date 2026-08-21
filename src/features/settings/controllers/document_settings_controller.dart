import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  DocumentSettingsController
//  Company branding used across printed PDFs (PO, DC, MRP, …).
//  Mirrors the web Settings › Document Settings — GET/PUT
//  /api/v2/settings/document. (The PDF-template visual designer
//  stays web-only.)
// ══════════════════════════════════════════════════════════════
class DocumentSettingsController extends GetxController {
  final loading  = false.obs;
  final saving   = false.obs;
  final errorMsg = Rxn<String>();

  final formKey = GlobalKey<FormState>();

  final companyCtrl = TextEditingController();
  final taglineCtrl = TextEditingController();
  final addressCtrl = TextEditingController(); // one line per address line
  final gstinCtrl   = TextEditingController();
  final phoneCtrl   = TextEditingController();
  final emailCtrl   = TextEditingController();
  final websiteCtrl = TextEditingController();
  final footerCtrl  = TextEditingController();
  final termsCtrl   = TextEditingController();
  final accentCtrl  = TextEditingController();

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/settings',
  );

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      loading.value = true;
      errorMsg.value = null;
      final res = await _dio.get('/document');
      final s = Map<String, dynamic>.from(res.data['settings'] as Map? ?? {});
      companyCtrl.text = s['companyName'] as String? ?? '';
      taglineCtrl.text = s['tagline'] as String? ?? '';
      final lines = (s['addressLines'] as List?)?.cast<dynamic>() ?? [];
      addressCtrl.text = lines.map((e) => e.toString()).join('\n');
      gstinCtrl.text = s['gstin'] as String? ?? '';
      phoneCtrl.text = s['phone'] as String? ?? '';
      emailCtrl.text = s['email'] as String? ?? '';
      websiteCtrl.text = s['website'] as String? ?? '';
      footerCtrl.text = s['footerNote'] as String? ?? '';
      termsCtrl.text = s['termsText'] as String? ?? '';
      accentCtrl.text = s['accentColor'] as String? ?? '';
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load settings';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    try {
      saving.value = true;
      final addressLines = addressCtrl.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final payload = <String, dynamic>{
        'companyName': companyCtrl.text.trim(),
        'tagline': taglineCtrl.text.trim(),
        'addressLines': addressLines,
        'gstin': gstinCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'website': websiteCtrl.text.trim(),
        'footerNote': footerCtrl.text.trim(),
        'termsText': termsCtrl.text.trim(),
        'accentColor': accentCtrl.text.trim(),
      };
      await _dio.put('/document', data: payload);
      Get.snackbar('Saved', 'Document settings updated',
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to save settings';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    companyCtrl.dispose();
    taglineCtrl.dispose();
    addressCtrl.dispose();
    gstinCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    websiteCtrl.dispose();
    footerCtrl.dispose();
    termsCtrl.dispose();
    accentCtrl.dispose();
    super.onClose();
  }
}
