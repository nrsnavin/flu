// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL DETAIL CONTROLLER
//  File: lib/src/features/rawMaterial/controllers/raw_material_detail_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/detail_model.dart';

class RawMaterialDetailController extends GetxController {
  final String materialId;
  RawMaterialDetailController({required this.materialId});

  static final Dio _dio = Dio(BaseOptions(
    baseUrl:        'http://13.233.117.153:2701/api/v2/materials',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── State ──────────────────────────────────────────────────
  final isLoading    = true.obs;
  final errorMsg     = Rxn<String>();
  final material     = Rxn<RawMaterialDetailModel>();

  // Which tab the user is viewing: 0=Inward 1=Outward 2=Ledger
  final activeTab    = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      isLoading.value = true;
      errorMsg.value  = null;
      final res = await _dio.get(
        '/get-raw-material-detail',
        queryParameters: {'id': materialId},
      );
      material.value =
          RawMaterialDetailModel.fromJson(res.data['material'] as Map<String, dynamic>);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load material';
      Get.snackbar('Error', errorMsg.value!,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteMaterial({required VoidCallback onDeleted}) async {
    try {
      await _dio.delete(
        '/delete-raw-material',
        queryParameters: {'id': materialId},
      );
      Get.snackbar('Deleted', 'Material removed',
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      onDeleted();
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data?['message'] as String? ?? 'Failed to delete',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ── Computed helpers ───────────────────────────────────────
  List<MaterialInwardModel>  get inwards  => material.value?.inwards  ?? [];
  List<MaterialOutwardModel> get outwards => material.value?.outwards ?? [];
  List<StockMovementModel>   get ledger   => material.value?.stockMovements ?? [];
}