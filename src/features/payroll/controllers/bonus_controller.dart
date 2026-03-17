// lib/src/features/payroll/controllers/bonus_controller.dart
//
// GetX controller for the Bonus tab.
// Manages: config CRUD, bonus trigger, record listing, mark-paid, reset.

import 'package:dio/dio.dart';
import 'package:get/get.dart';

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────

class BonusConfig {
  final String id;
  final int year;
  final String bonusLabel;
  final DateTime? bonusDate;
  final int yearlyWorkingDays;
  final String status; // 'pending' | 'triggered' | 'completed'
  final DateTime? triggeredAt;

  BonusConfig({
    required this.id,
    required this.year,
    required this.bonusLabel,
    this.bonusDate,
    required this.yearlyWorkingDays,
    required this.status,
    this.triggeredAt,
  });

  factory BonusConfig.fromJson(Map<String, dynamic> j) => BonusConfig(
    id:                j['_id'] as String? ?? '',
    year:              (j['year'] as num?)?.toInt() ?? DateTime.now().year,
    bonusLabel:        j['bonusLabel'] as String? ?? '',
    bonusDate:         j['bonusDate'] != null ? DateTime.parse(j['bonusDate'] as String) : null,
    yearlyWorkingDays: (j['yearlyWorkingDays'] as num?)?.toInt() ?? 300,
    status:            j['status'] as String? ?? 'pending',
    triggeredAt:       j['triggeredAt'] != null ? DateTime.parse(j['triggeredAt'] as String) : null,
  );
}

class BonusSummary {
  final int totalRecords;
  final int paidRecords;
  final int pendingRecords;
  final double totalPayout;

  BonusSummary({
    required this.totalRecords,
    required this.paidRecords,
    required this.pendingRecords,
    required this.totalPayout,
  });

  factory BonusSummary.fromJson(Map<String, dynamic> j) => BonusSummary(
    totalRecords:   (j['totalRecords']   as num?)?.toInt() ?? 0,
    paidRecords:    (j['paidRecords']    as num?)?.toInt() ?? 0,
    pendingRecords: (j['pendingRecords'] as num?)?.toInt() ?? 0,
    totalPayout:    (j['totalPayout']    as num?)?.toDouble() ?? 0,
  );
}

class BonusRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final int year;
  final double hourlyRate;
  final double hoursWorked;
  final double annualEarnings;
  final double bonusPercent;
  final double rawBonusAmount;
  final int attendanceDays;
  final int totalWorkingDays;
  final double attendanceRate;
  final String attendanceTier; // S | A | B | C
  final double multiplier;
  final double bonusAmount;
  final String status; // 'pending' | 'paid'
  final DateTime? paidAt;

  BonusRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.year,
    required this.hourlyRate,
    required this.hoursWorked,
    required this.annualEarnings,
    required this.bonusPercent,
    required this.rawBonusAmount,
    required this.attendanceDays,
    required this.totalWorkingDays,
    required this.attendanceRate,
    required this.attendanceTier,
    required this.multiplier,
    required this.bonusAmount,
    required this.status,
    this.paidAt,
  });

  bool get isPaid => status == 'paid';

  factory BonusRecord.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>? ?? {};
    return BonusRecord(
      id:              j['_id']             as String? ?? '',
      employeeId:      emp['_id']           as String? ?? '',
      employeeName:    emp['name']          as String? ?? '—',
      department:      emp['department']    as String? ?? '—',
      year:            (j['year']           as num?)?.toInt() ?? DateTime.now().year,
      hourlyRate:      (j['hourlyRate']     as num?)?.toDouble() ?? 0,
      hoursWorked:     (j['hoursWorked']    as num?)?.toDouble() ?? 0,
      annualEarnings:  (j['annualEarnings'] as num?)?.toDouble() ?? 0,
      bonusPercent:    (j['bonusPercent']   as num?)?.toDouble() ?? 10,
      rawBonusAmount:  (j['rawBonusAmount'] as num?)?.toDouble() ?? 0,
      attendanceDays:  (j['attendanceDays'] as num?)?.toInt() ?? 0,
      totalWorkingDays:(j['totalWorkingDays'] as num?)?.toInt() ?? 300,
      attendanceRate:  (j['attendanceRate'] as num?)?.toDouble() ?? 0,
      attendanceTier:  j['attendanceTier']  as String? ?? 'C',
      multiplier:      (j['multiplier']     as num?)?.toDouble() ?? 0.25,
      bonusAmount:     (j['bonusAmount']    as num?)?.toDouble() ?? 0,
      status:          j['status']          as String? ?? 'pending',
      paidAt:          j['paidAt'] != null ? DateTime.parse(j['paidAt'] as String) : null,
    );
  }
}

class RecordsSummary {
  final int total;
  final int paid;
  final int pending;
  final double totalPayout;
  final double paidPayout;
  final double pendingPayout;

  RecordsSummary({
    required this.total,
    required this.paid,
    required this.pending,
    required this.totalPayout,
    required this.paidPayout,
    required this.pendingPayout,
  });

  factory RecordsSummary.fromJson(Map<String, dynamic> j) => RecordsSummary(
    total:          (j['total']          as num?)?.toInt() ?? 0,
    paid:           (j['paid']           as num?)?.toInt() ?? 0,
    pending:        (j['pending']        as num?)?.toInt() ?? 0,
    totalPayout:    (j['totalPayout']    as num?)?.toDouble() ?? 0,
    paidPayout:     (j['paidPayout']     as num?)?.toDouble() ?? 0,
    pendingPayout:  (j['pendingPayout']  as num?)?.toDouble() ?? 0,
  );
}

// ─────────────────────────────────────────────────────────────
//  EMPLOYEE BONUS % MODEL (for rates-style listing)
// ─────────────────────────────────────────────────────────────

class EmployeeBonusRate {
  final String id;
  final String name;
  final String department;
  final double bonusPercent;

  EmployeeBonusRate({
    required this.id,
    required this.name,
    required this.department,
    required this.bonusPercent,
  });

  factory EmployeeBonusRate.fromJson(Map<String, dynamic> j) => EmployeeBonusRate(
    id:           j['_id']          as String? ?? '',
    name:         j['name']         as String? ?? '—',
    department:   j['department']   as String? ?? '—',
    bonusPercent: (j['bonusPercent'] as num?)?.toDouble() ?? 10,
  );
}

// ─────────────────────────────────────────────────────────────
//  API CLIENT
// ─────────────────────────────────────────────────────────────

class _BonusApi {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://13.233.117.153:2701/api/v2',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static Future<Map<String, dynamic>> getConfig(int year) async {
    final r = await _dio.get('/bonus/config', queryParameters: {'year': year});
    return r.data as Map<String, dynamic>;
  }

  static Future<void> updateConfig({
    required int year,
    String? bonusLabel,
    DateTime? bonusDate,
    int? yearlyWorkingDays,
  }) async {
    await _dio.put('/bonus/config', data: {
      'year': year,
      if (bonusLabel        != null) 'bonusLabel':        bonusLabel,
      if (bonusDate         != null) 'bonusDate':         bonusDate.toIso8601String(),
      if (yearlyWorkingDays != null) 'yearlyWorkingDays': yearlyWorkingDays,
    });
  }

  static Future<Map<String, dynamic>> triggerBonus(int year) async {
    final r = await _dio.post('/bonus/trigger', data: {'year': year});
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRecords(int year, String statusFilter) async {
    final r = await _dio.get('/bonus/records', queryParameters: {
      'year': year,
      'status': statusFilter,
    });
    return r.data as Map<String, dynamic>;
  }

  static Future<void> markPaid(String recordId) async {
    await _dio.put('/bonus/records/$recordId/pay');
  }

  static Future<void> reset(int year) async {
    await _dio.delete('/bonus/year/$year/reset');
  }

  static Future<List<EmployeeBonusRate>> getEmployeeRates() async {
    final r = await _dio.get('/employee/get-employees');
    final list = r.data['employees'] as List? ?? [];
    return list.map((e) => EmployeeBonusRate.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> updateEmployeePercent(String empId, double pct) async {
    await _dio.put('/bonus/employee/$empId/percent', data: {'bonusPercent': pct});
  }
}

// ─────────────────────────────────────────────────────────────
//  CONTROLLER
// ─────────────────────────────────────────────────────────────

class BonusController extends GetxController {
  // ── State ────────────────────────────────────────────────
  final selectedYear = DateTime.now().year.obs;

  // Config
  final config       = Rxn<BonusConfig>();
  final summary      = Rxn<BonusSummary>();
  final isLoadingCfg = false.obs;
  final cfgError     = Rxn<String>();

  // Config edit
  final tfBonusLabel   = ''.obs;
  final selectedDate   = Rxn<DateTime>();
  final tfWorkingDays  = '300'.obs;
  final isSavingCfg    = false.obs;
  final cfgSaveOk      = false.obs;
  final cfgSaveErr     = Rxn<String>();

  // Records
  final records         = <BonusRecord>[].obs;
  final recordsSummary  = Rxn<RecordsSummary>();
  final isLoadingRecs   = false.obs;
  final recsError       = Rxn<String>();
  final statusFilter    = 'all'.obs;

  // Trigger
  final isTriggering    = false.obs;
  final triggerOk       = false.obs;
  final triggerErr      = Rxn<String>();

  // Pay
  final payingId        = Rxn<String>();
  final payErr          = Rxn<String>();

  // Reset
  final isResetting     = false.obs;
  final resetOk         = false.obs;
  final resetErr        = Rxn<String>();

  // Per-employee bonus %
  final empRates        = <EmployeeBonusRate>[].obs;
  final isLoadingEmpRates = false.obs;
  final savingEmpId     = Rxn<String>();

  // ── Lifecycle ────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchConfig();
    fetchRecords();
  }

  // ── Config ───────────────────────────────────────────────
  Future<void> fetchConfig() async {
    isLoadingCfg.value = true;
    cfgError.value = null;
    try {
      final data = await _BonusApi.getConfig(selectedYear.value);
      final cfg = BonusConfig.fromJson(data['config'] as Map<String, dynamic>);
      config.value = cfg;
      summary.value = BonusSummary.fromJson(data['stats'] as Map<String, dynamic>);
      // Prefill edit fields
      tfBonusLabel.value  = cfg.bonusLabel;
      selectedDate.value  = cfg.bonusDate;
      tfWorkingDays.value = cfg.yearlyWorkingDays.toString();
    } catch (e) {
      cfgError.value = _msg(e);
    } finally {
      isLoadingCfg.value = false;
    }
  }

  Future<void> saveConfig() async {
    isSavingCfg.value = true;
    cfgSaveOk.value   = false;
    cfgSaveErr.value  = null;
    try {
      final wd = int.tryParse(tfWorkingDays.value);
      await _BonusApi.updateConfig(
        year:              selectedYear.value,
        bonusLabel:        tfBonusLabel.value.trim(),
        bonusDate:         selectedDate.value,
        yearlyWorkingDays: wd,
      );
      await fetchConfig();
      cfgSaveOk.value = true;
    } catch (e) {
      cfgSaveErr.value = _msg(e);
    } finally {
      isSavingCfg.value = false;
    }
  }

  // ── Trigger ──────────────────────────────────────────────
  Future<void> triggerBonus() async {
    isTriggering.value = true;
    triggerOk.value    = false;
    triggerErr.value   = null;
    try {
      await _BonusApi.triggerBonus(selectedYear.value);
      await fetchConfig();
      await fetchRecords();
      triggerOk.value = true;
    } catch (e) {
      triggerErr.value = _msg(e);
    } finally {
      isTriggering.value = false;
    }
  }

  // ── Records ──────────────────────────────────────────────
  Future<void> fetchRecords() async {
    isLoadingRecs.value = true;
    recsError.value = null;
    try {
      final data = await _BonusApi.getRecords(selectedYear.value, statusFilter.value);
      records.value = (data['records'] as List? ?? [])
          .map((e) => BonusRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      if (data['summary'] != null) {
        recordsSummary.value = RecordsSummary.fromJson(data['summary'] as Map<String, dynamic>);
      }
    } catch (e) {
      recsError.value = _msg(e);
    } finally {
      isLoadingRecs.value = false;
    }
  }

  Future<void> markPaid(String recordId) async {
    payErr.value  = null;
    payingId.value = recordId;
    try {
      await _BonusApi.markPaid(recordId);
      await fetchConfig();
      await fetchRecords();
    } catch (e) {
      payErr.value = _msg(e);
    } finally {
      payingId.value = null;
    }
  }

  // ── Reset ────────────────────────────────────────────────
  Future<void> resetBonus() async {
    isResetting.value = true;
    resetOk.value     = false;
    resetErr.value    = null;
    try {
      await _BonusApi.reset(selectedYear.value);
      await fetchConfig();
      await fetchRecords();
      resetOk.value = true;
    } catch (e) {
      resetErr.value = _msg(e);
    } finally {
      isResetting.value = false;
    }
  }

  // ── Per-employee bonus % ─────────────────────────────────
  Future<void> fetchEmpRates() async {
    isLoadingEmpRates.value = true;
    try {
      empRates.value = await _BonusApi.getEmployeeRates();
    } catch (_) {
    } finally {
      isLoadingEmpRates.value = false;
    }
  }

  Future<void> saveEmpPercent(String empId, double pct) async {
    savingEmpId.value = empId;
    try {
      await _BonusApi.updateEmployeePercent(empId, pct);
      await fetchEmpRates();
    } catch (_) {
    } finally {
      savingEmpId.value = null;
    }
  }

  // ── Year change ──────────────────────────────────────────
  void changeYear(int year) {
    selectedYear.value = year;
    fetchConfig();
    fetchRecords();
  }

  // ── Helpers ──────────────────────────────────────────────
  String _msg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Network error';
      return e.message ?? 'Network error';
    }
    return e.toString();
  }
}