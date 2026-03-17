import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/employee.dart';


// ══════════════════════════════════════════════════════════════
//  EMPLOYEE API SERVICE
// ══════════════════════════════════════════════════════════════

class EmployeeApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<List<EmployeeListItem>> fetchAll() async {
    final res = await _dio.get('/employee/get-employees');
    return (res.data['employees'] as List)
        .map((e) => EmployeeListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchDetail(String id) async {
    final res = await _dio.get(
      '/employee/get-employee-detail',
      queryParameters: {'id': id},
    );
    return res.data['employee'] as Map<String, dynamic>;
  }

  static Future<void> create(EmployeeCreate payload) async {
    await _dio.post('/employee/create-employee', data: payload.toJson());
  }

  /// For shift-plan operator dropdown
  static Future<List<EmployeeListItem>> fetchWeaveOperators() async {
    final res = await _dio.get('/employee/get-employee-weave');
    return (res.data['employees'] as List)
        .map((e) => EmployeeListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ══════════════════════════════════════════════════════════════
//  EMPLOYEE LIST CONTROLLER
//
//  FIX: original EmpViewController mixed http + Dio, had zero
//       try/catch, left isLoading = true forever on failure.
//       Merged into a single unified controller.
// ══════════════════════════════════════════════════════════════

class EmployeeListController extends GetxController {
  final allEmployees      = <EmployeeListItem>[].obs;
  final filteredEmployees = <EmployeeListItem>[].obs;

  final isLoading      = true.obs;
  final errorMsg       = Rxn<String>();
  final searchQuery    = ''.obs;
  final deptFilter     = 'all'.obs;

  static const List<String> kDepartments = [
    'all', 'weaving', 'warping', 'covering',
    'finishing', 'packing', 'checking', 'general', 'admin',
  ];

  @override
  void onInit() {
    super.onInit();
    ever(searchQuery, (_) => _applyFilter());
    ever(deptFilter,  (_) => _applyFilter());
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      allEmployees.value = await EmployeeApiService.fetchAll();
      _applyFilter();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to load employees';
      errorMsg.value = msg;
      _snack('Load Error', msg, isError: true);
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void _applyFilter() {
    var list = allEmployees.toList();
    if (deptFilter.value != 'all') {
      list = list
          .where((e) =>
      e.department.toLowerCase() == deptFilter.value.toLowerCase())
          .toList();
    }
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list
          .where((e) =>
      e.name.toLowerCase().contains(q) ||
          e.role.toLowerCase().contains(q))
          .toList();
    }
    filteredEmployees.value = list;
  }

  void setSearch(String q)   => searchQuery.value = q;
  void setDeptFilter(String d) => deptFilter.value = d;

  // Stat helpers
  int get totalCount => allEmployees.length;
  Map<String, int> get deptCounts {
    final map = <String, int>{};
    for (final e in allEmployees) {
      map[e.department] = (map[e.department] ?? 0) + 1;
    }
    return map;
  }
}

// ══════════════════════════════════════════════════════════════
//  EMPLOYEE DETAIL CONTROLLER
// ══════════════════════════════════════════════════════════════

class EmployeeDetailController extends GetxController {
  final String employeeId;
  EmployeeDetailController(this.employeeId);

  final employee = Rxn<EmployeeDetail>();
  final shifts   = <ShiftHistory>[].obs;

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
      final data = await EmployeeApiService.fetchDetail(employeeId);
      employee.value = EmployeeDetail.fromJson(data);
      shifts.value   = (data['result'] as List? ?? [])
          .map((e) => ShiftHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to load employee';
      errorMsg.value = msg;
      _snack('Load Error', msg, isError: true);
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Computed stats from real shift data ───────────────────
  // FIX: original _performanceCard showed hardcoded "82%", "24", etc.
  double get avgEfficiency {
    if (shifts.isEmpty) return 0;
    return shifts.fold(0.0, (s, sh) => s + sh.efficiency) / shifts.length;
  }

  double get avgOutput {
    if (shifts.isEmpty) return 0;
    return shifts.fold(0.0, (s, sh) => s + sh.outputMeters) / shifts.length;
  }

  double get avgRuntimeMinutes {
    if (shifts.isEmpty) return 0;
    return shifts.fold(0.0, (s, sh) => s + sh.runtimeMinutes) / shifts.length;
  }

  String get avgRuntimeFormatted {
    final mins = avgRuntimeMinutes.round();
    final h    = mins ~/ 60;
    final m    = mins % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ══════════════════════════════════════════════════════════════
//  ADD EMPLOYEE CONTROLLER
// ══════════════════════════════════════════════════════════════

class AddEmployeeController extends GetxController {
  final VoidCallback? onSuccess;
  AddEmployeeController({this.onSuccess});

  final isSaving = false.obs;

  Future<void> addEmployee(EmployeeCreate payload) async {
    isSaving.value = true;
    try {
      await EmployeeApiService.create(payload);
      _snack('Employee Added', '${payload.name} has been registered',
          isError: false);
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to create employee';
      _snack('Save Failed', msg, isError: true);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isSaving.value = false;
    }
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