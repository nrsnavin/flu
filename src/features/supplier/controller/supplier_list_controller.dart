// ══════════════════════════════════════════════════════════════
//  SUPPLIER CONTROLLERS
//  File: lib/src/features/supplier/controllers/supplier_controllers.dart
//
//  SupplierListController  — paginated list + debounced search + delete
//  SupplierDetailController — fetches fresh supplier + recent POs
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../services/api_service.dart';

// ══════════════════════════════════════════════════════════════
//  SupplierListController
// ══════════════════════════════════════════════════════════════
class SupplierListController extends GetxController {
  final suppliers     = <Map<String, dynamic>>[].obs;
  final loading       = false.obs;
  final isMoreLoading = false.obs;
  final searchText    = ''.obs;

  int  _page    = 1;
  bool _hasMore = true;
  static const _limit = 20;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchSuppliers(reset: true);
  }

  void onSearchChanged(String value) {
    searchText.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      fetchSuppliers(reset: true);
    });
  }

  Future<void> fetchSuppliers({bool reset = false}) async {
    if (loading.value || isMoreLoading.value) return;
    if (reset) {
      _page    = 1;
      _hasMore = true;
      suppliers.clear();
    }
    if (!_hasMore) return;

    try {
      _page == 1
          ? loading.value = true
          : isMoreLoading.value = true;

      final res = await SupplierApiService.dio.get(
        '/get-suppliers',
        queryParameters: {
          'page':   _page,
          'limit':  _limit,
          'search': searchText.value,
        },
      );

      final list = res.data['suppliers'] as List? ?? [];
      if (list.length < _limit) _hasMore = false;
      suppliers.addAll(List<Map<String, dynamic>>.from(list));
      _page++;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? 'Failed to load suppliers';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value       = false;
      isMoreLoading.value = false;
    }
  }

  Future<void> deleteSupplier(String id) async {
    try {
      await SupplierApiService.dio
          .delete('/delete-supplier', queryParameters: {'id': id});
      suppliers.removeWhere((s) => s['_id']?.toString() == id);
      Get.snackbar('Deleted', 'Supplier deactivated',
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } on DioException catch (e) {
      Get.snackbar(
          'Error',
          e.response?.data?['message'] as String? ?? 'Failed to delete',
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  bool get hasMore => _hasMore;

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}

// ══════════════════════════════════════════════════════════════
//  SupplierDetailController
// ══════════════════════════════════════════════════════════════
class SupplierDetailController extends GetxController {
  final String supplierId;
  SupplierDetailController({required this.supplierId});

  // ── Supplier state ─────────────────────────────────────────
  final isLoading  = true.obs;
  final errorMsg   = Rxn<String>();
  final supplier   = <String, dynamic>{}.obs;

  // ── PO state (paginated) ───────────────────────────────────
  final pos               = <Map<String, dynamic>>[].obs;
  final isPosLoading      = true.obs;
  final isPosMoreLoading  = false.obs;

  int  _posPage    = 1;
  bool _posHasMore = true;
  static const _posLimit = 10;

  bool get posHasMore => _posHasMore;

  static final Dio _dio = SupplierApiService.dio;

  @override
  void onInit() {
    super.onInit();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([fetchSupplier(), fetchPos(reset: true)]);
  }

  Future<void> refresh() => _loadAll();

  // ── Fetch supplier ─────────────────────────────────────────
  Future<void> fetchSupplier() async {
    try {
      isLoading.value = true;
      errorMsg.value  = null;
      final res = await _dio
          .get('/get-supplier-detail', queryParameters: {'id': supplierId});
      supplier.value =
      Map<String, dynamic>.from(res.data['supplier'] as Map);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load supplier';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Fetch POs (paginated) ──────────────────────────────────
  Future<void> fetchPos({bool reset = false}) async {
    if (isPosMoreLoading.value) return;
    if (reset) {
      _posPage    = 1;
      _posHasMore = true;
      pos.clear();
    }
    if (!_posHasMore) return;

    try {
      _posPage == 1
          ? isPosLoading.value = true
          : isPosMoreLoading.value = true;

      final res = await _dio.get(
        '/get-pos',
        queryParameters: {
          'supplierId': supplierId,
          'page':       _posPage,
          'limit':      _posLimit,
        },
      );
      final list = res.data['pos'] as List? ?? [];
      if (list.length < _posLimit) _posHasMore = false;
      pos.addAll(List<Map<String, dynamic>>.from(list));
      _posPage++;
    } catch (_) {
      // Non-critical — silently fail so the rest of the page still shows
    } finally {
      isPosLoading.value      = false;
      isPosMoreLoading.value  = false;
    }
  }

  // ── Deactivate supplier ────────────────────────────────────
  Future<bool> deactivate() async {
    try {
      await _dio.delete(
          '/delete-supplier', queryParameters: {'id': supplierId});
      // Update local state immediately
      supplier['isActive'] = false;
      // ignore: invalid_use_of_protected_member
      supplier.refresh();
      Get.snackbar('Deactivated', 'Supplier marked as inactive',
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } on DioException catch (e) {
      Get.snackbar('Error',
          e.response?.data?['message'] as String? ?? 'Failed to deactivate',
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  bool get isActive => supplier['isActive'] != false;
  Map<String, dynamic> get data => supplier;
}