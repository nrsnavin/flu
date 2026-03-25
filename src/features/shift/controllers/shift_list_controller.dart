// ══════════════════════════════════════════════════════════════
//  SHIFT LIST CONTROLLER
//  File: lib/src/features/shift/controllers/shift_list_controller.dart
//
//  ADDED: Bulk production entry support.
//  BulkEntry — one per open shift, owns its TextEditingControllers
//              and a reactive meter count for the live running total.
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/shiftModel.dart';

// ── Per-shift entry holder ────────────────────────────────────
class BulkEntry {
  final ShiftModel shift;
  final TextEditingController productionCtrl;
  final TextEditingController timerCtrl;
  final TextEditingController feedbackCtrl;
  final RxInt liveMeters; // updated on every keystroke

  BulkEntry(this.shift)
      : productionCtrl = TextEditingController(),
        timerCtrl      = TextEditingController(text: '00:00:00'),
        feedbackCtrl   = TextEditingController(),
        liveMeters     = 0.obs;

  void dispose() {
    productionCtrl.dispose();
    timerCtrl.dispose();
    feedbackCtrl.dispose();
  }

  /// Returns an error string if invalid, null if OK.
  String? validate() {
    final v = int.tryParse(productionCtrl.text.trim());
    if (v == null || v < 0) {
      return '${shift.machineName.isNotEmpty ? shift.machineName : "A machine"}: '
          'enter a valid production number';
    }
    return null;
  }

  Map<String, dynamic> toPayload() => {
    'id':         shift.id,
    'production': int.parse(productionCtrl.text.trim()),
    'timer':      timerCtrl.text.trim().isNotEmpty
        ? timerCtrl.text.trim()
        : '00:00:00',
    'feedback':   feedbackCtrl.text.trim(),
  };
}

// ══════════════════════════════════════════════════════════════
//  SHIFT LIST CONTROLLER
// ══════════════════════════════════════════════════════════════
class ShiftControllerView extends GetxController {
  final shifts    = <ShiftModel>[].obs;
  final isLoading = false.obs;

  // ── Bulk entry state ───────────────────────────────────────
  final bulkEntries     = <BulkEntry>[].obs;
  final isBulkSaving    = false.obs;
  final bulkTotalMeters = 0.obs; // live sum across all entries

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  void onInit() {
    super.onInit();
    fetchOpenShifts();
  }

  @override
  void onClose() {
    _disposeBulkEntries();
    super.onClose();
  }

  // ── Fetch open shifts ──────────────────────────────────────
  Future<void> fetchOpenShifts() async {
    try {
      isLoading.value = true;
      final response  = await _dio.get('/shift/open');
      shifts.value    = (response.data['shifts'] as List)
          .map((e) => ShiftModel.fromJson(e))
          .toList();
    } catch (e) {
      Get.snackbar(
        'Error', 'Failed to load shifts',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ── Bulk entry helpers ─────────────────────────────────────

  /// Call before opening the bulk sheet.
  /// Creates one BulkEntry per currently open shift and wires
  /// up listeners to keep bulkTotalMeters in sync.
  void initBulkEntries() {
    _disposeBulkEntries();
    final entries = shifts
        .where((s) => s.status == 'open')
        .map((s) => BulkEntry(s))
        .toList();

    for (final e in entries) {
      e.productionCtrl.addListener(() {
        e.liveMeters.value =
            int.tryParse(e.productionCtrl.text.trim()) ?? 0;
        _recalcTotal();
      });
    }

    bulkEntries.assignAll(entries);
    bulkTotalMeters.value = 0;
  }

  void _recalcTotal() {
    bulkTotalMeters.value =
        bulkEntries.fold(0, (s, e) => s + e.liveMeters.value);
  }

  void _disposeBulkEntries() {
    for (final e in bulkEntries) {
      e.dispose();
    }
    bulkEntries.clear();
    bulkTotalMeters.value = 0;
  }

  /// Validates every entry, then POSTs to the bulk endpoint.
  /// Returns true on success so the sheet can close itself.
  Future<bool> bulkSave() async {
    // Validate all before touching the network
    for (final e in bulkEntries) {
      final err = e.validate();
      if (err != null) {
        Get.snackbar(
          'Validation', err,
          backgroundColor: const Color(0xFFD97706),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    }

    isBulkSaving.value = true;
    try {
      await _dio.post(
        '/shift/bulk-enter-production',
        data: {
          'entries': bulkEntries.map((e) => e.toPayload()).toList(),
        },
      );

      Get.snackbar(
        'Saved',
        '${bulkEntries.length} shift${bulkEntries.length == 1 ? '' : 's'} updated',
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      _disposeBulkEntries();
      await fetchOpenShifts(); // refresh list
      return true;
    } on DioException catch (e) {
      Get.snackbar(
        'Save Failed',
        e.response?.data?['message'] as String? ?? 'Failed to save',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e) {
      Get.snackbar(
        'Error', e.toString(),
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