import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/RawMaterial.dart';
import '../../../core/app_config.dart';
import '../../../core/api_client.dart';
import 'material_group_controller.dart';
import 'material_category_store.dart';


// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL API SERVICE
//
//  FIX: original controllers used `http://10.0.2.2:2701` (Android
//       emulator localhost). Updated to real server.
//  FIX: each controller created its own Dio instance — now a
//       single shared static instance.
// ══════════════════════════════════════════════════════════════

class MaterialApiService {
  // Route through ApiClient.buildClient so the JWT cookie is attached —
  // a bare Dio(BaseOptions(...)) skips the interceptor and 401s against
  // the gated backend.
  static final Dio _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/materials',
    timeout: const Duration(seconds: 12),
  );

  static Future<List<RawMaterialListItem>> fetchList({
    String search    = '',
    String category  = 'All',
    String? groupId,
    bool lowStock    = false,
  }) async {
    final Map<String, dynamic> q = {};
    if (search.trim().isNotEmpty) q['search'] = search.trim();
    // Category and group are separate filters on the server, and
    // sending one as the other is how this stopped working: a group
    // name posted as `category` matched only the rows written under the
    // old scheme, so filtering by a group silently under-reported —
    // every material properly linked to it was missing, and an empty
    // result looks identical to "there are none".
    //
    // The server's group filter deliberately matches BOTH the link and
    // the legacy name, so this finds all of them.
    if (groupId != null && groupId.isNotEmpty) q['group'] = groupId;
    else if (category != 'All')                q['category'] = category;
    if (lowStock)                              q['lowStock'] = 'true';

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
  final groupId      = Rxn<String>();
  final lowStockOnly = false.obs;

  // temp values for filter sheet before applying
  final tempCategory  = 'All'.obs;
  final tempGroupId   = Rxn<String>();
  final tempLowStock  = false.obs;

  // Two lists, from two sources, because they are two questions. The
  // category list used to come from MaterialGroupStore, which meant
  // filtering by a group posted its NAME as `category` and found only
  // rows written before the split.
  final _groups     = MaterialGroupStore.ensure();
  final _categories = MaterialCategoryStore.ensure();

  List<String> get kCategories => _categories.categoriesWithAll;
  List<MaterialGroup> get kGroups => _groups.groups;

  @override
  void onInit() {
    super.onInit();
    _groups.load();
    _categories.load();
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
        groupId:  groupId.value,
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
    groupId.value      = tempGroupId.value;
    lowStockOnly.value = tempLowStock.value;
    fetch();
  }

  void resetFilters() {
    tempCategory.value  = 'All';
    tempGroupId.value   = null;
    tempLowStock.value  = false;
    category.value      = 'All';
    groupId.value       = null;
    lowStockOnly.value  = false;
    fetch();
  }

  /// The name of the group being filtered on, for the active-filter
  /// chip. Null when no group filter is set.
  String? get groupName {
    final id = groupId.value;
    if (id == null) return null;
    for (final g in _groups.groups) {
      if (g.id == id) return g.name;
    }
    return null;
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

  // ── Two classifications, and they are independent ──────────────
  //
  //  This screen used to ask one question and answer two. The category
  //  picker was built from MaterialGroupStore.names, and selectCategory
  //  set BOTH the category string and the group id from the same pick —
  //  so filing a yarn under a group called "Trim Tape" wrote
  //  category: "Trim Tape".
  //
  //  Two things went wrong with that, one loud and one silent:
  //
  //    loud   — the server validates categories now, so the save simply
  //             400s with "…is not a material category".
  //    silent — and this is the one that was already costing money: the
  //             elastic recipe picker, the MRP sheet and the warp/weft/
  //             covering queries all run `find({ category: "warp" })`.
  //             A yarn with category "Trim Tape" answered none of them
  //             and quietly disappeared from the warp picker. Nothing
  //             errored. It was just not there.
  //
  //  So they are asked separately now, the same way the web asks.

  /// One of the fixed five. Required.
  ///
  /// Starts EMPTY rather than 'warp': a DropdownButtonFormField throws
  /// when its `value` is not among its items, and these arrive from the
  /// server. Left blank until the list lands, and validated on save so
  /// a blank cannot be submitted.
  final selectedCategory = ''.obs;

  /// The mill's own classification. Optional — a material can exist
  /// before anybody has filed it, and "None" is a real answer.
  final selectedGroupId = Rxn<String>();

  final selectedSupplierId = Rxn<String>();
  final selectedSupplierName = Rxn<String>();

  final _groups     = MaterialGroupStore.ensure();
  final _categories = MaterialCategoryStore.ensure();

  /// The fixed five, from GET /materials/categories.
  List<String> get kCategories => _categories.categories;

  /// The mill's groups. Never the category list — if these two ever
  /// share a source again, the coupling is back.
  List<MaterialGroup> get kGroups => _groups.groups;

  void selectCategory(String name) => selectedCategory.value = name;

  /// null clears the group, which is a real choice rather than a
  /// missing one.
  void selectGroup(String? groupId) => selectedGroupId.value = groupId;

  @override
  void onInit() {
    super.onInit();
    _loadSuppliers();
    _groups.load();
    _categories.load().then((_) {
      // Default to the first category only if the person has not
      // already picked one while the request was in flight.
      if (selectedCategory.value.isEmpty && kCategories.isNotEmpty) {
        selectCategory(kCategories.first);
      }
    });
    // The store carries the built-in list from the moment it exists, so
    // the picker is never empty even before the fetch lands.
    if (selectedCategory.value.isEmpty && kCategories.isNotEmpty) {
      selectCategory(kCategories.first);
    }
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
    if (nameCtrl.text.trim().isEmpty) {
      _snack('Validation', 'Please enter a material name', isError: true);
      return false;
    }
    // Caught here rather than left to the server's 400, so the message
    // names the field instead of quoting an empty string back.
    if (selectedCategory.value.trim().isEmpty) {
      _snack('Validation', 'Please choose a category', isError: true);
      return false;
    }
    if (selectedSupplierId.value == null) {
      _snack('Validation', 'Please select a supplier', isError: true);
      return false;
    }
    isSaving.value = true;
    try {
      await MaterialApiService.createMaterial({
        'name':     nameCtrl.text.trim(),
        // Two independent fields. `group` is sent as null rather than
        // omitted when nothing is picked — "file this under nothing" is
        // a choice, and an absent key reads as "leave it alone", which
        // is a different instruction.
        'group':    selectedGroupId.value,
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