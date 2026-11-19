import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ── The day a notice is valid until ───────────────────────────
//
// "Valid until the 20th" is up through the 20th. The phone used to send
// its own midnight on that day as an instant — 18:30 UTC the evening
// before — and the notice came down as its last day began. It sends the
// day now, and the server keeps it as a day.

/// What a save sends of the end date: the day picked, as a day. On an
/// edit a cleared date is sent as null, so the server takes it away —
/// it used to be left out, which the server read as "no change", and
/// the ✕ beside the date did nothing.
Map<String, dynamic> announcementValidity(DateTime? validUntil,
    {required bool isEdit}) {
  if (validUntil == null) return isEdit ? {'validUntil': null} : {};
  String two(int n) => n.toString().padLeft(2, '0');
  return {
    'validUntil':
        '${validUntil.year}-${two(validUntil.month)}-${two(validUntil.day)}',
  };
}

/// The first and last day the "valid until" picker offers.
DateTime announcementPickerFirstDay(DateTime now) =>
    DateTime(now.year, now.month, now.day);
DateTime announcementPickerLastDay(DateTime now) =>
    now.add(const Duration(days: 365 * 5));

/// The day the picker opens on: the notice's own end date when the picker
/// offers it, else the nearest day it does. An expired notice — the one
/// an admin opens to extend — has an end date before the first day
/// offered, and a picker opened outside its own range fails.
DateTime announcementPickerDay(DateTime? validUntil, DateTime now) {
  final first = announcementPickerFirstDay(now);
  final last = announcementPickerLastDay(now);
  final wanted = validUntil ?? now.add(const Duration(days: 7));
  if (wanted.isBefore(first)) return first;
  if (wanted.isAfter(last)) return last;
  return wanted;
}

/// True once the last day a notice is valid has passed (on this phone's
/// calendar). A notice is still up on that day itself.
bool announcementExpired(dynamic validUntil, DateTime now) {
  if (validUntil == null) return false;
  final parsed = DateTime.tryParse(validUntil.toString());
  if (parsed == null) return false;
  final until = parsed.toLocal();
  final lastDay = DateTime(until.year, until.month, until.day);
  return lastDay.isBefore(DateTime(now.year, now.month, now.day));
}

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
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      await fetch();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to deactivate';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.solidError,
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
          backgroundColor: ErpColors.solidError,
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
        ...announcementValidity(validUntil.value, isEdit: isEdit),
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
        backgroundColor: ErpColors.solidSuccess,
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to save announcement';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.solidError,
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
