import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../core/request_id.dart';

// ══════════════════════════════════════════════════════════════
//  PACKING ENTRY CONTROLLER (worker)
//
//  GET  /packing/jobs-packing                    → active packing-ready jobs
//  GET  /packing/employees-by-department/checking→ checker dropdown
//  GET  /packing/employees-by-department/packing → packer dropdown
//  GET  /wastage/job-operators?id=<jobId>        → shift-presence guard
//                                                  (reused; same data
//                                                  populates the
//                                                  "Shift Not Logged"
//                                                  dialog)
//  POST /packing/create-packing                  → submit a packing record
//
//  Field names match the backend contract — see api/packing.js
//  POST handler. Required: job, elastic, meter, netWeight, tareWeight,
//  grossWeight, checkedBy, packedBy. Optional: joints, stretch, size.
// ══════════════════════════════════════════════════════════════
class EmpPackingEntryController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  // ── Jobs list state ──────────────────────────────────
  final jobs       = <Map<String, dynamic>>[].obs;
  final isLoading  = true.obs;
  final errorMsg   = Rxn<String>();

  // ── Employee dropdowns ───────────────────────────────
  final checkingEmployees = <Map<String, dynamic>>[].obs;
  final packingEmployees  = <Map<String, dynamic>>[].obs;
  final isEmpLoading      = false.obs;

  // ── Shift-presence guard ───────────────────────────────
  // Distinct list of employees who logged shifts on the job. Used
  // ONLY to decide whether any shift exists — the packing form
  // doesn't expose an operator picker (checked/packed come from
  // dept dropdowns). If this list is empty after fetch, the form
  // blocks with a "Shift Not Logged" dialog. We reuse the wastage
  // endpoint because the shape is identical and adding a duplicate
  // route on /packing would just be noise.
  final jobOperators     = <Map<String, dynamic>>[].obs;
  final isLoadingJobOps  = false.obs;
  final lastFetchedJob   = Rxn<String>();

  // ── Form state ─────────────────────────────────────────
  final selectedElasticId   = Rxn<String>();
  final selectedCheckedById = Rxn<String>();
  final selectedPackedById  = Rxn<String>();

  final meterCtrl   = TextEditingController();
  final jointsCtrl  = TextEditingController();
  final stretchCtrl = TextEditingController();
  final sizeCtrl    = TextEditingController();
  final tareCtrl    = TextEditingController();
  final netCtrl     = TextEditingController();
  final grossCtrl   = TextEditingController();

  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchJobs();
  }

  @override
  void onClose() {
    meterCtrl.dispose();
    jointsCtrl.dispose();
    stretchCtrl.dispose();
    sizeCtrl.dispose();
    tareCtrl.dispose();
    netCtrl.dispose();
    grossCtrl.dispose();
    super.onClose();
  }

  void _clearForm() {
    meterCtrl.clear();
    jointsCtrl.clear();
    stretchCtrl.clear();
    sizeCtrl.clear();
    tareCtrl.clear();
    netCtrl.clear();
    grossCtrl.clear();
    selectedElasticId.value   = null;
    selectedCheckedById.value = null;
    selectedPackedById.value  = null;
  }

  // ── Jobs ────────────────────────────────────────────────
  Future<void> fetchJobs() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res  = await _dio.get('/packing/jobs-packing');
      final body = SafeJson.asMap(res.data);
      final raw  = body['jobs'] is List
          ? SafeJson.asMapList(body['jobs'])
          : (res.data is List
              ? SafeJson.asMapList(res.data)
              : SafeJson.asMapList(body['data']));
      jobs.assignAll(raw);
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load packing jobs';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Employees ──────────────────────────────────────────
  Future<void> loadEmployees() async {
    if (checkingEmployees.isNotEmpty && packingEmployees.isNotEmpty) return;
    isEmpLoading.value = true;
    try {
      final results = await Future.wait([
        _dio.get('/packing/employees-by-department/checking'),
        _dio.get('/packing/employees-by-department/packing'),
      ]);
      checkingEmployees.assignAll(_parseEmployees(results[0].data));
      packingEmployees.assignAll(_parseEmployees(results[1].data));
    } on DioException catch (e) {
      _snack(
        'Error',
        SafeJson.apiErrorMessage(e.response?.data) ??
            'Failed to load teammates',
        isError: true,
      );
    } finally {
      isEmpLoading.value = false;
    }
  }

  List<Map<String, dynamic>> _parseEmployees(dynamic data) {
    final body = SafeJson.asMap(data);
    if (body['employees'] is List) return SafeJson.asMapList(body['employees']);
    if (data is List)              return SafeJson.asMapList(data);
    if (body['data'] is List)      return SafeJson.asMapList(body['data']);
    return const [];
  }

  // ── Shift presence ────────────────────────────────────
  // Reuses /wastage/job-operators — same data, no need to duplicate
  // the route on the packing router. Empty result → no shift logged.
  Future<void> fetchJobOperators(String jobId) async {
    if (jobId.isEmpty) return;
    if (lastFetchedJob.value == jobId && jobOperators.isNotEmpty) return;

    isLoadingJobOps.value = true;
    jobOperators.clear();

    try {
      final res  = await _dio.get('/wastage/job-operators',
          queryParameters: {'id': jobId});
      final body = SafeJson.asMap(res.data);
      jobOperators.assignAll(SafeJson.asMapList(body['operators']));
      lastFetchedJob.value = jobId;
    } on DioException catch (e) {
      _snack(
        'Error',
        SafeJson.apiErrorMessage(e.response?.data) ??
            'Failed to check shift presence',
        isError: true,
      );
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isLoadingJobOps.value = false;
    }
  }

  // Idempotency key for the current packing, as in the admin app. Kept
  // across resends of the SAME entry (a timeout may have landed on the
  // server, which records each key once) and rotated when anything sent
  // changes or after a confirmed save, so a resend can't pack the same
  // roll twice and an edited resubmit isn't swallowed as a duplicate.
  String? _requestId;
  String? _requestSig;

  // ── Submit ─────────────────────────────────────────────
  Future<bool> submit({required String jobId}) async {
    final meter   = double.tryParse(meterCtrl.text.trim());
    final joints  = int.tryParse(jointsCtrl.text.trim());
    final stretch = stretchCtrl.text.trim();
    final size    = sizeCtrl.text.trim();
    final tare    = double.tryParse(tareCtrl.text.trim());
    final net     = double.tryParse(netCtrl.text.trim());
    final gross   = double.tryParse(grossCtrl.text.trim());

    if (jobId.isEmpty) {
      _snack('Validation', 'No job selected', isError: true);
      return false;
    }
    // Defense-in-depth: same check the dialog enforces in the UI.
    if (jobOperators.isEmpty) {
      _snack('Validation',
          'Shift not logged on this job — packing entry not allowed',
          isError: true);
      return false;
    }
    if (selectedElasticId.value == null) {
      _snack('Validation', 'Pick the elastic packed', isError: true);
      return false;
    }
    if (meter == null || meter <= 0) {
      _snack('Validation', 'Enter a valid meter value', isError: true);
      return false;
    }
    if (net == null || net <= 0) {
      _snack('Validation', 'Enter the net weight (kg)', isError: true);
      return false;
    }
    if (tare == null || tare < 0) {
      _snack('Validation', 'Enter the tare weight (kg)', isError: true);
      return false;
    }
    if (gross == null || gross <= 0) {
      _snack('Validation', 'Enter the gross weight (kg)', isError: true);
      return false;
    }
    if (selectedCheckedById.value == null) {
      _snack('Validation', 'Pick the checker', isError: true);
      return false;
    }
    if (selectedPackedById.value == null) {
      _snack('Validation', 'Pick the packer', isError: true);
      return false;
    }

    isSubmitting.value = true;
    try {
      final payload = <String, dynamic>{
        'job':         jobId,
        'elastic':     selectedElasticId.value,
        'meter':       meter,
        'joints':      joints ?? 0,
        'tareWeight':  tare,
        'netWeight':   net,
        'grossWeight': gross,
        if (stretch.isNotEmpty) 'stretch': stretch,
        if (size.isNotEmpty)    'size':    size,
        'checkedBy':   selectedCheckedById.value,
        'packedBy':    selectedPackedById.value,
      };
      final sig = jsonEncode(payload);
      if (_requestId == null || sig != _requestSig) {
        _requestId = newRequestId();
        _requestSig = sig;
      }
      await _dio.post('/packing/create-packing', data: {...payload, 'requestId': _requestId});
      _requestId = null; // the next roll is a new business event
      _clearForm();
      _snack(
        'Packing Saved',
        'Recorded ${meter.toStringAsFixed(meter.truncateToDouble() == meter ? 0 : 2)} m '
        '(${net.toStringAsFixed(2)} kg net)',
        isError: false,
      );
      await fetchJobs();
      return true;
    } on DioException catch (e) {
      _snack(
        'Error',
        SafeJson.apiErrorMessage(e.response?.data) ??
            'Failed to save packing entry',
        isError: true,
      );
      return false;
    } finally {
      isSubmitting.value = false;
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
