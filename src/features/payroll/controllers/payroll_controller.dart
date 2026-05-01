// ══════════════════════════════════════════════════════════════
//  PAYROLL CONTROLLER  v6
//  File: lib/src/features/payroll/controllers/payroll_controller.dart
//
//  All fixes applied to match payroll_page.dart call sites:
//   • markAsPaid(id, note)
//   • rejectLeave(id, notes)
//   • rejectAdvance(id, notes)
//   • approveAdvance(id, month, year, notes)  — positional, not named
//   • payYearlyBonus(id, note)
//   • submitLeaveRequest()     — no args, uses stored leaveEmpId
//   • submitAdvanceRequest(amount) — 1 arg, uses stored advEmpId
//   • isSavingRate → RxnString (stores employee ID being saved)
//   • anaMonth → RxInt (0 = All Year, 1-12 = month)
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/payroll_models.dart';

class PayrollController extends GetxController {
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://13.233.117.153:2701/api/v2',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // ════════════════════════════════════════════════════════════
  //  1. NAVIGATION & MONTH PICKER
  // ════════════════════════════════════════════════════════════
  final activeView    = PayrollView.dashboard.obs;
  final selectedYear  = DateTime.now().year.obs;
  final selectedMonth = DateTime.now().month.obs;

  String get monthLabel => kMonths[selectedMonth.value] + ' ${selectedYear.value}';

  bool get canGoNextMonth {
    final now = DateTime.now();
    return selectedYear.value < now.year ||
        (selectedYear.value == now.year && selectedMonth.value < now.month);
  }

  void prevMonth() {
    if (selectedMonth.value == 1) { selectedMonth.value = 12; selectedYear.value--; }
    else { selectedMonth.value--; }
    _onMonthChanged();
  }

  void nextMonth() {
    if (!canGoNextMonth) return;
    if (selectedMonth.value == 12) { selectedMonth.value = 1; selectedYear.value++; }
    else { selectedMonth.value++; }
    _onMonthChanged();
  }

  void _onMonthChanged() {
    fetchDashboard();
    if (activeView.value == PayrollView.payslip && selectedEmployee.value != null) {
      openPayslip(selectedEmployee.value!);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  2. DASHBOARD
  // ════════════════════════════════════════════════════════════
  final isLoadingDash = false.obs;
  final dashboard     = Rxn<PayrollDashboard>();
  final dashError     = Rxn<String>();

  Future<void> fetchDashboard() async {
    try {
      isLoadingDash.value = true; dashError.value = null;
      final res = await _dio.get('/payroll/dashboard', queryParameters: {
        'year': selectedYear.value, 'month': selectedMonth.value,
      });
      dashboard.value = PayrollDashboard.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      dashError.value = e.response?.data?['message'] as String? ?? 'Failed to load dashboard';
    } finally { isLoadingDash.value = false; }
  }

  final isGenerating  = false.obs;
  final generateMsg   = Rxn<String>();
  final generateError = Rxn<String>();

  Future<void> generateAll() async {
    try {
      isGenerating.value = true; generateMsg.value = null; generateError.value = null;
      final res = await _dio.post('/payroll/generate', data: {
        'year': selectedYear.value, 'month': selectedMonth.value,
      });
      generateMsg.value = res.data['message'] as String?;
      await fetchDashboard();
    } on DioException catch (e) {
      generateError.value = e.response?.data?['message'] as String? ?? 'Generate failed';
    } finally { isGenerating.value = false; }
  }

  Future<void> finalizePayroll(String id) async {
    try {
      await _dio.put('/payroll/$id/finalize');
      await fetchDashboard();
      if (payslip.value?.id == id && selectedEmployee.value != null) {
        await openPayslip(selectedEmployee.value!);
      }
    } on DioException catch (_) {}
  }

  // FIX #1 — view calls markAsPaid(id, note) with 2 args
  Future<void> markAsPaid(String id, [String note = '']) async {
    try {
      await _dio.put('/payroll/$id/pay',
          data: {'paidBy': 'admin', 'paymentNote': note});
      await fetchDashboard();
      if (payslip.value?.id == id && selectedEmployee.value != null) {
        await openPayslip(selectedEmployee.value!);
      }
    } on DioException catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  //  3. PAYSLIP
  // ════════════════════════════════════════════════════════════
  final isLoadingPayslip = false.obs;
  final payslip          = Rxn<PayrollDoc>();
  final payslipError     = Rxn<String>();
  final selectedEmployee = RxnString();

  Future<void> openPayslip(String employeeId) async {
    try {
      selectedEmployee.value = employeeId;
      isLoadingPayslip.value = true; payslipError.value = null;
      activeView.value = PayrollView.payslip;
      final res = await _dio.get('/payroll/slip/$employeeId', queryParameters: {
        'year': selectedYear.value, 'month': selectedMonth.value,
      });
      payslip.value = PayrollDoc.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      payslipError.value = e.response?.data?['message'] as String? ?? 'Failed to load payslip';
    } finally { isLoadingPayslip.value = false; }
  }

  Future<DailyAttendance?> fetchDailyAttendance(
      String employeeId, int year, int month) async {
    if (employeeId.isEmpty) return null;
    try {
      final res = await _dio.get('/payroll/attendance', queryParameters: {
        'employeeId': employeeId, 'year': year, 'month': month,
      });
      return DailyAttendance.fromJson(res.data as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  // ════════════════════════════════════════════════════════════
  //  4. RATES
  // ════════════════════════════════════════════════════════════
  final isLoadingRates = false.obs;
  // FIX #8 — was RxBool; view does  v == widget.emp.id  so needs RxnString
  //   null  = not saving
  //   "id"  = that employee's row shows spinner
  final isSavingRate   = RxnString();
  final employees      = <EmployeeRate>[].obs;
  final ratesError     = Rxn<String>();
  final rateSaveMsg    = Rxn<String>();

  Future<void> fetchRates() async {
    try {
      isLoadingRates.value = true; ratesError.value = null;
      final res = await _dio.get('/payroll/employees');
      employees.value = (res.data['data'] as List)
          .map((e) => EmployeeRate.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ratesError.value = e.response?.data?['message'] as String? ?? 'Failed to load employees';
    } finally { isLoadingRates.value = false; }
  }

  Future<void> saveEmployeeRate(String id, double rate) async {
    try {
      isSavingRate.value = id;   // triggers ever() in _RateRow — now matches emp.id
      rateSaveMsg.value  = null;
      await _dio.post('/payroll/employees/$id/rate', data: {'hourlyRate': rate});
      rateSaveMsg.value = '✅ Rate saved';
      await fetchRates();
    } on DioException catch (_) {
      rateSaveMsg.value = 'Save failed';
    } finally { isSavingRate.value = null; }
  }

  // ════════════════════════════════════════════════════════════
  //  5. SETTINGS
  // ════════════════════════════════════════════════════════════
  final isLoadingSettings = false.obs;
  final isSavingSettings  = false.obs;
  final settingsSaveOk    = false.obs;
  final settingsError     = Rxn<String>();

  final tfCasualLeaves     = TextEditingController();
  final tfSickLeaves       = TextEditingController();
  final tfGraceMins        = TextEditingController();
  final tfPenaltyPerExcess = TextEditingController();
  final tfNoLeaveBonus     = TextEditingController();
  final tfPerfectBonus     = TextEditingController();
  final tfStreakBonus       = TextEditingController();
  final tfOtGraceMins      = TextEditingController();
  final tfOtMultiplier     = TextEditingController();

  Future<void> fetchSettings() async {
    try {
      isLoadingSettings.value = true; settingsError.value = null;
      final res  = await _dio.get('/payroll/settings');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final s    = PayrollSettings.fromJson(data);
      tfCasualLeaves.text     = '${s.casualLeavesPerMonth}';
      tfSickLeaves.text       = '${s.sickLeavesPerMonth}';
      tfGraceMins.text        = '${s.lateGracePeriodMinutes}';
      tfPenaltyPerExcess.text = s.penaltyPerExcessAbsent.toStringAsFixed(0);
      tfNoLeaveBonus.text     = s.noLeaveBonus.toStringAsFixed(0);
      tfPerfectBonus.text     = s.perfectAttendanceBonus.toStringAsFixed(0);
      tfStreakBonus.text       = s.streakBonusPer7Shifts.toStringAsFixed(0);
      tfOtGraceMins.text  = '${data['overtimeGraceMinutes'] ?? 60}';
      tfOtMultiplier.text = '${data['overtimeMultiplier']   ?? 1.5}';
    } on DioException catch (e) {
      settingsError.value = e.response?.data?['message'] as String? ?? 'Failed to load settings';
    } finally { isLoadingSettings.value = false; }
  }

  Future<void> saveSettings() async {
    try {
      isSavingSettings.value = true; settingsSaveOk.value = false; settingsError.value = null;
      await _dio.post('/payroll/settings', data: {
        'casualLeavesPerMonth':   int.tryParse(tfCasualLeaves.text)        ?? 2,
        'sickLeavesPerMonth':     int.tryParse(tfSickLeaves.text)          ?? 1,
        'lateGracePeriodMinutes': int.tryParse(tfGraceMins.text)           ?? 10,
        'penaltyPerExcessAbsent': double.tryParse(tfPenaltyPerExcess.text) ?? 200,
        'noLeaveBonus':           double.tryParse(tfNoLeaveBonus.text)     ?? 300,
        'perfectAttendanceBonus': double.tryParse(tfPerfectBonus.text)     ?? 500,
        'streakBonusPer7Shifts':  double.tryParse(tfStreakBonus.text)      ?? 100,
        'overtimeGraceMinutes':   int.tryParse(tfOtGraceMins.text)         ?? 60,
        'overtimeMultiplier':     double.tryParse(tfOtMultiplier.text)     ?? 1.5,
      });
      settingsSaveOk.value = true;
      Future.delayed(const Duration(seconds: 3), () => settingsSaveOk.value = false);
    } on DioException catch (e) {
      settingsError.value = e.response?.data?['message'] as String? ?? 'Failed to save settings';
    } finally { isSavingSettings.value = false; }
  }

  // ════════════════════════════════════════════════════════════
  //  6. LEAVE
  // ════════════════════════════════════════════════════════════
  final isLoadingLeave = false.obs;
  final leaveRequests  = <LeaveRequest>[].obs;
  final leaveError     = Rxn<String>();
  final leaveFilter    = 'pending'.obs;

  final leaveSubmitting = false.obs;
  final leaveSubmitOk   = false.obs;
  final leaveSubmitErr  = Rxn<String>();
  final leaveStartDate  = ''.obs;   // "YYYY-MM-DD"
  final leaveEndDate    = ''.obs;
  final leaveShift      = 'DAY'.obs;
  final leaveType       = 'casual'.obs;
  final leaveReason     = ''.obs;
  // FIX #6 — stored employee ID so submitLeaveRequest() takes no args
  final leaveEmpId      = ''.obs;

  Future<void> fetchLeaveRequests() async {
    try {
      isLoadingLeave.value = true; leaveError.value = null;
      final res = await _dio.get('/leave/all', queryParameters: {
        if (leaveFilter.value != 'all') 'status': leaveFilter.value,
        'year':  selectedYear.value,
        'month': selectedMonth.value,
      });
      leaveRequests.value = (res.data['data'] as List? ?? [])
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      leaveError.value = e.response?.data?['message'] as String? ?? 'Failed to load leaves';
    } finally { isLoadingLeave.value = false; }
  }

  Future<void> approveLeave(String id) async {
    try { await _dio.put('/leave/$id/approve'); await fetchLeaveRequests(); }
    on DioException catch (_) {}
  }

  // FIX #2 — view calls rejectLeave(id, rem)
  Future<void> rejectLeave(String id, [String notes = '']) async {
    try {
      await _dio.put('/leave/$id/reject',
          data: notes.isNotEmpty ? {'adminRemarks': notes} : null);
      await fetchLeaveRequests();
    } on DioException catch (_) {}
  }

  void openLeaveFormFor(String employeeId) {
    leaveEmpId.value     = employeeId;  // FIX #6 — store for submitLeaveRequest
    leaveSubmitOk.value  = false;
    leaveSubmitErr.value = null;
    leaveStartDate.value = '';
    leaveEndDate.value   = '';
    leaveReason.value    = '';
  }

  // FIX #6 — no args; reads leaveEmpId set by openLeaveFormFor
  Future<void> submitLeaveRequest() async {
    final empId = leaveEmpId.value;
    if (empId.isEmpty) { leaveSubmitErr.value = 'No employee selected'; return; }
    try {
      leaveSubmitting.value = true; leaveSubmitOk.value = false; leaveSubmitErr.value = null;
      await _dio.post('/leave/request', data: {
        'employeeId': empId,
        'startDate':  leaveStartDate.value,
        'endDate':    leaveEndDate.value,
        'shift':      leaveShift.value,
        'leaveType':  leaveType.value,
        'reason':     leaveReason.value,
      });
      leaveSubmitOk.value = true;
      await fetchLeaveRequests();
    } on DioException catch (e) {
      leaveSubmitErr.value = e.response?.data?['message'] as String? ?? 'Submission failed';
    } finally { leaveSubmitting.value = false; }
  }

  // ════════════════════════════════════════════════════════════
  //  7. ADVANCE
  // ════════════════════════════════════════════════════════════
  final isLoadingAdv = false.obs;
  final advApproving = false.obs;
  final advances     = <AdvanceRequest>[].obs;
  final advError     = Rxn<String>();
  final advFilter    = 'pending'.obs;

  final advSubmitting = false.obs;
  final advSubmitOk   = false.obs;
  final advSubmitErr  = Rxn<String>();
  final advReason     = ''.obs;
  // FIX #7 — stored employee ID so submitAdvanceRequest(amount) takes 1 arg
  final advEmpId      = ''.obs;

  Future<void> fetchAdvances() async {
    try {
      isLoadingAdv.value = true; advError.value = null;
      final res = await _dio.get('/payroll/advance', queryParameters: {
        if (advFilter.value != 'all') 'status': advFilter.value,
      });
      advances.value = (res.data['data'] as List? ?? [])
          .map((e) => AdvanceRequest.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      advError.value = e.response?.data?['message'] as String? ?? 'Failed to load advances';
    } finally { isLoadingAdv.value = false; }
  }

  // FIX #4 — view calls approveAdvance(id, month, year, notes) — all positional
  Future<void> approveAdvance(
      String id, int deductMonth, int deductYear, [String notes = '']) async {
    try {
      advApproving.value = true;
      await _dio.put('/payroll/advance/$id/approve', data: {
        'deductMonth': deductMonth,
        'deductYear':  deductYear,
        if (notes.isNotEmpty) 'adminNotes': notes,
      });
      await fetchAdvances();
    } on DioException catch (_) {
    } finally { advApproving.value = false; }
  }

  // FIX #3 — view calls rejectAdvance(id, notes)
  Future<void> rejectAdvance(String id, [String notes = '']) async {
    try {
      await _dio.put('/payroll/advance/$id/reject',
          data: notes.isNotEmpty ? {'adminNotes': notes} : null);
      await fetchAdvances();
    } on DioException catch (_) {}
  }

  void openAdvanceFormFor(String employeeId) {
    advEmpId.value     = employeeId;  // FIX #7 — store for submitAdvanceRequest
    advSubmitOk.value  = false;
    advSubmitErr.value = null;
    advReason.value    = '';
  }

  // FIX #7 — 1 arg only; reads advEmpId set by openAdvanceFormFor
  Future<void> submitAdvanceRequest(double amount) async {
    final empId = advEmpId.value;
    if (empId.isEmpty) { advSubmitErr.value = 'No employee selected'; return; }
    try {
      advSubmitting.value = true; advSubmitOk.value = false; advSubmitErr.value = null;
      await _dio.post('/payroll/advance', data: {
        'employeeId': empId, 'amount': amount, 'reason': advReason.value,
      });
      advSubmitOk.value = true;
    } on DioException catch (e) {
      advSubmitErr.value = e.response?.data?['message'] as String? ?? 'Submission failed';
    } finally { advSubmitting.value = false; }
  }

  // ════════════════════════════════════════════════════════════
  //  8. ANALYTICS
  // ════════════════════════════════════════════════════════════
  final isLoadingAna = false.obs;
  final analytics    = <AnalyticsEmployee>[].obs;
  final anaSummary   = Rxn<AnalyticsSummary>();
  final anaError     = Rxn<String>();
  final anaYear      = DateTime.now().year.obs;
  // FIX #9 — was Rxn<int>() (nullable); view uses != 0 and == m
  // 0 = All Year,  1–12 = specific month
  final anaMonth     = 0.obs;

  Future<void> fetchAnalytics() async {
    try {
      isLoadingAna.value = true; anaError.value = null;
      final res = await _dio.get('/payroll/analytics', queryParameters: {
        'year':  anaYear.value,
        if (anaMonth.value != 0) 'month': anaMonth.value,
      });
      final data = res.data as Map<String, dynamic>;
      anaSummary.value = AnalyticsSummary.fromJson(
          data['summary'] as Map<String, dynamic>? ?? {});
      analytics.value = (data['data'] as List? ?? [])
          .map((e) => AnalyticsEmployee.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      anaError.value = e.response?.data?['message'] as String? ?? 'Failed to load analytics';
    } finally { isLoadingAna.value = false; }
  }

  // ════════════════════════════════════════════════════════════
  //  9. YEARLY BONUS
  // ════════════════════════════════════════════════════════════
  final isLoadingYB   = false.obs;
  final isComputingYB = false.obs;
  final yearlyBonuses = <YearlyBonus>[].obs;

  Future<void> fetchYearlyBonuses() async {
    try {
      isLoadingYB.value = true;
      final res = await _dio.get('/payroll/yearly-bonus',
          queryParameters: {'year': selectedYear.value});
      yearlyBonuses.value = (res.data['data'] as List? ?? [])
          .map((e) => YearlyBonus.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (_) {
    } finally { isLoadingYB.value = false; }
  }

  Future<void> computeYearlyBonuses() async {
    try {
      isComputingYB.value = true;
      await _dio.post('/payroll/yearly-bonus/compute',
          queryParameters: {'year': selectedYear.value});
      await fetchYearlyBonuses();
    } on DioException catch (_) {
    } finally { isComputingYB.value = false; }
  }

  // FIX #5 — view calls payYearlyBonus(id, note)
  Future<void> payYearlyBonus(String id, [String note = '']) async {
    try {
      await _dio.put('/payroll/yearly-bonus/$id/pay',
          data: {'paidBy': 'admin', if (note.isNotEmpty) 'paymentNote': note});
      await fetchYearlyBonuses();
    } on DioException catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  //  10. LIFECYCLE
  // ════════════════════════════════════════════════════════════
  @override
  void onInit() {
    super.onInit();
    fetchDashboard();
    fetchSettings();
    fetchRates();
  }

  @override
  void onClose() {
    for (final c in [
      tfCasualLeaves, tfSickLeaves, tfGraceMins, tfPenaltyPerExcess,
      tfNoLeaveBonus, tfPerfectBonus, tfStreakBonus,
      tfOtGraceMins, tfOtMultiplier,
    ]) { c.dispose(); }
    super.onClose();
  }
}