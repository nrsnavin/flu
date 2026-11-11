import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../models/covering.dart';

// ═════════════════════════════════════════════════════════════
//  COVERING DETAIL CONTROLLER (worker)
//
//  GET  /covering/detail?id=
//  POST /covering/beam-entry   (covering dept only)
//
//  No start/complete/cancel exposed to workers — those remain admin.
// ═════════════════════════════════════════════════════════════
class EmpCoveringDetailController extends GetxController {
  final String coveringId;
  final bool   canRecordBeamEntries;
  EmpCoveringDetailController(this.coveringId,
      {this.canRecordBeamEntries = false});

  Dio get _dio => ApiClient.instance.dio;

  final covering     = Rxn<CoveringDetail>();
  final isLoading    = true.obs;
  final isAddingBeam = false.obs;
  final errorMsg     = Rxn<String>();

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
    beamNoCtrl.dispose();
    beamWtCtrl.dispose();
    beamNoteCtrl.dispose();
    super.onClose();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get('/covering/detail',
          queryParameters: {'id': coveringId});
      final body = SafeJson.asMap(res.data);
      final cov  = SafeJson.asMap(body['covering']);
      if (cov.isEmpty) {
        errorMsg.value = 'Covering not found';
      } else {
        covering.value = CoveringDetail.fromJson(cov);
      }
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load covering';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  int get nextBeamNo {
    final entries = covering.value?.beamEntries ?? const <BeamEntry>[];
    if (entries.isEmpty) return 1;
    return entries.map((e) => e.beamNo).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<bool> addBeamEntry() async {
    if (!canRecordBeamEntries) return false;
    final no   = int.tryParse(beamNoCtrl.text.trim());
    final wt   = double.tryParse(beamWtCtrl.text.trim());
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
      await _dio.post('/covering/beam-entry', data: {
        'id':     coveringId,
        'beamNo': no,
        'weight': wt,
        'note':   note,
      });
      beamNoCtrl.clear();
      beamWtCtrl.clear();
      beamNoteCtrl.clear();
      await fetchDetail();
      _snack('Beam Added',
          'Beam $no (${wt.toStringAsFixed(2)} kg) recorded',
          isError: false);
      return true;
    } on DioException catch (e) {
      _snack(
        'Error',
        SafeJson.apiErrorMessage(e.response?.data) ??
            'Failed to add beam entry',
        isError: true,
      );
      return false;
    } finally {
      isAddingBeam.value = false;
    }
  }

  void _snack(String title, String msg, {required bool isError}) {
    Get.snackbar(
      title, msg,
      backgroundColor: isError
          ? const Color(0xFFDC2626)
          : const Color(0xFF16A34A),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }
}
