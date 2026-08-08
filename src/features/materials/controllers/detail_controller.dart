// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL DETAIL CONTROLLER
//  File: lib/src/features/rawMaterial/controllers/raw_material_detail_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/detail_model.dart';
import '../models/yarn_lot.dart';
import '../../../core/app_config.dart';

class RawMaterialDetailController extends GetxController {
  final String materialId;
  RawMaterialDetailController({required this.materialId});

  static final Dio _dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/materials');

  /// Lots live under their own router, not under /materials.
  static final Dio _lotDio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/yarn-lots');

  // ── State ──────────────────────────────────────────────────
  final isLoading    = true.obs;
  final errorMsg     = Rxn<String>();
  final material     = Rxn<RawMaterialDetailModel>();

  // Which tab the user is viewing: 0=Inward 1=Outward 2=Ledger 3=Lots
  final activeTab    = 0.obs;

  // ── Dye lots ───────────────────────────────────────────────
  // Loaded alongside the detail rather than on tab switch: the header
  // shows how much of the stock is accounted for by lots, and that
  // figure cannot wait for somebody to open the tab.
  final lots        = <YarnLot>[].obs;
  final lotsLoading = false.obs;
  final lotsError   = Rxn<String>();

  /// What the lots account for. Deliberately NOT compared to stock as an
  /// error: yarn that came in before lot tracking has no lot, so the sum
  /// is a floor on what is present, never the whole of it.
  double get lotBalanceTotal =>
      lots.fold<double>(0, (sum, l) => sum + l.balance);

  List<YarnLot> get issuableLots =>
      lots.where((l) => l.isIssuable).toList();

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
    fetchLots();
  }

  /// Every lot of this material, spent ones included — an exhausted lot
  /// is still the answer to "which yarn did that beam come off".
  Future<void> fetchLots() async {
    try {
      lotsLoading.value = true;
      lotsError.value = null;
      final res = await _lotDio.get('/list', queryParameters: {
        'material': materialId,
        'status': 'all',
        'limit': 200,
      });
      lots.value = ((res.data as Map)['lots'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => YarnLot.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      lotsError.value =
          e.response?.data?['message'] as String? ?? 'Failed to load lots';
    } catch (e) {
      lotsError.value = 'Failed to load lots';
    } finally {
      lotsLoading.value = false;
    }
  }

  /// Open a lot against yarn that is already on the rack.
  ///
  /// The server refuses a quantity beyond what is not yet assigned to
  /// some other lot — a lot claiming more than the material holds would
  /// be read as fact by every screen downstream. Returns null on
  /// success, or the message to show.
  Future<String?> createLot({
    required String lotNo,
    required double quantity,
    String shade = '',
    String dyer = '',
  }) async {
    try {
      await _lotDio.post('/create', data: {
        'rawMaterial': materialId,
        'lotNo': lotNo.trim(),
        'quantity': quantity,
        if (shade.trim().isNotEmpty) 'shade': shade.trim(),
        if (dyer.trim().isNotEmpty) 'dyer': dyer.trim(),
      });
      await fetchLots();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String? ?? 'Could not open the lot';
    } catch (e) {
      return 'Could not open the lot';
    }
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