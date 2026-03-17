// ══════════════════════════════════════════════════════════════
//  STOCK ADJUST CONTROLLER
//  File: lib/src/features/materials/controllers/stock_adjust_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

// ── Model ──────────────────────────────────────────────────────
class StockAdjustItem {
  final String id;
  final String name;
  final String category;
  final double currentStock;
  final double minStock;
  final double price;

  // Mutable during editing
  double adjustment;      // delta — can be negative
  String reason;

  StockAdjustItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.minStock,
    required this.price,
    this.adjustment = 0,
    this.reason     = '',
  });

  double get newStock => (currentStock + adjustment).clamp(0, double.infinity);
  bool   get hasChange => adjustment != 0;
  bool   get isLowStock => currentStock <= minStock;
  bool   get willBeLowAfter => newStock <= minStock;

  factory StockAdjustItem.fromJson(Map<String, dynamic> j) => StockAdjustItem(
    id:           j['_id']?.toString()    ?? '',
    name:         j['name']?.toString()   ?? '',
    category:     j['category']?.toString() ?? '',
    currentStock: (j['stock']    as num?)?.toDouble() ?? 0,
    minStock:     (j['minStock'] as num?)?.toDouble() ?? 0,
    price:        (j['price']    as num?)?.toDouble() ?? 0,
  );
}

// ── Result model (returned by backend after submit) ────────────
class AdjustResult {
  final String id, name, category;
  final double oldStock, newStock, adjustment;
  AdjustResult({required this.id, required this.name, required this.category,
    required this.oldStock, required this.newStock, required this.adjustment});
  factory AdjustResult.fromJson(Map<String, dynamic> j) => AdjustResult(
    id:         j['id']?.toString()       ?? '',
    name:       j['name']?.toString()     ?? '',
    category:   j['category']?.toString() ?? '',
    oldStock:   (j['oldStock']   as num?)?.toDouble() ?? 0,
    newStock:   (j['newStock']   as num?)?.toDouble() ?? 0,
    adjustment: (j['adjustment'] as num?)?.toDouble() ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════
//  CONTROLLER
// ══════════════════════════════════════════════════════════════
class StockAdjustController extends GetxController {

  final _dio = Dio(BaseOptions(
    baseUrl:        'http://13.233.117.153:2701/api/v2/materials',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // ── State ──────────────────────────────────────────────────
  final isLoading    = false.obs;
  final isSubmitting = false.obs;
  final loadError    = RxnString();
  final submitError  = RxnString();
  final submitDone   = false.obs;
  final results      = <AdjustResult>[].obs;

  // All materials (source of truth from server)
  final _allItems    = <StockAdjustItem>[];

  // Filtered display list (reactive wrapper — rebuilt on filter change)
  final displayItems = <StockAdjustItem>[].obs;

  // ── Filter / search ────────────────────────────────────────
  final searchQuery    = ''.obs;
  final filterCategory = 'All'.obs;
  final filterChanged  = false.obs;  // show only items with adjustments

  // ── Global reason ──────────────────────────────────────────
  late final TextEditingController globalReasonCtrl;

  // ── TextEditingControllers map (one per item id) ───────────
  // Keyed by item.id so they survive list rebuilds
  final Map<String, TextEditingController> _adjCtrls = {};
  final Map<String, TextEditingController> _reasCtrls = {};

  TextEditingController adjCtrl(String id)  => _adjCtrls[id]!;
  TextEditingController reasCtrl(String id) => _reasCtrls[id]!;

  final categories = ['All', 'warp', 'weft', 'covering', 'Rubber', 'Chemicals'];

  @override
  void onInit() {
    super.onInit();
    globalReasonCtrl = TextEditingController(text: 'Stock audit');
    fetchMaterials();
  }

  @override
  void onClose() {
    globalReasonCtrl.dispose();
    for (final c in _adjCtrls.values)  c.dispose();
    for (final c in _reasCtrls.values) c.dispose();
    super.onClose();
  }

  // ── Computed helpers ───────────────────────────────────────
  List<StockAdjustItem> get changedItems =>
      _allItems.where((i) => i.hasChange).toList();

  int get changedCount => changedItems.length;

  double get totalIncrease => changedItems
      .where((i) => i.adjustment > 0)
      .fold(0, (s, i) => s + i.adjustment);

  double get totalDecrease => changedItems
      .where((i) => i.adjustment < 0)
      .fold(0, (s, i) => s + i.adjustment.abs());

  // ── Load ───────────────────────────────────────────────────
  Future<void> fetchMaterials() async {
    isLoading.value = true;
    loadError.value = null;
    submitDone.value = false;
    results.clear();
    try {
      final r = await _dio.get('/get-raw-materials');
      final list = (r.data['materials'] as List? ?? [])
          .map((e) => StockAdjustItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Dispose old controllers
      for (final c in _adjCtrls.values)  c.dispose();
      for (final c in _reasCtrls.values) c.dispose();
      _adjCtrls.clear();
      _reasCtrls.clear();

      // Create fresh controllers
      for (final item in list) {
        _adjCtrls[item.id]  = TextEditingController(text: '');
        _reasCtrls[item.id] = TextEditingController(text: '');
      }

      _allItems
        ..clear()
        ..addAll(list);

      _applyFilter();
    } on DioException catch (e) {
      loadError.value = e.response?.data?['message']?.toString() ?? 'Failed to load materials';
    } catch (e) {
      loadError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Filter ─────────────────────────────────────────────────
  void setSearch(String q)     { searchQuery.value    = q.toLowerCase(); _applyFilter(); }
  void setCategory(String cat) { filterCategory.value = cat;             _applyFilter(); }
  void setChangedOnly(bool v)  { filterChanged.value  = v;               _applyFilter(); }

  void _applyFilter() {
    var list = _allItems.toList();
    if (searchQuery.value.isNotEmpty) {
      list = list.where((i) =>
      i.name.toLowerCase().contains(searchQuery.value) ||
          i.category.toLowerCase().contains(searchQuery.value)).toList();
    }
    if (filterCategory.value != 'All') {
      list = list.where((i) => i.category == filterCategory.value).toList();
    }
    if (filterChanged.value) {
      list = list.where((i) => i.hasChange).toList();
    }
    displayItems.value = list;
  }

  // ── Set adjustment for one item ────────────────────────────
  // Called from the UI text field onChange
  void setAdjustment(String id, String raw) {
    final idx = _allItems.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final parsed = double.tryParse(raw);
    _allItems[idx].adjustment = parsed ?? 0;
    // Rebuild display to refresh summary counters
    _applyFilter();
  }

  void setReason(String id, String reason) {
    final idx = _allItems.indexWhere((i) => i.id == id);
    if (idx >= 0) _allItems[idx].reason = reason;
  }

  // Quick increment / decrement buttons
  void increment(String id, double step) {
    final idx = _allItems.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    _allItems[idx].adjustment += step;
    _adjCtrls[id]?.text = _fmt(_allItems[idx].adjustment);
    _applyFilter();
  }

  void decrement(String id, double step) {
    final idx = _allItems.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final newAdj = _allItems[idx].adjustment - step;
    // Don't let adjustment push stock below 0
    final minAdj = -_allItems[idx].currentStock;
    _allItems[idx].adjustment = newAdj.clamp(minAdj, double.infinity);
    _adjCtrls[id]?.text = _fmt(_allItems[idx].adjustment);
    _applyFilter();
  }

  void resetItem(String id) {
    final idx = _allItems.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    _allItems[idx].adjustment = 0;
    _allItems[idx].reason     = '';
    _adjCtrls[id]?.text  = '';
    _reasCtrls[id]?.text = '';
    _applyFilter();
  }

  void resetAll() {
    for (final item in _allItems) {
      item.adjustment = 0;
      item.reason     = '';
      _adjCtrls[item.id]?.text  = '';
      _reasCtrls[item.id]?.text = '';
    }
    _applyFilter();
  }

  // ── Submit ─────────────────────────────────────────────────
  Future<void> submitAdjustments() async {
    final changed = changedItems;
    if (changed.isEmpty) return;

    isSubmitting.value = true;
    submitError.value  = null;

    try {
      final payload = {
        'globalReason': globalReasonCtrl.text.trim().isEmpty
            ? 'Stock adjustment' : globalReasonCtrl.text.trim(),
        'adjustments': changed.map((i) => {
          '_id':        i.id,
          'adjustment': i.adjustment,
          'reason':     i.reason.trim().isEmpty ? null : i.reason.trim(),
        }).toList(),
      };

      final r = await _dio.post('/bulk-adjust-stock', data: payload);
      final raw = r.data['updated'] as List? ?? [];
      results.value = raw.map((e) => AdjustResult.fromJson(e as Map<String, dynamic>)).toList();

      submitDone.value = true;

      // Refresh the list with new stock values from server
      await fetchMaterials();

      // Also refresh the main material list if it's in memory
      try {
        // ignore: invalid_use_of_protected_member
        Get.find<dynamic>(tag: 'RawMaterialListController')?.fetchMaterials?.call();
      } catch (_) {}

    } on DioException catch (e) {
      submitError.value = e.response?.data?['message']?.toString() ?? 'Submit failed';
    } catch (e) {
      submitError.value = e.toString();
    } finally {
      isSubmitting.value = false;
    }
  }

  String _fmt(double v) {
    if (v == 0) return '';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}