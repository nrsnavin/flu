// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL LIST CONTROLLER
//  File: lib/src/features/materials/controllers/rawMaterial_list_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../models/RawMaterial.dart';


class RawMaterialListController extends GetxController {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl:        'http://13.233.117.153:2701/api/v2/materials',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── List state ─────────────────────────────────────────────
  final materials     = <RawMaterialListItem>[].obs;
  final loading       = false.obs;
  final search        = ''.obs;
  final category      = 'All'.obs;
  final lowStockOnly  = false.obs;

  // Filter sheet temp state
  final tempCategory  = 'All'.obs;
  final tempLowStock  = false.obs;

  // ── Bulk price update state ────────────────────────────────
  final isBulkSaving  = false.obs;

  final categories = [
    'All', 'warp', 'weft', 'covering', 'Rubber', 'Chemicals',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchMaterials();
    debounce(search, (_) => fetchMaterials(),
        time: const Duration(milliseconds: 400));
  }

  // ── Fetch ──────────────────────────────────────────────────
  Future<void> fetchMaterials() async {
    try {
      loading.value = true;
      final query = <String, dynamic>{};
      if (search.value.trim().isNotEmpty) query['search']   = search.value.trim();
      if (category.value != 'All')        query['category'] = category.value;
      if (lowStockOnly.value)             query['lowStock'] = true;

      final res = await _dio.get('/get-raw-materials',
          queryParameters: query);
      materials.value = (res.data['materials'] as List)
          .map((e) => RawMaterialListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      Get.snackbar('Error',
          e.response?.data?['message'] as String? ?? 'Failed to load materials',
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  void applyFilters() {
    category.value     = tempCategory.value;
    lowStockOnly.value = tempLowStock.value;
    fetchMaterials();
  }

  void resetFilters() {
    tempCategory.value = 'All';
    tempLowStock.value = false;
    category.value     = 'All';
    lowStockOnly.value = false;
    fetchMaterials();
  }

  // ── Bulk price update ──────────────────────────────────────
  /// [updates] — list of {_id, price} for every material whose price changed
  /// [reason]  — free-text label stored in priceHistory
  Future<bool> bulkUpdatePrices({
    required List<Map<String, dynamic>> updates,
    required String reason,
  }) async {
    // Only send materials where price actually changed vs current list
    final changed = updates.where((u) {
      final current = materials.firstWhereOrNull(
              (m) => m.id == u['_id']?.toString());
      if (current == null) return false;
      return (u['price'] as double) != current.price;
    }).toList();

    if (changed.isEmpty) {
      Get.snackbar(
        'No Changes',
        'All prices are the same as before — nothing to update.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    try {
      isBulkSaving.value = true;
      final res = await _dio.post('/bulk-update-prices', data: {
        'updates': changed,
        'reason':  reason.trim().isNotEmpty ? reason.trim() : 'Bulk update',
      });

      final updatedCount = res.data['updated'] as int? ?? 0;
      // Refresh list so new prices are reflected
      await fetchMaterials();

      Get.snackbar(
        '✅ Prices Updated',
        '$updatedCount material${updatedCount == 1 ? '' : 's'} updated',
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return true;
    } on DioException catch (e) {
      Get.snackbar(
        'Update Failed',
        e.response?.data?['message'] as String? ?? 'Failed to update prices',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isBulkSaving.value = false;
    }
  }
}