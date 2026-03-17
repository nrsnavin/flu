import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/PackingModel.dart';


// ══════════════════════════════════════════════════════════════
//  PACKING API SERVICE
// ══════════════════════════════════════════════════════════════

class PackingApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  /// GET /packing/grouped  → list of jobs with packing summary
  static Future<List<PackingJobSummary>> fetchGrouped() async {
    final res = await _dio.get('/packing/grouped');
    final list = res.data["grouped"] as List? ?? [];
    return list
        .where((e) => e is Map && e['job'] != null)
        .map((e) => PackingJobSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /packing/by-job/:jobId  → all packings for a job (populated)
  static Future<List<PackingListItem>> fetchByJob(String jobId) async {
    final res = await _dio.get('/packing/by-job/$jobId');
    return (res.data['packings'] as List? ?? [])
        .map((e) => PackingListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /packing/detail/:id  → full detail with all populates
  static Future<PackingDetail> fetchDetail(String id) async {
    final res = await _dio.get('/packing/detail/$id');
    return PackingDetail.fromJson(res.data['packing'] as Map<String, dynamic>);
  }

  /// GET /packing/jobs-packing  → jobs in packing status (for add form)
  static Future<List<PackingJobModel>> fetchPackingJobs() async {
    final res = await _dio.get('/packing/jobs-packing');
    return (res.data['jobs'] as List? ?? [])
        .map((e) => PackingJobModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /packing/employees-by-department/:dept
  static Future<List<EmployeeOption>> fetchEmployees(String dept) async {
    final res = await _dio.get('/packing/employees-by-department/$dept');
    return (res.data['employees'] as List? ?? [])
        .map((e) => EmployeeOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /packing/create-packing
  static Future<Map<String, dynamic>> createPacking(
      Map<String, dynamic> payload) async {
    final res = await _dio.post('/packing/create-packing', data: payload);
    return res.data as Map<String, dynamic>;
  }
}

// ══════════════════════════════════════════════════════════════
//  PACKING OVERVIEW CONTROLLER
//
//  FIX: original PackagingController had no error handling,
//       no loading state, and the response format mismatch
//       (grouped returns array not {success, data: [...]}).
// ══════════════════════════════════════════════════════════════

class PackingOverviewController extends GetxController {
  final jobs       = <PackingJobSummary>[].obs;
  final isLoading  = true.obs;
  final errorMsg   = Rxn<String>();
  final searchQuery = ''.obs;

  List<PackingJobSummary> get filtered {
    if (searchQuery.value.isEmpty) return jobs.toList();
    final q = searchQuery.value.toLowerCase();
    return jobs
        .where((j) =>
    j.jobNo.toString().contains(q) ||
        (j.customerName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchGrouped();
  }

  Future<void> fetchGrouped() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      jobs.value = await PackingApiService.fetchGrouped();
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load packing jobs';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void setSearch(String q) => searchQuery.value = q;

  int get totalBoxes => jobs.fold(0, (s, j) => s + j.totalBoxes);
  double get totalMeters => jobs.fold(0.0, (s, j) => s + j.totalMeters);
}

// ══════════════════════════════════════════════════════════════
//  PACKING LIST BY JOB CONTROLLER
//
//  FIX: original PackingListController.fetchPackingByJob called
//       GET /packing/job/:jobNo with a MongoDB _id — the route
//       did Packing.find({ job: params.jobNo }) which works for _id
//       but returns raw documents without populate → elastic name
//       was always blank. Also: called in build() → refetched
//       on every rebuild.
// ══════════════════════════════════════════════════════════════

class PackingListByJobController extends GetxController {
  final String jobId;
  PackingListByJobController(this.jobId);

  final packings   = <PackingListItem>[].obs;
  final isLoading  = true.obs;
  final errorMsg   = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      packings.value = await PackingApiService.fetchByJob(jobId);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load packings';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  double get totalMeters => packings.fold(0.0, (s, p) => s + p.meters);
  int get totalJoints    => packings.fold(0, (s, p) => s + p.joints);
}

// ══════════════════════════════════════════════════════════════
//  PACKING DETAIL CONTROLLER
//
//  FIX: original used GET /packing/$id (the /:id route) which
//       doesn't populate elastic → elasticName always empty.
//  FIX: PackingModel.fromJson(res.data['packing']) but /:id route
//       returns the object directly without { packing: ... } wrapper.
//  FIX: No error handling.
//  FIX: printPdf() and openPdf() both called openPdf() — no actual
//       print distinction.
//  FIX: fetchDetail() was called from build() → re-fetched every
//       rebuild.
// ══════════════════════════════════════════════════════════════

class PackingDetailController extends GetxController {
  final String packingId;
  PackingDetailController(this.packingId);

  final packing   = Rxn<PackingDetail>();
  final isLoading = true.obs;
  final errorMsg  = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      packing.value = await PackingApiService.fetchDetail(packingId);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load packing detail';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ADD PACKING CONTROLLER
//
//  FIX: no try/catch in fetchJobs, fetchEmployees, submit.
//  FIX: int.parse(meterController.text) crashes on empty input.
//  FIX: no loading state on submit.
//  FIX: no validation before submit.
// ══════════════════════════════════════════════════════════════

class AddPackingController extends GetxController {
  final VoidCallback? onSuccess;
  AddPackingController({this.onSuccess});

  final jobs              = <PackingJobModel>[].obs;
  final checkingEmployees = <EmployeeOption>[].obs;
  final packingEmployees  = <EmployeeOption>[].obs;

  final selectedJob       = Rxn<PackingJobModel>();
  final selectedElastic   = Rxn<String>();
  final selectedCheckedBy = Rxn<String>();
  final selectedPackedBy  = Rxn<String>();

  final isLoading  = true.obs;
  final isSaving   = false.obs;
  final errorMsg   = Rxn<String>();

  final meterCtrl   = TextEditingController();
  final jointsCtrl  = TextEditingController();
  final tareCtrl    = TextEditingController();
  final netCtrl     = TextEditingController();
  final grossCtrl   = TextEditingController();
  final stretchCtrl = TextEditingController();
  final sizeCtrl    = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
  }

  @override
  void onClose() {
    meterCtrl.dispose();
    jointsCtrl.dispose();
    tareCtrl.dispose();
    netCtrl.dispose();
    grossCtrl.dispose();
    stretchCtrl.dispose();
    sizeCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadInitialData() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final results = await Future.wait([
        PackingApiService.fetchPackingJobs(),
        PackingApiService.fetchEmployees('checking'),
        PackingApiService.fetchEmployees('packing'),
      ]);
      jobs.value              = results[0] as List<PackingJobModel>;
      checkingEmployees.value = results[1] as List<EmployeeOption>;
      packingEmployees.value  = results[2] as List<EmployeeOption>;
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load form data';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submit() async {
    if (!_validate()) return false;
    isSaving.value = true;
    try {
      await PackingApiService.createPacking({
        'job':         selectedJob.value!.id,
        'elastic':     selectedElastic.value,
        'meter':       double.parse(meterCtrl.text.trim()),
        'joints':      int.parse(jointsCtrl.text.trim()),
        'tareWeight':  double.parse(tareCtrl.text.trim()),
        'netWeight':   double.parse(netCtrl.text.trim()),
        'grossWeight': double.parse(grossCtrl.text.trim()),
        'stretch':     stretchCtrl.text.trim(),
        'size':        sizeCtrl.text.trim(),
        'checkedBy':   selectedCheckedBy.value,
        'packedBy':    selectedPackedBy.value,
      });
      _snack('Packing Added', 'Packing record saved successfully',
          isError: false);
      onSuccess?.call();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to save packing';
      _snack('Save Failed', msg, isError: true);
      return false;
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  bool _validate() {
    if (selectedJob.value == null) {
      _snack('Validation', 'Please select a job', isError: true);
      return false;
    }
    if (selectedElastic.value == null) {
      _snack('Validation', 'Please select an elastic', isError: true);
      return false;
    }
    if (selectedCheckedBy.value == null) {
      _snack('Validation', 'Please select Checked By employee', isError: true);
      return false;
    }
    if (selectedPackedBy.value == null) {
      _snack('Validation', 'Please select Packed By employee', isError: true);
      return false;
    }
    return true;
  }
}

// ── Shared snackbar helper ────────────────────────────────────
void _snack(String title, String message, {required bool isError}) {
  Get.snackbar(
    title, message,
    backgroundColor: isError
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A),
    colorText:       Colors.white,
    snackPosition:   SnackPosition.BOTTOM,
    duration:        const Duration(seconds: 4),
    icon: Icon(
      isError ? Icons.error_outline : Icons.check_circle_outline,
      color: Colors.white,
    ),
  );
}