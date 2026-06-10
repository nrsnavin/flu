import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';

// ══════════════════════════════════════════════════════════════
//  MachineIssueAdminController
//
//  Drives the admin Machine Issues queue:
//    GET    /api/v2/machine-issue          (with ?status= filter)
//    GET    /api/v2/machine-issue/:id
//    PUT    /api/v2/machine-issue/:id/status
//
//  Both endpoints are gated by isAdmin('admin'); ApiClient.buildClient
//  ships the cookie so they actually authorise.
// ══════════════════════════════════════════════════════════════
class MachineIssueAdminController extends GetxController {
  final items     = <Map<String, dynamic>>[].obs;
  final selected  = Rxn<Map<String, dynamic>>();
  final loading   = false.obs;
  final updating  = false.obs;
  final errorMsg  = Rxn<String>();
  final status    = 'all'.obs;

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/machine-issue',
  );

  static const statuses = [
    'all', 'open', 'acknowledged', 'in_progress', 'resolved', 'rejected',
  ];

  @override
  void onInit() {
    super.onInit();
    fetch();
    ever(status, (_) => fetch());
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get(
        '/',
        queryParameters: {'status': status.value},
      );
      final raw = (res.data is Map ? res.data['data'] : null) as List? ?? const [];
      items.value = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on DioException catch (e) {
      errorMsg.value = (e.response?.data is Map
              ? e.response?.data['message']?.toString()
              : null) ??
          'Failed to load machine issues';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> fetchDetail(String id) async {
    if (id.isEmpty) return;
    selected.value = null;
    try {
      final res = await _dio.get('/$id');
      final body = res.data is Map ? res.data['data'] : null;
      if (body is Map) {
        selected.value = Map<String, dynamic>.from(body);
      }
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        (e.response?.data is Map
                ? e.response?.data['message']?.toString()
                : null) ??
            'Failed to load issue',
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<bool> updateStatus(
    String id, {
    required String nextStatus,
    String resolutionNotes = '',
  }) async {
    if (id.isEmpty) return false;
    if (updating.value) return false;
    updating.value = true;
    try {
      final res = await _dio.put(
        '/$id/status',
        data: {'status': nextStatus, 'resolutionNotes': resolutionNotes},
      );
      final body = res.data is Map ? res.data['data'] : null;
      if (body is Map) {
        selected.value = Map<String, dynamic>.from(body);
        // Sync the row in the list view as well.
        final idx = items.indexWhere((it) => it['_id'] == id);
        if (idx >= 0) {
          items[idx] = Map<String, dynamic>.from(body);
          items.refresh();
        }
      }
      return true;
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        (e.response?.data is Map
                ? e.response?.data['message']?.toString()
                : null) ??
            'Failed to update status',
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      updating.value = false;
    }
  }
}
