import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/lock/open_externally.dart';
import 'package:path_provider/path_provider.dart';

import 'package:production/src/core/api_client.dart';
import '../../PurchaseOrder/services/theme.dart';

/// Drives the Material Requirement Program (MRP) screen for one job.
///
/// Everything is sourced from the authoritative backend MRP endpoints
/// (added with the outsource feature):
///   GET   /job/:id/mrp              → computed material requirement
///   GET   /job/:id/mrp.pdf          → the signed PDF sheet
///   PATCH /job/:id/production-mode  → set in-house / outsource (+vendor)
class MrpController extends GetxController {
  MrpController(this.jobId);
  final String jobId;

  // Reuse the shared client so the JWT travels with each request — the
  // MRP routes are admin-gated, and the PDF must be fetched with auth
  // (an external browser open would 401 since we auth by header).
  Dio get _dio => ApiClient.instance.dio;

  final loading   = true.obs;   // initial JSON load
  final saving    = false.obs;  // production-mode PATCH in flight
  final pdfLoading = false.obs;  // PDF fetch/open in flight
  final errorMsg  = Rxn<String>();

  final data = Rxn<Map<String, dynamic>>();

  String get productionMode =>
      data.value?['productionMode']?.toString() ?? 'in_house';
  String get outsourceVendor =>
      data.value?['outsourceVendor']?.toString() ?? '';
  bool get isOutsource => productionMode == 'outsource';

  List<Map<String, dynamic>> get materials =>
      ((data.value?['materials'] as List<dynamic>?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  List<Map<String, dynamic>> get elastics =>
      ((data.value?['elastics'] as List<dynamic>?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  bool get hasShortfall =>
      materials.any((m) => ((m['shortfall'] as num?) ?? 0) > 0);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get('/job/$jobId/mrp');
      final body = res.data is Map ? res.data as Map : const {};
      data.value = (body['data'] as Map?)?.cast<String, dynamic>();
      if (data.value == null) errorMsg.value = 'MRP data unavailable.';
    } on DioException catch (e) {
      errorMsg.value = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? 'Failed to load MRP.')
          : (e.message ?? 'Failed to load MRP.');
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> setProductionMode(String mode, {String vendor = ''}) async {
    if (saving.value) return;
    saving.value = true;
    try {
      await _dio.patch('/job/$jobId/production-mode', data: {
        'productionMode': mode,
        if (mode == 'outsource') 'outsourceVendor': vendor,
      });
      await load(); // reflect the authoritative saved state
      Get.snackbar(
        'Updated',
        mode == 'outsource' ? 'Job set to outsourced.' : 'Job set to in-house.',
        backgroundColor: ErpColors.solidSuccess,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data is Map
            ? (e.response?.data['message']?.toString() ?? 'Failed to update mode.')
            : (e.message ?? 'Failed to update mode.'),
        backgroundColor: ErpColors.solidError,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      saving.value = false;
    }
  }

  /// Fetch the signed PDF (auth header travels via the shared client)
  /// and open it with the native viewer — mirrors the Export-PDF flow
  /// already used on the job detail screen.
  Future<void> openPdf() async {
    if (pdfLoading.value) return;
    pdfLoading.value = true;
    try {
      final res = await _dio.get<List<int>>(
        '/job/$jobId/mrp.pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data ?? const <int>[];
      if (bytes.isEmpty) throw Exception('Empty PDF');
      final dir = await getApplicationDocumentsDirectory();
      final jobNo = data.value?['jobOrderNo']?.toString() ?? jobId;
      final safe = jobNo.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final file = File('${dir.path}/MRP_$safe.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await openExternally(file.path);
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data is Map
            ? (e.response?.data['message']?.toString() ?? 'Failed to open PDF.')
            : (e.message ?? 'Failed to open PDF.'),
        backgroundColor: ErpColors.solidError,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not open the MRP PDF: $e',
          backgroundColor: ErpColors.solidError,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      pdfLoading.value = false;
    }
  }
}
