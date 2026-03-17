import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/covering.dart';

// ══════════════════════════════════════════════════════════════
//  COVERING API SERVICE
//
//  FIX: original covering_detail.dart (controller file) imported
//       both package:dio/dio.dart AND package:http/http.dart —
//       http package was never used, only Dio was. Dead import
//       removed. ApiService is now a clean Dio-only singleton.
// ══════════════════════════════════════════════════════════════

class CoveringApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  static Future<Map<String, dynamic>> _get(
      String path, {
        Map<String, dynamic>? query,
      }) async {
    final res = await _dio.get(path, queryParameters: query);
    if (res.data is! Map) throw Exception('Invalid API response');
    if (res.data['success'] == false) {
      throw Exception(res.data['message'] ?? 'API Error');
    }
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(
      String path, {
        dynamic data,
      }) async {
    final res = await _dio.post(path, data: data);
    if (res.data is! Map) throw Exception('Invalid API response');
    if (res.data['success'] == false) {
      throw Exception(res.data['message'] ?? 'API Error');
    }
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchList({
    String status = 'open',
    String search = '',
    int page = 1,
    int limit = 20,
  }) =>
      _get('/covering/list', query: {
        'status': status,
        'search': search,
        'page':   page,
        'limit':  limit,
      });

  static Future<Map<String, dynamic>> fetchDetail(String id) =>
      _get('/covering/detail', query: {'id': id});

  static Future<void> start(String id) =>
      _post('/covering/start', data: {'id': id});

  static Future<void> complete(String id, {String? remarks}) =>
      _post('/covering/complete', data: {
        'id': id,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      });
}

// ══════════════════════════════════════════════════════════════
//  COVERING LIST CONTROLLER
//
//  FIX: original CoveringController was used in a StatelessWidget
//       with Get.put() as a class field → stale instance on
//       re-navigation.
//  FIX: fetch(reset: true) was called from build() causing infinite
//       refetch on every widget rebuild.
// ══════════════════════════════════════════════════════════════

class CoveringListController extends GetxController {
  final list      = <CoveringListItem>[].obs;
  final isLoading = false.obs;
  final hasMore   = true.obs;
  final errorMsg  = Rxn<String>();

  final statusFilter = 'open'.obs;
  final searchQuery  = ''.obs;

  int _page = 1;
  static const int _limit = 20;

  static const List<String> kStatuses = [
    'open', 'in_progress', 'completed', 'cancelled',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchList(reset: true);
  }

  Future<void> fetchList({bool reset = false}) async {
    if (isLoading.value) return;
    if (reset) {
      _page = 1;
      list.clear();
      hasMore.value = true;
      errorMsg.value = null;
    }
    if (!hasMore.value) return;

    isLoading.value = true;
    try {
      final res = await CoveringApiService.fetchList(
        status: statusFilter.value,
        search: searchQuery.value,
        page:   _page,
        limit:  _limit,
      );
      final raw        = res['data'] as List? ?? [];
      final pagination = res['pagination'] as Map? ?? {};

      list.addAll(raw.map((e) =>
          CoveringListItem.fromJson(e as Map<String, dynamic>)));

      hasMore.value = pagination['hasMore'] == true;
      _page++;
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load coverings';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void setStatus(String s) {
    if (statusFilter.value == s) return;
    statusFilter.value = s;
    fetchList(reset: true);
  }

  void setSearch(String q) {
    searchQuery.value = q;
    fetchList(reset: true);
  }

  // Counts for summary strip
  int get openCount       => list.where((c) => c.status == 'open').length;
  int get inProgressCount => list.where((c) => c.status == 'in_progress').length;
  int get completedCount  => list.where((c) => c.status == 'completed').length;
}

// ══════════════════════════════════════════════════════════════
//  COVERING DETAIL CONTROLLER
//
//  FIX: original controller imported http package (unused).
//  FIX: completeCovering() had `String? remarks` declared as a
//       LOCAL variable inside the method — always null, so remarks
//       were NEVER sent to the API. Now an observable field.
//  FIX: Get.put() inside build() → controller re-created every rebuild.
// ══════════════════════════════════════════════════════════════

class CoveringDetailController extends GetxController {
  final String coveringId;
  CoveringDetailController(this.coveringId);

  final covering      = Rxn<CoveringDetail>();
  final isLoading     = true.obs;
  final errorMsg      = Rxn<String>();
  final isActioning   = false.obs;   // start / complete in progress

  // FIX: remarks now a proper observable field
  final remarksCtrl   = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  @override
  void onClose() {
    remarksCtrl.dispose();
    super.onClose();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await CoveringApiService.fetchDetail(coveringId);
      covering.value =
          CoveringDetail.fromJson(res['covering'] as Map<String, dynamic>);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load covering';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> startCovering() async {
    if (isActioning.value) return;
    isActioning.value = true;
    try {
      await CoveringApiService.start(coveringId);
      await fetchDetail();
      _snack('Started', 'Covering moved to IN PROGRESS', isError: false);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isActioning.value = false;
    }
  }

  Future<void> completeCovering() async {
    if (isActioning.value) return;
    isActioning.value = true;
    try {
      // FIX: now actually sends remarksCtrl text
      await CoveringApiService.complete(coveringId,
          remarks: remarksCtrl.text.trim());
      await fetchDetail();
      _snack('Completed', 'Covering marked as completed', isError: false);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isActioning.value = false;
    }
  }
}

// ── Shared snackbar ───────────────────────────────────────────
void _snack(String title, String message, {required bool isError}) {
  Get.snackbar(
    title, message,
    backgroundColor: isError
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A),
    colorText:     Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration:      const Duration(seconds: 4),
    icon: Icon(
      isError ? Icons.error_outline : Icons.check_circle_outline,
      color: Colors.white,
    ),
  );
}