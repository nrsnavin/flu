import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

/// Who raised an issue, for a list row or the detail page: the operator
/// (with their department), the supervisor at the floor entry, or the
/// office login. '—' when nobody is known.
///
/// Only the operator used to be read, so an issue the office raised said
/// "—", and one raised at the floor entry named the loom's operator, who
/// had not reported it.
String machineIssueReporter(Map issue) {
  if (issue['source']?.toString() == 'floor') {
    final by = issue['reportedByName']?.toString().trim() ?? '';
    return by.isEmpty ? 'Floor entry' : '$by · floor entry';
  }
  final employee = issue['employee'] is Map ? issue['employee'] as Map : const {};
  final name = employee['name']?.toString() ?? '';
  if (name.isNotEmpty) {
    final dept = employee['department']?.toString() ?? '';
    return dept.isEmpty ? name : '$name · $dept';
  }
  final office = issue['reportedBy'] is Map
      ? (issue['reportedBy'] as Map)['name']?.toString() ?? ''
      : '';
  return office.isEmpty ? '—' : '$office · office';
}

/// The loom's operator on an issue raised at the floor entry — shown
/// beside the supervisor who raised it. '' for any other issue (an
/// operator's own report already names them).
String machineIssueOperator(Map issue) {
  if (issue['source']?.toString() != 'floor') return '';
  final employee = issue['employee'] is Map ? issue['employee'] as Map : const {};
  return employee['name']?.toString() ?? '';
}

/// What a status change sends. The notes go only when they were changed:
/// left as they were, the request says nothing of them and the server
/// keeps what it has — a note a colleague added since the sheet opened
/// included. Cleared, they are sent as cleared.
Map<String, dynamic> machineIssueStatusBody(
  String status, {
  required String notes,
  String before = '',
}) {
  final typed = notes.trim();
  return {
    'status': status,
    if (typed != before.trim()) 'resolutionNotes': typed,
  };
}

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
    baseUrl: '${ApiConfig.baseUrl}/machine-issue',
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
        backgroundColor: ErpColors.solidError,
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
        backgroundColor: ErpColors.solidError,
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      creating.value = false;
    }
  }

  /// [notesBefore] is the note the sheet opened with: the notes are sent
  /// only if [resolutionNotes] differs from it (machineIssueStatusBody).
  Future<bool> updateStatus(
    String id, {
    required String nextStatus,
    String resolutionNotes = '',
    String notesBefore = '',
  }) async {
    if (id.isEmpty) return false;
    if (updating.value) return false;
    updating.value = true;
    try {
      final res = await _dio.put(
        '/$id/status',
        data: machineIssueStatusBody(nextStatus,
            notes: resolutionNotes, before: notesBefore),
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
        backgroundColor: ErpColors.solidError,
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      updating.value = false;
    }
  }
}
