import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  AnnouncementListController
//  Admin view — full list (active + inactive).
// ══════════════════════════════════════════════════════════════
class AnnouncementListController extends GetxController {
  final items    = <Map<String, dynamic>>[].obs;
  final loading  = false.obs;
  final errorMsg = Rxn<String>();

  // Cookie-attaching factory — announcement admin routes (GET /, POST,
  // PUT, DELETE) are gated by isAdmin('admin') so a bare Dio() 401s.
  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/announcement',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    try {
      loading.value = true;
      errorMsg.value = null;
      final res = await _dio.get("/");
      final List list = res.data['data'] ?? [];
      items.value = List<Map<String, dynamic>>.from(list);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load announcements';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> deactivate(String id) async {
    try {
      await _dio.delete("/$id");
      Get.snackbar('Removed', 'Announcement deactivated',
          backgroundColor: const Color(0xFF16A34A),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      await fetch();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to deactivate';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  AnnouncementFormController
//  Drives create + edit screens. POST when `existing` is null,
//  otherwise PUT /:id.
// ══════════════════════════════════════════════════════════════
class AnnouncementFormController extends GetxController {
  final Map<String, dynamic>? existing;
  final VoidCallback? onSuccess;

  AnnouncementFormController({this.existing, this.onSuccess});

  final formKey = GlobalKey<FormState>();

  final titleCtrl       = TextEditingController();
  final bodyCtrl        = TextEditingController();
  final departmentCtrl  = TextEditingController();
  final attachmentCtrl  = TextEditingController();

  final type       = "info".obs;
  final audience   = "all".obs;
  final isPinned   = false.obs;
  final isActive   = true.obs;
  final validUntil = Rxn<DateTime>();
  final loading    = false.obs;

  bool get isEdit => existing != null;

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/announcement',
  );

  @override
  void onInit() {
    super.onInit();
    final e = existing;
    if (e != null) {
      titleCtrl.text      = e['title']         as String? ?? '';
      bodyCtrl.text       = e['body']          as String? ?? '';
      departmentCtrl.text = e['department']    as String? ?? '';
      attachmentCtrl.text = e['attachmentUrl'] as String? ?? '';
      type.value      = e['type']     as String? ?? 'info';
      audience.value  = e['audience'] as String? ?? 'all';
      isPinned.value  = e['isPinned'] == true;
      isActive.value  = e['isActive'] != false;
      final vu = e['validUntil'] as String?;
      if (vu != null) {
        try { validUntil.value = DateTime.parse(vu).toLocal(); } catch (_) {}
      }
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (audience.value == 'department' && departmentCtrl.text.trim().isEmpty) {
      Get.snackbar('Validation', 'Department is required for department audience',
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      loading.value = true;
      final payload = <String, dynamic>{
        'title':         titleCtrl.text.trim(),
        'body':          bodyCtrl.text.trim(),
        'type':          type.value,
        'audience':      audience.value,
        'department':    departmentCtrl.text.trim(),
        'isPinned':      isPinned.value,
        'attachmentUrl': attachmentCtrl.text.trim(),
        if (validUntil.value != null)
          'validUntil': validUntil.value!.toUtc().toIso8601String(),
      };
      if (isEdit) payload['isActive'] = isActive.value;

      if (isEdit) {
        await _dio.put('/${existing!['_id']}', data: payload);
      } else {
        await _dio.post('/', data: payload);
      }

      Get.snackbar(
        'Saved',
        isEdit ? 'Announcement updated' : 'Announcement posted',
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to save announcement';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    departmentCtrl.dispose();
    attachmentCtrl.dispose();
    super.onClose();
  }
}
