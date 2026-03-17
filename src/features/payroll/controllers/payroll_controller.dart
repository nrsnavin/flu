// ══════════════════════════════════════════════════════════════
//  PAYROLL CONTROLLER  v4
//  File: lib/src/features/payroll/controllers/payroll_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/payroll_models.dart';


final _dio = Dio(BaseOptions(
  baseUrl:        'http://13.233.117.153:2701/api/v2',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
));

class PayrollController extends GetxController {

  // ── Active view ────────────────────────────────────────────
  final activeView = PayrollView.dashboard.obs;

  // ── Month / year ───────────────────────────────────────────
  final selectedMonth = DateTime.now().month.obs;
  final selectedYear  = DateTime.now().year.obs;

  // ── Dashboard ──────────────────────────────────────────────
  final isLoadingDash = false.obs;
  final dashError     = RxnString();
  final dashboard     = Rxn<PayrollDashboard>();

  // ── Generate ───────────────────────────────────────────────
  final isGenerating    = false.obs;
  final generateError   = RxnString();
  final generateSuccess = false.obs;
  final generateMsg     = RxnString();

  // ── Payslip ────────────────────────────────────────────────
  final isLoadingPayslip   = false.obs;
  final payslipError       = RxnString();
  final payslip            = Rxn<PayrollDoc>();
  final activePayslipEmpId = RxnString();

  // ── Employee Rates ─────────────────────────────────────────
  final isLoadingRates = false.obs;
  final ratesError     = RxnString();
  final employees      = <EmployeeRate>[].obs;
  final isSavingRate   = ''.obs;
  final rateSaveMsg    = RxnString();

  // ── Settings ───────────────────────────────────────────────
  final isLoadingSettings = false.obs;
  final isSavingSettings  = false.obs;
  final settingsError     = RxnString();
  final settingsSaveOk    = false.obs;
  Rxn<PayrollSettings> settings = Rxn<PayrollSettings>();
  late final TextEditingController tfCasualLeaves, tfSickLeaves, tfGraceMins,
      tfPenaltyPerExcess, tfNoLeaveBonus, tfPerfectBonus, tfStreakBonus;

  // ── Leave ──────────────────────────────────────────────────
  final isLoadingLeave  = false.obs;
  final leaveError      = RxnString();
  final leaveRequests   = <LeaveRequest>[].obs;
  final leaveFilter     = 'pending'.obs;
  final leaveSubmitting = false.obs;
  final leaveSubmitOk   = false.obs;
  final leaveSubmitErr  = RxnString();
  final leaveShift      = 'DAY'.obs;
  final leaveType       = 'casual'.obs;
  final leaveStartDate  = Rx<DateTime>(DateTime.now());
  final leaveEndDate    = Rx<DateTime>(DateTime.now());
  final leaveReason     = ''.obs;
  String? _leaveEmpId;

  // ── Advance ────────────────────────────────────────────────
  final isLoadingAdv  = false.obs;
  final advError      = RxnString();
  final advances      = <AdvanceRequest>[].obs;
  final advFilter     = 'pending'.obs;  // pending | approved | rejected | all
  // Advance submit form
  final advSubmitting = false.obs;
  final advSubmitOk   = false.obs;
  final advSubmitErr  = RxnString();
  final advReason     = ''.obs;
  String? _advEmpId;
  // Approve form
  final advApproving  = ''.obs;  // id being approved
  final advApprovingMonth = DateTime.now().month.obs;
  final advApprovingYear  = DateTime.now().year.obs;

  // ── Yearly Bonus ───────────────────────────────────────────
  final isLoadingYB  = false.obs;
  final isComputingYB= false.obs;
  final ybError      = RxnString();
  final yearlyBonuses= <YearlyBonus>[].obs;
  final ybYear       = DateTime.now().year.obs;

  // ── Analytics ──────────────────────────────────────────────
  final isLoadingAna  = false.obs;
  final anaError      = RxnString();
  final analytics     = <AnalyticsEmployee>[].obs;
  Rxn<AnalyticsSummary> anaSummary = Rxn<AnalyticsSummary>();
  final anaYear       = DateTime.now().year.obs;
  final anaMonth      = 0.obs;  // 0 = all months

  @override
  void onInit() {
    super.onInit();
    _initTf();
    fetchDashboard();
    fetchRates();
    fetchSettings();
    fetchLeaveRequests();
    fetchAdvances();
    fetchYearlyBonuses();
    fetchAnalytics();
  }

  @override
  void onClose() { _disposeTf(); super.onClose(); }

  void _initTf() {
    tfCasualLeaves    = TextEditingController(text: '2');
    tfSickLeaves      = TextEditingController(text: '1');
    tfGraceMins       = TextEditingController(text: '10');
    tfPenaltyPerExcess= TextEditingController(text: '200');
    tfNoLeaveBonus    = TextEditingController(text: '300');
    tfPerfectBonus    = TextEditingController(text: '500');
    tfStreakBonus     = TextEditingController(text: '100');
  }
  void _disposeTf() {
    for (final c in [tfCasualLeaves, tfSickLeaves, tfGraceMins, tfPenaltyPerExcess,
      tfNoLeaveBonus, tfPerfectBonus, tfStreakBonus]) c.dispose();
  }

  // ── Month nav ──────────────────────────────────────────────
  void prevMonth() {
    if (selectedMonth.value == 1) { selectedMonth.value = 12; selectedYear.value--; }
    else selectedMonth.value--;
    fetchDashboard();
    if (activePayslipEmpId.value != null) openPayslip(activePayslipEmpId.value!);
  }
  void nextMonth() {
    final n = DateTime.now();
    if (selectedYear.value == n.year && selectedMonth.value == n.month) return;
    if (selectedMonth.value == 12) { selectedMonth.value = 1; selectedYear.value++; }
    else selectedMonth.value++;
    fetchDashboard();
    if (activePayslipEmpId.value != null) openPayslip(activePayslipEmpId.value!);
  }
  bool get canGoNextMonth {
    final n = DateTime.now();
    return !(selectedYear.value == n.year && selectedMonth.value == n.month);
  }
  String get monthLabel => '${kMonths[selectedMonth.value]} ${selectedYear.value}';

  // ── Dashboard ──────────────────────────────────────────────
  Future<void> fetchDashboard() async {
    isLoadingDash.value = true; dashError.value = null;
    try {
      final r = await _dio.get('/payroll/dashboard',
          queryParameters: {'year': selectedYear.value, 'month': selectedMonth.value});
      dashboard.value = PayrollDashboard.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      dashError.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } catch (e) { dashError.value = e.toString(); }
    finally { isLoadingDash.value = false; }
  }

  // ── Generate ───────────────────────────────────────────────
  Future<void> generateAll() async {
    isGenerating.value = true; generateError.value = null; generateSuccess.value = false;
    generateMsg.value  = null;
    try {
      final r   = await _dio.post('/payroll/generate',
          data: {'year': selectedYear.value, 'month': selectedMonth.value});
      final cnt = (r.data['data'] as List?)?.length ?? 0;
      generateSuccess.value = true;
      generateMsg.value     = '✅ Generated for $cnt employee(s)';
      await fetchDashboard();
      Future.delayed(const Duration(seconds: 4), () {
        generateSuccess.value = false; generateMsg.value = null;
      });
    } on DioException catch (e) {
      generateError.value = e.response?.data?['message']?.toString() ?? 'Generate failed';
    } catch (e) { generateError.value = e.toString(); }
    finally { isGenerating.value = false; }
  }

  // ── Payslip ────────────────────────────────────────────────
  Future<void> openPayslip(String empId) async {
    activePayslipEmpId.value = empId; activeView.value = PayrollView.payslip;
    isLoadingPayslip.value = true; payslipError.value = null; payslip.value = null;
    try {
      final r = await _dio.get('/payroll/slip/$empId',
          queryParameters: {'year': selectedYear.value, 'month': selectedMonth.value});
      payslip.value = PayrollDoc.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      payslipError.value = e.response?.data?['message']?.toString()
          ?? 'Not generated — run Generate first';
    } catch (e) { payslipError.value = e.toString(); }
    finally { isLoadingPayslip.value = false; }
  }
  Future<void> finalizePayroll(String id) async {
    try {
      await _dio.put('/payroll/$id/finalize');
      if (activePayslipEmpId.value != null) openPayslip(activePayslipEmpId.value!);
      fetchDashboard();
    } catch (_) {}
  }
  Future<void> markAsPaid(String id, String note) async {
    try {
      await _dio.put('/payroll/$id/pay', data: {'paidBy': 'admin', 'paymentNote': note});
      if (activePayslipEmpId.value != null) openPayslip(activePayslipEmpId.value!);
      fetchDashboard();
    } catch (_) {}
  }

  // ── Employee Rates ─────────────────────────────────────────
  Future<void> fetchRates() async {
    isLoadingRates.value = true; ratesError.value = null;
    try {
      final r = await _dio.get('/payroll/employees');
      employees.value = (r.data['data'] as List? ?? [])
          .map((e) => EmployeeRate.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ratesError.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } finally { isLoadingRates.value = false; }
  }
  Future<void> saveEmployeeRate(String empId, double rate) async {
    isSavingRate.value = empId; rateSaveMsg.value = null;
    try {
      final r = await _dio.post('/payroll/employees/$empId/rate', data: {'hourlyRate': rate});
      final u = EmployeeRate.fromJson(r.data['data'] as Map<String, dynamic>);
      final i = employees.indexWhere((e) => e.id == empId);
      if (i >= 0) employees[i] = u;
      rateSaveMsg.value = '✅ Rate saved for ${u.name}';
      Future.delayed(const Duration(seconds: 3), () => rateSaveMsg.value = null);
    } on DioException catch (e) {
      rateSaveMsg.value = '❌ ${e.response?.data?['message'] ?? 'Save failed'}';
    } finally { isSavingRate.value = ''; }
  }

  // ── Settings ───────────────────────────────────────────────
  Future<void> fetchSettings() async {
    isLoadingSettings.value = true;
    try {
      final r = await _dio.get('/payroll/settings');
      final d = r.data['data'];
      settings.value = (d != null && (d as Map).isNotEmpty)
          ? PayrollSettings.fromJson(d as Map<String, dynamic>)
          : PayrollSettings.defaults();
      _fillTf(settings.value!);
    } catch (_) {
      settings.value = PayrollSettings.defaults();
      _fillTf(settings.value!);
    } finally { isLoadingSettings.value = false; }
  }
  void _fillTf(PayrollSettings s) {
    tfCasualLeaves.text     = s.casualLeavesPerMonth.toString();
    tfSickLeaves.text       = s.sickLeavesPerMonth.toString();
    tfGraceMins.text        = s.lateGracePeriodMinutes.toString();
    tfPenaltyPerExcess.text = s.penaltyPerExcessAbsent.toStringAsFixed(0);
    tfNoLeaveBonus.text     = s.noLeaveBonus.toStringAsFixed(0);
    tfPerfectBonus.text     = s.perfectAttendanceBonus.toStringAsFixed(0);
    tfStreakBonus.text       = s.streakBonusPer7Shifts.toStringAsFixed(0);
  }
  Future<void> saveSettings() async {
    isSavingSettings.value = true; settingsError.value = null; settingsSaveOk.value = false;
    try {
      int    pi(TextEditingController t) => int.tryParse(t.text.trim()) ?? 0;
      double pd(TextEditingController t) => double.tryParse(t.text.trim()) ?? 0;
      final r = await _dio.post('/payroll/settings', data: {
        'casualLeavesPerMonth': pi(tfCasualLeaves), 'sickLeavesPerMonth': pi(tfSickLeaves),
        'lateGracePeriodMinutes': pi(tfGraceMins), 'penaltyPerExcessAbsent': pd(tfPenaltyPerExcess),
        'noLeaveBonus': pd(tfNoLeaveBonus), 'perfectAttendanceBonus': pd(tfPerfectBonus),
        'streakBonusPer7Shifts': pd(tfStreakBonus),
      });
      settings.value = PayrollSettings.fromJson(r.data['data'] as Map<String, dynamic>);
      settingsSaveOk.value = true;
      Future.delayed(const Duration(seconds: 3), () => settingsSaveOk.value = false);
    } on DioException catch (e) {
      settingsError.value = e.response?.data?['message']?.toString() ?? 'Save failed';
    } finally { isSavingSettings.value = false; }
  }

  // ── Leave ──────────────────────────────────────────────────
  Future<void> fetchLeaveRequests() async {
    isLoadingLeave.value = true; leaveError.value = null;
    try {
      final params = <String, dynamic>{
        'month': selectedMonth.value, 'year': selectedYear.value,
      };
      if (leaveFilter.value != 'all') params['status'] = leaveFilter.value;
      final r = await _dio.get('/leave', queryParameters: params);
      leaveRequests.value = (r.data['data'] as List? ?? [])
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      leaveError.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } finally { isLoadingLeave.value = false; }
  }
  Future<void> approveLeave(String id) async {
    try { await _dio.put('/leave/$id/approve'); fetchLeaveRequests(); } catch (_) {}
  }
  Future<void> rejectLeave(String id, String remarks) async {
    try { await _dio.put('/leave/$id/reject', data: {'reviewNotes': remarks}); fetchLeaveRequests(); } catch (_) {}
  }
  void openLeaveFormFor(String empId) => _leaveEmpId = empId;
  Future<void> submitLeaveRequest() async {
    if (leaveReason.value.trim().isEmpty) {
      leaveSubmitErr.value = 'Please enter a reason'; return;
    }
    leaveSubmitting.value = true; leaveSubmitOk.value = false; leaveSubmitErr.value = null;
    try {
      await _dio.post('/leave/request', data: {
        if (_leaveEmpId != null) 'employeeId': _leaveEmpId,
        'startDate': _fmt(leaveStartDate.value), 'endDate': _fmt(leaveEndDate.value),
        'shift': leaveShift.value, 'leaveType': leaveType.value,
        'reason': leaveReason.value.trim(),
      });
      leaveSubmitOk.value = true; leaveReason.value = '';
      fetchLeaveRequests();
      Future.delayed(const Duration(seconds: 3), () => leaveSubmitOk.value = false);
    } on DioException catch (e) {
      leaveSubmitErr.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } finally { leaveSubmitting.value = false; }
  }

  // ── Advance ────────────────────────────────────────────────
  Future<void> fetchAdvances() async {
    isLoadingAdv.value = true; advError.value = null;
    try {
      final params = <String, dynamic>{};
      if (advFilter.value != 'all') params['status'] = advFilter.value;
      final r = await _dio.get('/payroll/advance', queryParameters: params);
      advances.value = (r.data['data'] as List? ?? [])
          .map((e) => AdvanceRequest.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      advError.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } finally { isLoadingAdv.value = false; }
  }

  void openAdvanceFormFor(String empId) => _advEmpId = empId;

  Future<void> submitAdvanceRequest(double amount) async {
    if (amount <= 0) { advSubmitErr.value = 'Enter a valid amount'; return; }
    advSubmitting.value = true; advSubmitOk.value = false; advSubmitErr.value = null;
    try {
      await _dio.post('/payroll/advance', data: {
        if (_advEmpId != null) 'employeeId': _advEmpId,
        'amount': amount, 'reason': advReason.value.trim(),
      });
      advSubmitOk.value = true; advReason.value = '';
      fetchAdvances();
      Future.delayed(const Duration(seconds: 3), () => advSubmitOk.value = false);
    } on DioException catch (e) {
      advSubmitErr.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } finally { advSubmitting.value = false; }
  }

  Future<void> approveAdvance(String id, int month, int year, String notes) async {
    advApproving.value = id;
    try {
      await _dio.put('/payroll/advance/$id/approve', data: {
        'deductMonth': month, 'deductYear': year, 'adminNotes': notes,
      });
      fetchAdvances();
    } on DioException catch (_) {}
    finally { advApproving.value = ''; }
  }

  Future<void> rejectAdvance(String id, String notes) async {
    try {
      await _dio.put('/payroll/advance/$id/reject', data: {'adminNotes': notes});
      fetchAdvances();
    } catch (_) {}
  }

  // ── Yearly Bonus ───────────────────────────────────────────
  Future<void> fetchYearlyBonuses() async {
    isLoadingYB.value = true; ybError.value = null;
    try {
      final r = await _dio.get('/payroll/yearly-bonus', queryParameters: {'year': ybYear.value});
      yearlyBonuses.value = (r.data['data'] as List? ?? [])
          .map((e) => YearlyBonus.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ybError.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } finally { isLoadingYB.value = false; }
  }

  Future<void> computeYearlyBonuses() async {
    isComputingYB.value = true; ybError.value = null;
    try {
      await _dio.post('/payroll/yearly-bonus/compute', queryParameters: {'year': ybYear.value});
      await fetchYearlyBonuses();
    } on DioException catch (e) {
      ybError.value = e.response?.data?['message']?.toString() ?? 'Compute failed';
    } finally { isComputingYB.value = false; }
  }

  Future<void> payYearlyBonus(String id, String note) async {
    try {
      await _dio.put('/payroll/yearly-bonus/$id/pay',
          data: {'paidBy': 'admin', 'paymentNote': note});
      fetchYearlyBonuses();
    } catch (_) {}
  }

  // ── Analytics ──────────────────────────────────────────────
  Future<void> fetchAnalytics() async {
    isLoadingAna.value = true; anaError.value = null;
    try {
      final params = <String, dynamic>{'year': anaYear.value};
      if (anaMonth.value > 0) params['month'] = anaMonth.value;
      final r = await _dio.get('/payroll/analytics', queryParameters: params);
      anaSummary.value = AnalyticsSummary.fromJson(r.data['summary'] as Map<String, dynamic>);
      analytics.value  = (r.data['data'] as List? ?? [])
          .map((e) => AnalyticsEmployee.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      anaError.value = e.response?.data?['message']?.toString() ?? 'Failed';
    } finally { isLoadingAna.value = false; }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}