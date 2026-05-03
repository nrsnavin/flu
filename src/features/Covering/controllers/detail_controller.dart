// lib/src/features/Covering/controllers/covering_detail.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/covering.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;

class CoveringApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2/covering',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  static Future<CoveringDetail> fetchDetail(String id) async {
    final res = await _dio.get('/detail', queryParameters: {'id': id});
    return CoveringDetail.fromJson(
        res.data['covering'] as Map<String, dynamic>);
  }

  static Future<void> start(String id) async {
    await _dio.post('/start', data: {'id': id, 'actor': buildActorPayload()});
  }

  static Future<void> complete(String id, {String? remarks}) async {
    await _dio.post('/complete', data: {
      'id': id,
      if (remarks != null) 'remarks': remarks,
      'actor': buildActorPayload(),
    });
  }

  static Future<void> cancel(String id, {String? remarks}) async {
    await _dio.post('/cancel', data: {
      'id': id,
      if (remarks != null) 'remarks': remarks,
      'actor': buildActorPayload(),
    });
  }

  /// POST /covering/beam-entry
  static Future<Map<String, dynamic>> addBeamEntry({
    required String coveringId,
    required int beamNo,
    required double weight,
    String note = '',
  }) async {
    final res = await _dio.post('/beam-entry', data: {
      'id':     coveringId,
      'beamNo': beamNo,
      'weight': weight,
      'note':   note,
      'actor':  buildActorPayload(),
    });
    return res.data as Map<String, dynamic>;
  }

  /// DELETE /covering/beam-entry?coveringId=&entryId=
  static Future<Map<String, dynamic>> deleteBeamEntry({
    required String coveringId,
    required String entryId,
  }) async {
    final res = await _dio.delete('/beam-entry',
        queryParameters: {'coveringId': coveringId, 'entryId': entryId});
    return res.data as Map<String, dynamic>;
  }
}

// ══════════════════════════════════════════════════════════════
//  COVERING DETAIL CONTROLLER
// ══════════════════════════════════════════════════════════════
class CoveringDetailController extends GetxController {
  final String coveringId;
  CoveringDetailController(this.coveringId);

  // ── Data ──────────────────────────────────────────────────
  final covering    = Rxn<CoveringDetail>();

  // ── UI state ──────────────────────────────────────────────
  final isLoading   = true.obs;
  final isActioning = false.obs;   // start / complete / cancel
  final isAddingBeam = false.obs;  // beam entry submit spinner
  final errorMsg    = Rxn<String>();

  // ── Form controllers ──────────────────────────────────────
  final remarksCtrl  = TextEditingController();
  final beamNoCtrl   = TextEditingController();
  final beamWtCtrl   = TextEditingController();
  final beamNoteCtrl = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  @override
  void onClose() {
    remarksCtrl.dispose();
    beamNoCtrl.dispose();
    beamWtCtrl.dispose();
    beamNoteCtrl.dispose();
    super.onClose();
  }

  // ── Fetch ─────────────────────────────────────────────────
  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      covering.value = await CoveringApiService.fetchDetail(coveringId);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load covering';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Start ─────────────────────────────────────────────────
  Future<void> startCovering() async {
    isActioning.value = true;
    try {
      await CoveringApiService.start(coveringId);
      await fetchDetail();
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'Failed to start',
          isError: true);
    } finally {
      isActioning.value = false;
    }
  }

  // ── Complete ──────────────────────────────────────────────
  Future<void> completeCovering() async {
    isActioning.value = true;
    try {
      await CoveringApiService.complete(coveringId,
          remarks: remarksCtrl.text.trim().isNotEmpty
              ? remarksCtrl.text.trim()
              : null);
      await fetchDetail();
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'Failed to complete',
          isError: true);
    } finally {
      isActioning.value = false;
    }
  }

  // ── Cancel ────────────────────────────────────────────────
  Future<void> cancelCovering({String? remarks}) async {
    isActioning.value = true;
    try {
      await CoveringApiService.cancel(coveringId, remarks: remarks);
      await fetchDetail();
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'Failed to cancel',
          isError: true);
    } finally {
      isActioning.value = false;
    }
  }

  // ── Add beam entry ────────────────────────────────────────
  Future<bool> addBeamEntry() async {
    final no  = int.tryParse(beamNoCtrl.text.trim());
    final wt  = double.tryParse(beamWtCtrl.text.trim());
    final note = beamNoteCtrl.text.trim();

    if (no == null || no < 1) {
      _snack('Validation', 'Enter a valid beam number', isError: true);
      return false;
    }
    if (wt == null || wt <= 0) {
      _snack('Validation', 'Enter a valid weight (kg)', isError: true);
      return false;
    }

    isAddingBeam.value = true;
    try {
      await CoveringApiService.addBeamEntry(
        coveringId: coveringId,
        beamNo:     no,
        weight:     wt,
        note:       note,
      );
      // Clear fields
      beamNoCtrl.clear();
      beamWtCtrl.clear();
      beamNoteCtrl.clear();
      await fetchDetail();
      _snack('Beam Added', 'Beam $no (${wt.toStringAsFixed(2)} kg) recorded',
          isError: false);
      return true;
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'Failed to add beam',
          isError: true);
      return false;
    } finally {
      isAddingBeam.value = false;
    }
  }

  // ── Delete beam entry ─────────────────────────────────────
  Future<void> deleteBeamEntry(String entryId) async {
    try {
      await CoveringApiService.deleteBeamEntry(
          coveringId: coveringId, entryId: entryId);
      await fetchDetail();
      _snack('Removed', 'Beam entry deleted', isError: false);
    } on DioException catch (e) {
      _snack('Error',
          e.response?.data?['message'] as String? ?? 'Failed to delete',
          isError: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  void _snack(String title, String msg, {required bool isError}) {
    Get.snackbar(
      title, msg,
      backgroundColor: isError
          ? const Color(0xFFDC2626)
          : const Color(0xFF16A34A),
      colorText:     Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration:      const Duration(seconds: 4),
    );
  }

  // Next suggested beam number (last + 1)
  int get nextBeamNo {
    final entries = covering.value?.beamEntries ?? [];
    if (entries.isEmpty) return 1;
    return entries.map((e) => e.beamNo).reduce((a, b) => a > b ? a : b) + 1;
  }
}