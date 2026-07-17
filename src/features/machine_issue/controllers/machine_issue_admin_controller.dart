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
  final creating  = false.obs;
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

  // Admin-raised issue. The backend POST / accepts an admin with no
  // linked employee (source: "admin", recorded against the admin user)
  // — the same path the web "Report machine issue" form uses. On success
  // the new row is prepended so it shows immediately without a refetch.
  Future<bool> create({
    required String machineId,
    required String title,
    required String description,
    String severity = 'medium',
  }) async {
    if (creating.value) return false;
    creating.value = true;
    try {
      final res = await _dio.post('/', data: {
        'machineId':   machineId,
        'title':       title.trim(),
        'description': description.trim(),
        'severity':    severity,
      });
      final body = res.data is Map ? res.data['data'] : null;
      if (body is Map) {
        // Only surface it in the current view if the filter would match.
        if (status.value == 'all' || status.value == (body['status'] ?? 'open')) {
          items.insert(0, Map<String, dynamic>.from(body));
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
            'Failed to report issue',
        backgroundColor: const Color(0xFFDC2626),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      creating.value = false;
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
