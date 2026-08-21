import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ═════════════════════════════════════════════════════════════
//  ElasticStockController
// ═════════════════════════════════════════════════════════════
class ElasticStockController extends GetxController {
  // ── Per-elastic detail state ────────────────
  final elastic          = Rxn<Map<String, dynamic>>();
  final stock            = 0.0.obs;
  final available        = 0.0.obs;
  final reservedStock    = 0.0.obs;
  final minStock         = 0.0.obs;
  final isLowStock       = false.obs;
  final quantityProduced = 0.0.obs;
  final movements        = <Map<String, dynamic>>[].obs;
  final loading          = false.obs;
  final errorMsg         = Rxn<String>();
  final adjusting        = false.obs;

  // ── Summary (stock map) state ───────────────────
  final summary         = <Map<String, dynamic>>[].obs;
  final summaryLoading  = false.obs;
  final summaryErrorMsg = Rxn<String>();

  // ── Reconcile state ─────────────────────────────
  final drifts           = <Map<String, dynamic>>[].obs;
  final reconcileLoading = false.obs;
  final reconcileError   = Rxn<String>();

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/elastic',
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
      stock.value         = (data['stock']         as num?)?.toDouble() ?? 0;
      available.value     = (data['available']     as num?)?.toDouble() ?? stock.value;
      reservedStock.value = (data['reservedStock'] as num?)?.toDouble() ?? 0;
      minStock.value      = (data['minStock']      as num?)?.toDouble() ?? 0;
      quantityProduced.value =
          (data['quantityProduced'] as num?)?.toDouble() ?? 0;
      isLowStock.value =
          (elastic.value?['isLowStock'] as bool?) ??
          (minStock.value > 0 && stock.value <= minStock.value);
      final List rawMovements = (data['movements'] as List?) ?? [];
      movements.value = List<Map<String, dynamic>>.from(rawMovements);
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

  Future<void> fetchReconcile() async {
    try {
      reconcileLoading.value = true;
      reconcileError.value = null;
      final res = await _dio.get('/reconcile');
      final List list = (res.data['drifts'] as List?) ?? [];
      drifts.value = List<Map<String, dynamic>>.from(list);
    } on DioException catch (e) {
      reconcileError.value =
          e.response?.data?['message'] as String? ??
              'Failed to load reconcile report';
    } catch (e) {
      reconcileError.value = e.toString();
    } finally {
      reconcileLoading.value = false;
    }
  }

  /// Manual stock adjustment.
  ///
  /// [force] passes `force: true` in the request body so the backend
  /// percentage cap (|delta| > max(100, 50% of currentStock)) lets
  /// the write through. The UI should set this only after a second
  /// confirm dialog acknowledging the large magnitude.
  ///
  /// Returns a result struct with `ok`, the raw error message (so the
  /// caller can render the threshold-cap explainer), and whether the
  /// failure looks like the magnitude cap.
  Future<AdjustResult> adjust({
    required String elasticId,
    required double delta,
    required String reason,
    bool force = false,
  }) async {
    try {
      adjusting.value = true;
      await _dio.post('/$elasticId/adjust-stock', data: {
        'delta':  delta,
        'reason': reason,
        if (force) 'force': true,
      });
      Get.snackbar(
        'Stock Adjusted',
        delta >= 0
            ? 'Added ${delta.abs()} to stock'
            : 'Removed ${delta.abs()} from stock',
        backgroundColor: ErpColors.solidSuccess,
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchStock(elasticId);
      return const AdjustResult(ok: true);
    } on DioException catch (e) {
      final msg = (e.response?.data?['message'] as String?)
          ?? 'Failed to adjust stock';
      // Heuristic: the backend message starts with "Magnitude " when
      // the percentage cap kicked in. Used by the page to offer the
      // force-retry confirm.
      final isCap = msg.startsWith('Magnitude ');
      if (!isCap) {
        Get.snackbar('Error', msg,
            backgroundColor: ErpColors.solidError,
            colorText: const Color(0xFFFFFFFF),
            snackPosition: SnackPosition.BOTTOM);
      }
      return AdjustResult(ok: false, message: msg, magnitudeCap: isCap);
    } finally {
      adjusting.value = false;
    }
  }

  /// Persist the low-stock threshold via the dedicated PATCH route.
  Future<bool> setMinStock(String elasticId, double value) async {
    try {
      final res = await _dio.patch('/$elasticId/min-stock', data: {
        'minStock': value,
      });
      final body = res.data as Map<String, dynamic>;
      minStock.value = (body['minStock'] as num?)?.toDouble() ?? value;
      isLowStock.value = (body['isLowStock'] as bool?) ??
          (minStock.value > 0 && stock.value <= minStock.value);
      Get.snackbar(
        'Min Stock Updated',
        'Threshold set to ${minStock.value.toStringAsFixed(0)}',
        backgroundColor: ErpColors.solidSuccess,
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update min stock';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }
}

class AdjustResult {
  final bool ok;
  final String? message;
  final bool magnitudeCap;
  const AdjustResult({
    required this.ok,
    this.message,
    this.magnitudeCap = false,
  });
}
