import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/checkingJobModel.dart';


// ══════════════════════════════════════════════════════════════
//  WASTAGE API SERVICE
// ══════════════════════════════════════════════════════════════

class WastageApi {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2/wastage',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  static final Dio _jobDio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2/job',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  static Future<List<WastageJobSummary>> fetchJobsWithWastage({
    String? status,
  }) async {
    final res = await _dio.get('/jobs-wastage-list', queryParameters: {
      if (status != null) 'status': status,
    });
    return (res.data['jobs'] as List? ?? [])
        .map((e) => WastageJobSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<WastageRecord>> fetchByJob(String jobId) async {
    final res =
    await _dio.get('/get-by-job', queryParameters: {'jobId': jobId});
    return (res.data['wastages'] as List? ?? [])
        .map((e) => WastageRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<WastageRecord> fetchDetail(String id) async {
    final res =
    await _dio.get('/get-detail', queryParameters: {'id': id});
    return WastageRecord.fromJson(
        res.data['wastage'] as Map<String, dynamic>);
  }

  // FIX: was calling /create-wastage on wrong router (wastage.js) with wrong
  //      field names. Now calls /wastage/add-wastage with correct field names.
  static Future<WastageRecord> addWastage({
    required String jobId,
    required String elasticId,
    required String employeeId,
    required double quantity,
    required double penalty,
    required String reason,
  }) async {
    final res = await _dio.post('/add-wastage', data: {
      'job':      jobId,
      'elastic':  elasticId,
      'employee': employeeId,
      'quantity': quantity,
      'penalty':  penalty,
      'reason':   reason,
    });
    return WastageRecord.fromJson(
        res.data['wastage'] as Map<String, dynamic>);
  }

  // FIX: was /job/jobs-checking (only "checking" status).
  //      Now /wastage/jobs-for-wastage returns weaving/finishing/checking.
  static Future<List<WastageJobOption>> fetchJobsForWastage() async {
    final res = await _dio.get('/jobs-for-wastage');
    return (res.data['jobs'] as List? ?? [])
        .map((e) => WastageJobOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<EmployeeOption>> fetchOperators(String jobId) async {
    final res = await _jobDio.get(
        '/job-operators', queryParameters: {'id': jobId});
    return (res.data['operators'] as List? ?? [])
        .map((e) => EmployeeOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<WastageAnalytics> fetchAnalytics({int days = 30}) async {
    final res = await _dio.get('/analytics', queryParameters: {'days': days});
    return WastageAnalytics.fromJson(
        res.data['analytics'] as Map<String, dynamic>);
  }
}

// ══════════════════════════════════════════════════════════════
//  WASTAGE LIST CONTROLLER  (jobs grouped)
//
//  BUGS FIXED:
//  1. No filter/search support.
//  2. No error state.
// ══════════════════════════════════════════════════════════════

class WastageListController extends GetxController {
  final jobs       = <WastageJobSummary>[].obs;
  final isLoading  = false.obs;
  final errorMsg   = Rxn<String>();
  final statusFilter = Rxn<String>();

  // Stats
  double get totalWastage =>
      jobs.fold(0.0, (s, j) => s + j.totalWastage);
  int get totalEntries =>
      jobs.fold(0, (s, j) => s + j.wastageCount);

  @override
  void onInit() {
    super.onInit();
    fetch();
    ever(statusFilter, (_) => fetch());
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      jobs.value = await WastageApi.fetchJobsWithWastage(
          status: statusFilter.value);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ??
              'Failed to load wastage data';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  WASTAGE JOB CONTROLLER  (records for one job)
// ══════════════════════════════════════════════════════════════

class WastageJobController extends GetxController {
  final String jobId;
  final int jobNo;
  WastageJobController(this.jobId, this.jobNo);

  final wastages  = <WastageRecord>[].obs;
  final isLoading = true.obs;
  final errorMsg  = Rxn<String>();

  double get totalQty =>
      wastages.fold(0.0, (s, w) => s + w.quantity);
  double get totalPenalty =>
      wastages.fold(0.0, (s, w) => s + w.penalty);

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      wastages.value = await WastageApi.fetchByJob(jobId);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ADD WASTAGE CONTROLLER
//
//  BUGS FIXED:
//  1. Fetched only "checking" jobs — now fetches weaving/finishing/checking.
//  2. submitWastage() called wrong endpoint with wrong field names.
//  3. int.parse(quantityController.text) crashed on empty field.
//  4. double.parse(penaltyController.text) crashed on empty field.
//  5. No try/catch on ANY API call — unhandled crashes.
//  6. No loading state on submit.
//  7. No error feedback on failed API calls.
// ══════════════════════════════════════════════════════════════

class AddWastageController extends GetxController {
  final VoidCallback? onSuccess;
  AddWastageController({this.onSuccess});

  final jobs          = <WastageJobOption>[].obs;
  final operators     = <EmployeeOption>[].obs;
  final isLoadingJobs = true.obs;
  final isLoadingOps  = false.obs;
  final isSaving      = false.obs;
  final errorMsg      = Rxn<String>();

  final selectedJob      = Rxn<WastageJobOption>();
  final selectedElastic  = Rxn<WastageElasticOption>();
  final selectedEmployee = Rxn<EmployeeOption>();

  final quantityCtrl = TextEditingController();
  final penaltyCtrl  = TextEditingController();
  final reasonCtrl   = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _fetchJobs();
  }

  @override
  void onClose() {
    quantityCtrl.dispose();
    penaltyCtrl.dispose();
    reasonCtrl.dispose();
    super.onClose();
  }

  void reload() => _fetchJobs();

  Future<void> _fetchJobs() async {
    isLoadingJobs.value = true;
    try {
      // FIX: was /jobs-checking (only checking). Now weaving/finishing/checking
      jobs.value = await WastageApi.fetchJobsForWastage();
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load jobs';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoadingJobs.value = false;
    }
  }

  Future<void> onJobSelected(WastageJobOption job) async {
    selectedJob.value      = job;
    selectedElastic.value  = null;
    selectedEmployee.value = null;
    operators.clear();

    isLoadingOps.value = true;
    try {
      operators.value = await WastageApi.fetchOperators(job.id);
    } catch (_) {
      // non-critical — operator list stays empty
    } finally {
      isLoadingOps.value = false;
    }
  }

  Future<bool> submit() async {
    final job  = selectedJob.value;
    final el   = selectedElastic.value;
    final emp  = selectedEmployee.value;
    final qStr = quantityCtrl.text.trim();
    final pStr = penaltyCtrl.text.trim();
    final rsn  = reasonCtrl.text.trim();

    if (job == null)  { _snack('Select a job',      isError: true); return false; }
    if (el == null)   { _snack('Select an elastic', isError: true); return false; }
    if (emp == null)  { _snack('Select an operator',isError: true); return false; }
    if (qStr.isEmpty) { _snack('Enter quantity',    isError: true); return false; }
    if (rsn.isEmpty)  { _snack('Enter a reason',    isError: true); return false; }

    // FIX: was int.parse() — crashes on decimal / empty input
    final qty = double.tryParse(qStr);
    if (qty == null || qty <= 0) {
      _snack('Invalid quantity', isError: true);
      return false;
    }
    final penalty = double.tryParse(pStr) ?? 0.0;

    isSaving.value = true;
    try {
      // FIX: was calling /create-wastage with {job, elastic, employee}
      //      field names while job.js /create-wastage expected {jobId, elasticId, employeeId}.
      //      Now calls /wastage/add-wastage with correct {job, elastic, employee}.
      await WastageApi.addWastage(
        jobId:      job.id,
        elasticId:  el.id,
        employeeId: emp.id,
        quantity:   qty,
        penalty:    penalty,
        reason:     rsn,
      );
      _snack('Wastage recorded successfully', isError: false);
      onSuccess?.call();
      return true;
    } on DioException catch (e) {
      // FIX: was no try/catch at all
      _snack(
          e.response?.data?['message'] as String? ?? 'Failed to save',
          isError: true);
      return false;
    } catch (e) {
      _snack(e.toString(), isError: true);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void _snack(String msg, {required bool isError}) {
    Get.snackbar(
      isError ? 'Error' : 'Success',
      msg,
      backgroundColor:
      isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      colorText:     Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration:      const Duration(seconds: 4),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  WASTAGE ANALYTICS CONTROLLER
// ══════════════════════════════════════════════════════════════

class WastageAnalyticsController extends GetxController {
  final analytics = Rxn<WastageAnalytics>();
  final isLoading = true.obs;
  final errorMsg  = Rxn<String>();
  final days      = 30.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
    ever(days, (_) => fetch());
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      analytics.value = await WastageApi.fetchAnalytics(days: days.value);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load analytics';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}