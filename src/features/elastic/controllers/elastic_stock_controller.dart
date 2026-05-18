import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';

// ══════════════════════════════════════════════════════════════
//  ElasticStockController
//  Wraps the three new admin-facing elastic stock endpoints:
//    GET  /api/v2/elastic/:id/stock       (AUTH)
//    GET  /api/v2/elastic/stock-summary   (ADMIN)
//    POST /api/v2/elastic/:id/adjust-stock (ADMIN)
//
//  One controller covers both the per-elastic detail view and the
//  global stock map — they call different methods so the screens
//  can each `Get.put(ElasticStockController())` with a tag.
// ══════════════════════════════════════════════════════════════
class ElasticStockController extends GetxController {
  // ── Per-elastic detail state ────────────────────────────
  final elastic       = Rxn<Map<String, dynamic>>();
  final stock         = 0.0.obs;
  final quantityProduced = 0.0.obs;
  final movements     = <Map<String, dynamic>>[].obs;
  final loading       = false.obs;
  final errorMsg      = Rxn<String>();
  final adjusting     = false.obs;

  // ── Summary (stock map) state ───────────────────────────────
  final summary       = <Map<String, dynamic>>[].obs;
  final summaryLoading = false.obs;
  final summaryErrorMsg = Rxn<String>();

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/elastic',
  );

  Future<void> fetchStock(String elasticId) async {
    try {
      loading.value = true;
      errorMsg.value = null;
      final res = await _dio.get('/$elasticId/stock');
      final data = res.data as Map<String, dynamic>;
      elastic.value = data['elastic'] is Map
          ? Map<String, dynamic>.from(data['elastic'] as Map)
          : null;
      stock.value = (data['stock'] as num?)?.toDouble() ?? 0;
      quantityProduced.value =
          (data['quantityProduced'] as num?)?.toDouble() ?? 0;
      final List rawMovements = (data['movements'] as List?) ?? [];
      movements.value =
          List<Map<String, dynamic>>.from(rawMovements);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ??
              'Failed to load stock';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> fetchSummary() async {
    try {
      summaryLoading.value = true;
      summaryErrorMsg.value = null;
      final res = await _dio.get('/stock-summary');
      final List list = (res.data['summary'] as List?) ??
          (res.data['data'] as List?) ?? [];
      summary.value = List<Map<String, dynamic>>.from(list);
    } on DioException catch (e) {
      summaryErrorMsg.value =
          e.response?.data?['message'] as String? ??
              'Failed to load stock summary';
    } catch (e) {
      summaryErrorMsg.value = e.toString();
    } finally {
      summaryLoading.value = false;
    }
  }

  Future<bool> adjust({
    required String elasticId,
    required double delta,
    required String reason,
  }) async {
    try {
      adjusting.value = true;
      await _dio.post('/$elasticId/adjust-stock', data: {
        'delta': delta,
        'reason': reason,
      });
      Get.snackbar(
        'Stock Adjusted',
        delta >= 0
            ? 'Added ${delta.abs()} to stock'
            : 'Removed ${delta.abs()} from stock',
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchStock(elasticId);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to adjust stock';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      adjusting.value = false;
    }
  }
}
