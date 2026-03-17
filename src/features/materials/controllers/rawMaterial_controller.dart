import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/RawMaterial.dart';


// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL API SERVICE
//
//  FIX: original controllers used `http://10.0.2.2:2701` (Android
//       emulator localhost). Updated to real server.
//  FIX: each controller created its own Dio instance — now a
//       single shared static instance.
// ══════════════════════════════════════════════════════════════

class MaterialApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2/materials',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  static Future<List<RawMaterialListItem>> fetchList({
    String search    = '',
    String category  = 'All',
    bool lowStock    = false,
  }) async {
    final Map<String, dynamic> q = {};
    if (search.trim().isNotEmpty) q['search'] = search.trim();
    if (category != 'All')        q['category'] = category;
    if (lowStock)                  q['lowStock'] = 'true';

    final res = await _dio.get('/get-raw-materials', queryParameters: q);
    return (res.data['materials'] as List? ?? [])
        .map((e) => RawMaterialListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<RawMaterialDetail> fetchDetail(String id) async {
    final res =
    await _dio.get('/get-raw-material-detail', queryParameters: {'id': id});
    return RawMaterialDetail.fromJson(
        res.data['material'] as Map<String, dynamic>);
  }

  static Future<void> deleteMaterial(String id) async {
    await _dio.delete('/delete-raw-material', queryParameters: {'id': id});
  }

  static Future<void> createMaterial(Map<String, dynamic> data) async {
    final res = await _dio.post('/create-raw-material', data: data);
    if (res.data['success'] != true) {
      throw Exception(res.data['message'] ?? 'Create failed');
    }
  }

  static Future<List<SupplierDropdownItem>> fetchSuppliers(
      {String search = ''}) async {
    final res = await _dio.get('/suppliers',
        queryParameters: search.isNotEmpty ? {'search': search} : null);
    return (res.data['suppliers'] as List? ?? [])
        .map((e) =>
        SupplierDropdownItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> raisePO(RaisePOPayload payload) async {
    final res = await _dio.post('/raise-po', data: payload.toJson());
    if (res.data['success'] != true) {
      throw Exception(res.data['message'] ?? 'PO creation failed');
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  MATERIAL LIST CONTROLLER
//
//  FIX: original RawMaterialListPage was StatelessWidget with
//       Get.put() as class field → stale controller on re-nav.
//  FIX: debounce worked only on search, not on category change.
//  FIX: no error state observable.
// ══════════════════════════════════════════════════════════════

class MaterialListController extends GetxController {
  final materials   = <RawMaterialListItem>[].obs;
  final isLoading   = false.obs;
  final errorMsg    = Rxn<String>();

  final search       = ''.obs;
  final category     = 'All'.obs;
  final lowStockOnly = false.obs;

  // temp values for filter sheet before applying
  final tempCategory  = 'All'.obs;
  final tempLowStock  = false.obs;

  static const List<String> kCategories = [
    'All', 'warp', 'weft', 'covering', 'Rubber', 'Chemicals',
  ];

  @override
  void onInit() {
    super.onInit();
    fetch();
    // debounce on search so typing doesn't fire per-keystroke
    debounce(search, (_) => fetch(), time: const Duration(milliseconds: 400));
  }

  Future<void> fetch() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      materials.value = await MaterialApiService.fetchList(
        search:   search.value,
        category: category.value,
        lowStock: lowStockOnly.value,
      );
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load materials';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void applyFilters() {
    category.value     = tempCategory.value;
    lowStockOnly.value = tempLowStock.value;
    fetch();
  }

  void resetFilters() {
    tempCategory.value  = 'All';
    tempLowStock.value  = false;
    category.value      = 'All';
    lowStockOnly.value  = false;
    fetch();
  }

  // Group materials by category for the list page
  Map<String, List<RawMaterialListItem>> get grouped {
    final Map<String, List<RawMaterialListItem>> map = {};
    for (final m in materials) {
      map.putIfAbsent(m.category, () => []).add(m);
    }
    return map;
  }

  int get lowStockCount => materials.where((m) => m.isLowStock).length;
}

// ══════════════════════════════════════════════════════════════
//  MATERIAL DETAIL CONTROLLER
//
//  FIX: original Get.put() at class field in StatelessWidget →
//       stale instance on re-nav.
//  FIX: fetchMaterialDetail() called in build() → refetch every
//       rebuild.
//  FIX: deleteMaterial() called non-existent /delete-raw-material
//       route. Added to backend, now wired correctly.
//  FIX: no error state, no loading state for delete.
// ══════════════════════════════════════════════════════════════

class MaterialDetailController extends GetxController {
  final String materialId;
  final VoidCallback? onSuccess;
  MaterialDetailController(this.materialId, {this.onSuccess});

  final detail     = Rxn<RawMaterialDetail>();
  final isLoading  = true.obs;
  final errorMsg   = Rxn<String>();
  final isDeleting = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      detail.value = await MaterialApiService.fetchDetail(materialId);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load material';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteMaterial() async {
    isDeleting.value = true;
    try {
      await MaterialApiService.deleteMaterial(materialId);
      _snack('Deleted', 'Material removed successfully', isError: false);
      onSuccess?.call();
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'Delete failed',
          isError: true);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isDeleting.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ADD MATERIAL CONTROLLER
//
//  FIX: original RawMaterialController used Get.off(RawMaterialListPage())
//       after create — replaced with onSuccess callback so the caller
//       handles navigation via Navigator.of(context).pop(true).
//  FIX: no supplier loading in the add form, no error handling.
// ══════════════════════════════════════════════════════════════

class AddMaterialController extends GetxController {
  final VoidCallback? onSuccess;
  AddMaterialController({this.onSuccess});

  final suppliers    = <SupplierDropdownItem>[].obs;
  final isSaving     = false.obs;
  final isLoadingSup = true.obs;

  final nameCtrl     = TextEditingController();
  final stockCtrl    = TextEditingController(text: '0');
  final minStockCtrl = TextEditingController(text: '0');
  final priceCtrl    = TextEditingController(text: '0');

  final selectedCategory = 'warp'.obs;
  final selectedSupplierId = Rxn<String>();
  final selectedSupplierName = Rxn<String>();

  static const List<String> kCategories = [
    'warp', 'weft', 'covering', 'Rubber', 'Chemicals',
  ];

  @override
  void onInit() {
    super.onInit();
    _loadSuppliers();
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    stockCtrl.dispose();
    minStockCtrl.dispose();
    priceCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadSuppliers({String search = ''}) async {
    isLoadingSup.value = true;
    try {
      suppliers.value =
      await MaterialApiService.fetchSuppliers(search: search);
    } catch (_) {
      // non-critical, show empty dropdown
    } finally {
      isLoadingSup.value = false;
    }
  }

  void searchSuppliers(String q) => _loadSuppliers(search: q);

  void selectSupplier(SupplierDropdownItem s) {
    selectedSupplierId.value   = s.id;
    selectedSupplierName.value = s.name;
  }

  Future<bool> save() async {
    if (selectedSupplierId.value == null) {
      _snack('Validation', 'Please select a supplier', isError: true);
      return false;
    }
    isSaving.value = true;
    try {
      await MaterialApiService.createMaterial({
        'name':     nameCtrl.text.trim(),
        'category': selectedCategory.value,
        'stock':    double.tryParse(stockCtrl.text) ?? 0,
        'minStock': double.tryParse(minStockCtrl.text) ?? 0,
        'price':    double.tryParse(priceCtrl.text) ?? 0,
        'supplier': selectedSupplierId.value,
      });
      _snack('Saved', 'Raw material added successfully', isError: false);
      onSuccess?.call();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'Save failed',
          isError: true);
      return false;
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  RAISE PO CONTROLLER
// ══════════════════════════════════════════════════════════════

class RaisePOController extends GetxController {
  final String materialId;
  final String? defaultSupplierId;
  final double currentPrice;
  final VoidCallback? onSuccess;
  RaisePOController({
    required this.materialId,
    this.defaultSupplierId,
    required this.currentPrice,
    this.onSuccess,
  });

  final suppliers = <SupplierDropdownItem>[].obs;
  final selectedSupplier = Rxn<SupplierDropdownItem>();
  final isSaving     = false.obs;
  final isLoadingSup = true.obs;

  final qtyCtrl   = TextEditingController();
  final priceCtrl = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    priceCtrl.text = currentPrice.toStringAsFixed(2);
    _loadSuppliers();
  }

  @override
  void onClose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadSuppliers() async {
    isLoadingSup.value = true;
    try {
      suppliers.value = await MaterialApiService.fetchSuppliers();
      // pre-select the material's supplier
      if (defaultSupplierId != null) {
        selectedSupplier.value = suppliers.firstWhereOrNull(
                (s) => s.id == defaultSupplierId);
      }
    } catch (_) {} finally {
      isLoadingSup.value = false;
    }
  }

  Future<bool> submitPO() async {
    if (selectedSupplier.value == null) {
      _snack('Validation', 'Select a supplier', isError: true);
      return false;
    }
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _snack('Validation', 'Enter a valid quantity', isError: true);
      return false;
    }
    isSaving.value = true;
    try {
      await MaterialApiService.raisePO(RaisePOPayload(
        materialId:  materialId,
        supplierId:  selectedSupplier.value!.id,
        quantity:    qty,
        price:       double.tryParse(priceCtrl.text.trim()) ?? currentPrice,
      ));
      _snack('PO Raised', 'Purchase order created successfully',
          isError: false);
      onSuccess?.call();
      return true;
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'PO creation failed',
          isError: true);
      return false;
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
      return false;
    } finally {
      isSaving.value = false;
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