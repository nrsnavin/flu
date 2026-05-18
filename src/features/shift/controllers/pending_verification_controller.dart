import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';

// ══════════════════════════════════════════════════════════════
//  PendingVerificationController
//  Drives the admin's Pending Shift Verifications page (and the
//  dashboard's Pending Shifts KPI count). Hits the new admin route:
//    GET  /api/v2/shift/pending-verification
//    POST /api/v2/shift/verify-production
// ══════════════════════════════════════════════════════════════
class PendingVerificationController extends GetxController {
  final items    = <Map<String, dynamic>>[].obs;
  final loading  = false.obs;
  final errorMsg = Rxn<String>();
  final verifying = false.obs;

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/shift',
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
      final res = await _dio.get('/pending-verification');
      final List list = (res.data['shifts'] as List?) ??
          (res.data['data'] as List?) ?? [];
      items.value = List<Map<String, dynamic>>.from(list);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ??
              'Failed to load pending shifts';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<bool> verify({
    required String shiftId,
    required double productionMeters,
    String? timer,
    String? feedback,
    String? note,
  }) async {
    try {
      verifying.value = true;
      await _dio.post('/verify-production', data: {
        'shiftId': shiftId,
        'productionMeters': productionMeters,
        if (timer != null && timer.isNotEmpty) 'timer': timer,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      Get.snackbar(
        'Verified',
        'Shift production cascaded with the final values',
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetch();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Failed to verify shift production';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      verifying.value = false;
    }
  }
}
