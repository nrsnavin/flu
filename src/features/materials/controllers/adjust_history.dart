// lib/src/features/materials/controllers/stock_adjust_history_controller.dart
//
// Models + controller for the Stock Adjustment History page.
// Calls GET /materials/adjust-history with pagination, search,
// category filter and date-range (days) filter.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════
//  MODEL
// ══════════════════════════════════════════════════════════════

class AdjustHistoryEntry {
  final String materialId;
  final String materialName;
  final String category;
  final double currentStock;   // current stock at query time
  final DateTime date;
  final double adjustment;     // positive = added, negative = removed
  final double? balance;       // stock immediately after this adjustment
  final String reason;

  AdjustHistoryEntry({
    required this.materialId,
    required this.materialName,
    required this.category,
    required this.currentStock,
    required this.date,
    required this.adjustment,
    this.balance,
    required this.reason,
  });

  bool get isPositive => adjustment > 0;

  // Old stock = balance - adjustment (if balance is known)
  double? get oldStock =>
      balance != null ? balance! - adjustment : null;

  factory AdjustHistoryEntry.fromJson(Map<String, dynamic> j) =>
      AdjustHistoryEntry(
        materialId:   j['materialId']?.toString()   ?? '',
        materialName: j['materialName']?.toString() ?? '—',
        category:     j['category']?.toString()     ?? '—',
        currentStock: (j['currentStock'] as num?)?.toDouble() ?? 0,
        date: j['date'] != null
            ? DateTime.parse(j['date'] as String).toLocal()
            : DateTime.now(),
        adjustment: (j['adjustment'] as num?)?.toDouble() ?? 0,
        balance:    (j['balance']    as num?)?.toDouble(),
        reason:     j['reason']?.toString()         ?? '',
      );
}

// Groups entries under a date label for section headers in the list
class AdjustHistoryGroup {
  final String dateLabel;  // e.g. "Today", "Yesterday", "14 Mar 2026"
  final List<AdjustHistoryEntry> entries;

  AdjustHistoryGroup({required this.dateLabel, required this.entries});
}

// ══════════════════════════════════════════════════════════════
//  CONTROLLER
// ══════════════════════════════════════════════════════════════

class StockAdjustHistoryController extends GetxController {
  static const List<String> kCategories = [
    'All', 'warp', 'weft', 'covering', 'Rubber', 'Chemicals',
  ];

  static const List<int> kDayOptions = [7, 30, 90, 180, 365];

  final _dio = Dio(BaseOptions(
    baseUrl:        'http://13.233.117.153:2701/api/v2/materials',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // ── Filter state ───────────────────────────────────────────
  final searchQuery    = ''.obs;
  final filterCategory = 'All'.obs;
  final filterDays     = 90.obs;

  // ── Pagination ─────────────────────────────────────────────
  final _page     = 1;
  final totalPages = 1.obs;
  final totalCount = 0.obs;

  // ── Data ───────────────────────────────────────────────────
  final allEntries = <AdjustHistoryEntry>[].obs;
  final groups     = <AdjustHistoryGroup>[].obs;

  // ── UI state ───────────────────────────────────────────────
  final isLoading  = true.obs;
  final errorMsg   = Rxn<String>();

  // ── Summary stats ──────────────────────────────────────────
  double get totalAdded =>
      allEntries.where((e) => e.isPositive).fold(0.0, (s, e) => s + e.adjustment);

  double get totalRemoved =>
      allEntries.where((e) => !e.isPositive).fold(0.0, (s, e) => s + e.adjustment.abs());

  int get uniqueMaterials =>
      allEntries.map((e) => e.materialId).toSet().length;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  // ── Fetch ──────────────────────────────────────────────────
  Future<void> fetch({bool reset = true}) async {
    isLoading.value = true;
    errorMsg.value  = null;
    if (reset) allEntries.clear();

    try {
      final params = <String, dynamic>{
        'page':  _page,
        'limit': 100,
        'days':  filterDays.value,
      };
      if (filterCategory.value != 'All') params['category'] = filterCategory.value;
      if (searchQuery.value.trim().isNotEmpty) params['search'] = searchQuery.value.trim();

      final res = await _dio.get('/adjust-history', queryParameters: params);

      totalCount.value = (res.data['total'] as num?)?.toInt() ?? 0;
      totalPages.value = (res.data['pages'] as num?)?.toInt() ?? 1;

      final raw = res.data['adjustments'] as List? ?? [];
      allEntries.value = raw
          .map((e) => AdjustHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      _buildGroups();
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString() ??
          'Failed to load adjustment history';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Build date groups ──────────────────────────────────────
  void _buildGroups() {
    if (allEntries.isEmpty) {
      groups.clear();
      return;
    }

    final now   = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final yest  = today.subtract(const Duration(days: 1));
    final fmt   = DateFormat('dd MMM yyyy');

    final Map<String, List<AdjustHistoryEntry>> map = {};

    for (final e in allEntries) {
      final d = DateUtils.dateOnly(e.date);
      final String label;
      if (d == today)     label = 'Today';
      else if (d == yest) label = 'Yesterday';
      else                label = fmt.format(d);

      map.putIfAbsent(label, () => []).add(e);
    }

    groups.value = map.entries
        .map((kv) => AdjustHistoryGroup(
        dateLabel: kv.key, entries: kv.value))
        .toList();
  }

  // ── Filter helpers ─────────────────────────────────────────
  void setSearch(String q) {
    searchQuery.value = q;
    fetch();
  }

  void setCategory(String cat) {
    filterCategory.value = cat;
    fetch();
  }

  void setDays(int d) {
    filterDays.value = d;
    fetch();
  }
}