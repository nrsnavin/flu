// ══════════════════════════════════════════════════════════════
//  PAYROLL MODELS  v4
//  File: lib/src/features/payroll/models/payroll_models.dart
// ══════════════════════════════════════════════════════════════

enum PayrollView { dashboard, payslip, rates, settings, leave, analytics, advance ,bonus}

const kMonths = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
int    _i(dynamic v) => (v as num?)?.toInt()    ?? 0;
String _s(dynamic v) => v?.toString()           ?? '';
bool   _b(dynamic v) => v as bool?              ?? false;

// ══════════════════════════════════════════════════════════════
//  EMPLOYEE RATE ROW
// ══════════════════════════════════════════════════════════════
class EmployeeRate {
  final String id, name, department, role;
  final double hourlyRate, dayShiftPay, nightShiftPay;
  const EmployeeRate({required this.id, required this.name, required this.department,
    required this.role, required this.hourlyRate, required this.dayShiftPay,
    required this.nightShiftPay});
  factory EmployeeRate.fromJson(Map<String, dynamic> j) => EmployeeRate(
      id: _s(j['id'] ?? j['_id']), name: _s(j['name']), department: _s(j['department']),
      role: _s(j['role']), hourlyRate: _d(j['hourlyRate']),
      dayShiftPay: _d(j['dayShiftPay']), nightShiftPay: _d(j['nightShiftPay']));
  EmployeeRate withRate(double r) => EmployeeRate(id: id, name: name, department: department,
      role: role, hourlyRate: r, dayShiftPay: r * 12, nightShiftPay: r * 8);
}

// ══════════════════════════════════════════════════════════════
//  PAYROLL SETTINGS
// ══════════════════════════════════════════════════════════════
class PayrollSettings {
  final int    casualLeavesPerMonth, sickLeavesPerMonth, lateGracePeriodMinutes;
  final double penaltyPerExcessAbsent, noLeaveBonus, perfectAttendanceBonus, streakBonusPer7Shifts;
  int get totalLeaveQuota => casualLeavesPerMonth + sickLeavesPerMonth;
  const PayrollSettings({required this.casualLeavesPerMonth, required this.sickLeavesPerMonth,
    required this.lateGracePeriodMinutes, required this.penaltyPerExcessAbsent,
    required this.noLeaveBonus, required this.perfectAttendanceBonus,
    required this.streakBonusPer7Shifts});
  factory PayrollSettings.defaults() => const PayrollSettings(
      casualLeavesPerMonth: 2, sickLeavesPerMonth: 1, lateGracePeriodMinutes: 10,
      penaltyPerExcessAbsent: 200, noLeaveBonus: 300, perfectAttendanceBonus: 500,
      streakBonusPer7Shifts: 100);
  factory PayrollSettings.fromJson(Map<String, dynamic> j) => PayrollSettings(
      casualLeavesPerMonth:   _i(j['casualLeavesPerMonth'])   == 0 ? 2  : _i(j['casualLeavesPerMonth']),
      sickLeavesPerMonth:     _i(j['sickLeavesPerMonth'])     == 0 ? 1  : _i(j['sickLeavesPerMonth']),
      lateGracePeriodMinutes: _i(j['lateGracePeriodMinutes']) == 0 ? 10 : _i(j['lateGracePeriodMinutes']),
      penaltyPerExcessAbsent: _d(j['penaltyPerExcessAbsent']),
      noLeaveBonus:           _d(j['noLeaveBonus']),
      perfectAttendanceBonus: _d(j['perfectAttendanceBonus']),
      streakBonusPer7Shifts:  _d(j['streakBonusPer7Shifts']));
  Map<String, dynamic> toJson() => {
    'casualLeavesPerMonth': casualLeavesPerMonth, 'sickLeavesPerMonth': sickLeavesPerMonth,
    'lateGracePeriodMinutes': lateGracePeriodMinutes, 'penaltyPerExcessAbsent': penaltyPerExcessAbsent,
    'noLeaveBonus': noLeaveBonus, 'perfectAttendanceBonus': perfectAttendanceBonus,
    'streakBonusPer7Shifts': streakBonusPer7Shifts};
}

// ══════════════════════════════════════════════════════════════
//  PAYROLL DASHBOARD
// ══════════════════════════════════════════════════════════════
class PayrollDashboard {
  final int    totalEmployees, perfectCount, paidCount, finalizedCount, draftCount;
  final double totalNetPay, totalGross, totalDeductions, totalBonuses;
  final List<PayrollRow> employees;
  const PayrollDashboard({required this.totalEmployees, required this.totalNetPay,
    required this.totalGross, required this.totalDeductions, required this.totalBonuses,
    required this.perfectCount, required this.paidCount, required this.finalizedCount,
    required this.draftCount, required this.employees});
  factory PayrollDashboard.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] as Map<String, dynamic>? ?? {};
    return PayrollDashboard(
        totalEmployees: _i(s['totalEmployees']), totalNetPay: _d(s['totalNetPay']),
        totalGross: _d(s['totalGross']), totalDeductions: _d(s['totalDeductions']),
        totalBonuses: _d(s['totalBonuses']), perfectCount: _i(s['perfectCount']),
        paidCount: _i(s['paidCount']), finalizedCount: _i(s['finalizedCount']),
        draftCount: _i(s['draftCount']),
        employees: (j['employees'] as List? ?? [])
            .map((e) => PayrollRow.fromJson(e as Map<String, dynamic>)).toList());
  }
}

// ══════════════════════════════════════════════════════════════
//  PAYROLL ROW
// ══════════════════════════════════════════════════════════════
class PayrollRow {
  final String employeeId, name, department, status;
  final double hourlyRate, grossEarnings, totalDeductions, totalBonuses, netPay, totalAdvanceDeduction;
  final int    totalShifts, presentShifts, absentShifts, excessAbsents;
  final bool   perfectAttendance;
  const PayrollRow({required this.employeeId, required this.name, required this.department,
    required this.hourlyRate, required this.totalShifts, required this.presentShifts,
    required this.absentShifts, required this.excessAbsents, required this.grossEarnings,
    required this.totalDeductions, required this.totalBonuses, required this.netPay,
    required this.totalAdvanceDeduction, required this.perfectAttendance, required this.status});
  factory PayrollRow.fromJson(Map<String, dynamic> j) => PayrollRow(
      employeeId: _s(j['employeeId']), name: _s(j['name']), department: _s(j['department']),
      hourlyRate: _d(j['hourlyRate']), totalShifts: _i(j['totalShifts']),
      presentShifts: _i(j['presentShifts']), absentShifts: _i(j['absentShifts']),
      excessAbsents: _i(j['excessAbsents']), grossEarnings: _d(j['grossEarnings']),
      totalDeductions: _d(j['totalDeductions']), totalBonuses: _d(j['totalBonuses']),
      netPay: _d(j['netPay']), totalAdvanceDeduction: _d(j['totalAdvanceDeduction']),
      perfectAttendance: _b(j['perfectAttendance']), status: _s(j['status']));
}

// ══════════════════════════════════════════════════════════════
//  PAYROLL LINE ITEM
// ══════════════════════════════════════════════════════════════
class PayrollLineItem {
  final String label, type;
  final double amount;
  const PayrollLineItem({required this.label, required this.amount, required this.type});
  factory PayrollLineItem.fromJson(Map<String, dynamic> j) => PayrollLineItem(
      label: _s(j['label']), amount: _d(j['amount']), type: _s(j['type']));
}

// ══════════════════════════════════════════════════════════════
//  PAYROLL DOC  (full payslip)
// ══════════════════════════════════════════════════════════════
class PayrollDoc {
  final String id, employeeName, department, status;
  final double hourlyRate;
  final int    month, year;
  final int    totalShifts, presentShifts, halfDayShifts, absentShifts;
  final int    approvedLeaveShifts, totalLateMinutes, unapprovedAbsents, excessAbsents;
  final int    dayShiftsWorked, nightShiftsWorked;
  final double dayShiftEarnings, nightShiftEarnings;
  final double grossEarnings, totalDeductions, totalBonuses, netPay;
  final double noLeaveBonus, perfectAttendanceBonus, totalStreakBonus, totalAdvanceDeduction;
  final int    longestStreak;
  final bool   perfectAttendance;
  final List<PayrollLineItem> lineItems;
  final String? paidAt, paidBy, paymentNote;
  String get monthLabel => kMonths[month];
  List<PayrollLineItem> get earnings   => lineItems.where((l) => l.type == 'earning').toList();
  List<PayrollLineItem> get deductions => lineItems.where((l) => l.type == 'deduction' && l.amount != 0).toList();
  List<PayrollLineItem> get bonuses    => lineItems.where((l) => l.type == 'bonus').toList();

  const PayrollDoc({
    required this.id, required this.employeeName, required this.department,
    required this.hourlyRate, required this.month, required this.year, required this.status,
    required this.totalShifts, required this.presentShifts, required this.halfDayShifts,
    required this.absentShifts, required this.approvedLeaveShifts, required this.totalLateMinutes,
    required this.unapprovedAbsents, required this.excessAbsents,
    required this.dayShiftsWorked, required this.nightShiftsWorked,
    required this.dayShiftEarnings, required this.nightShiftEarnings,
    required this.grossEarnings, required this.totalDeductions, required this.totalBonuses,
    required this.netPay, required this.noLeaveBonus, required this.perfectAttendanceBonus,
    required this.totalStreakBonus, required this.totalAdvanceDeduction,
    required this.longestStreak, required this.perfectAttendance, required this.lineItems,
    this.paidAt, this.paidBy, this.paymentNote,
  });

  factory PayrollDoc.fromJson(Map<String, dynamic> raw) {
    final j   = raw['data'] is Map ? raw['data'] as Map<String, dynamic> : raw;
    final emp = j['employee'];
    return PayrollDoc(
        id: _s(j['_id'] ?? j['id']),
        employeeName: emp is Map ? _s(emp['name']) : _s(j['employeeName']),
        department:   emp is Map ? _s(emp['department']) : _s(j['department']),
        hourlyRate:   _d(j['hourlyRate']), month: _i(j['month']), year: _i(j['year']),
        status:       _s(j['status']), totalShifts: _i(j['totalShifts']),
        presentShifts: _i(j['presentShifts']), halfDayShifts: _i(j['halfDayShifts']),
        absentShifts: _i(j['absentShifts']), approvedLeaveShifts: _i(j['approvedLeaveShifts']),
        totalLateMinutes: _i(j['totalLateMinutes']), unapprovedAbsents: _i(j['unapprovedAbsents']),
        excessAbsents: _i(j['excessAbsents']), dayShiftsWorked: _i(j['dayShiftsWorked']),
        nightShiftsWorked: _i(j['nightShiftsWorked']), dayShiftEarnings: _d(j['dayShiftEarnings']),
        nightShiftEarnings: _d(j['nightShiftEarnings']), grossEarnings: _d(j['grossEarnings']),
        totalDeductions: _d(j['totalDeductions']), totalBonuses: _d(j['totalBonuses']),
        netPay: _d(j['netPay']), noLeaveBonus: _d(j['noLeaveBonus']),
        perfectAttendanceBonus: _d(j['perfectAttendanceBonus']),
        totalStreakBonus: _d(j['totalStreakBonus']),
        totalAdvanceDeduction: _d(j['totalAdvanceDeduction']),
        longestStreak: _i(j['longestStreak']), perfectAttendance: _b(j['perfectAttendance']),
        lineItems: (j['lineItems'] as List? ?? [])
            .map((e) => PayrollLineItem.fromJson(e as Map<String, dynamic>)).toList(),
        paidAt: j['paidAt']?.toString(), paidBy: j['paidBy']?.toString(),
        paymentNote: j['paymentNote']?.toString());
  }
}

// ══════════════════════════════════════════════════════════════
//  LEAVE REQUEST
// ══════════════════════════════════════════════════════════════
enum LeaveRequestStatus { pending, approved, rejected }

class LeaveRequest {
  final String id, name, department, startDate, endDate, shift, leaveType, reason, adminRemarks;
  final LeaveRequestStatus status;
  final int  totalDays;
  final bool penaltyExempt;
  const LeaveRequest({required this.id, required this.name, required this.department,
    required this.startDate, required this.endDate, required this.shift, required this.leaveType,
    required this.reason, required this.adminRemarks, required this.status,
    required this.totalDays, required this.penaltyExempt});
  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
      id: _s(j['_id'] ?? j['id']), name: _s(j['name'] ?? j['employeeName']),
      department: _s(j['department'] ?? j['employeeDept']),
      startDate: _s(j['startDate'] ?? j['date']), endDate: _s(j['endDate'] ?? j['date']),
      shift: _s(j['shift']), leaveType: _s(j['leaveType']), reason: _s(j['reason']),
      adminRemarks: _s(j['adminRemarks'] ?? j['reviewNotes']),
      status: _parseStatus(_s(j['status'])),
      totalDays: _i(j['totalDays']) == 0 ? 1 : _i(j['totalDays']),
      penaltyExempt: _b(j['penaltyExempt']) || _parseStatus(_s(j['status'])) == LeaveRequestStatus.approved);
  static LeaveRequestStatus _parseStatus(String s) => switch (s) {
    'approved' => LeaveRequestStatus.approved,
    'rejected' => LeaveRequestStatus.rejected,
    _ => LeaveRequestStatus.pending,
  };
}

// ══════════════════════════════════════════════════════════════
//  ADVANCE REQUEST
// ══════════════════════════════════════════════════════════════
enum AdvanceStatus { pending, approved, rejected }

class AdvanceRequest {
  final String id, employeeName, department, reason, adminNotes, approvedBy;
  final double amount;
  final AdvanceStatus status;
  final int?   deductMonth, deductYear;
  final bool   deductedInPayroll;
  final String createdAt;

  const AdvanceRequest({required this.id, required this.employeeName,
    required this.department, required this.amount, required this.reason,
    required this.adminNotes, required this.approvedBy, required this.status,
    this.deductMonth, this.deductYear, required this.deductedInPayroll,
    required this.createdAt});

  factory AdvanceRequest.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'];
    return AdvanceRequest(
        id:             _s(j['_id'] ?? j['id']),
        employeeName:   emp is Map ? _s(emp['name']) : _s(j['employeeName']),
        department:     emp is Map ? _s(emp['department']) : _s(j['department']),
        amount:         _d(j['amount']),
        reason:         _s(j['reason']),
        adminNotes:     _s(j['adminNotes']),
        approvedBy:     _s(j['approvedBy']),
        status:         _parseAdv(_s(j['status'])),
        deductMonth:    j['deductMonth'] != null ? _i(j['deductMonth']) : null,
        deductYear:     j['deductYear']  != null ? _i(j['deductYear'])  : null,
        deductedInPayroll: _b(j['deductedInPayroll']),
        createdAt:      _s(j['createdAt']));
  }

  static AdvanceStatus _parseAdv(String s) => switch (s) {
    'approved' => AdvanceStatus.approved,
    'rejected' => AdvanceStatus.rejected,
    _ => AdvanceStatus.pending,
  };
}

// ══════════════════════════════════════════════════════════════
//  YEARLY BONUS
// ══════════════════════════════════════════════════════════════
class YearlyBonus {
  final String id, employeeName, department, status;
  final double totalAnnualPay, bonusAmount;
  final int    year, monthsCounted;
  final String? paidAt, paidBy;

  const YearlyBonus({required this.id, required this.employeeName, required this.department,
    required this.totalAnnualPay, required this.bonusAmount, required this.year,
    required this.monthsCounted, required this.status, this.paidAt, this.paidBy});

  factory YearlyBonus.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'];
    return YearlyBonus(
        id:             _s(j['_id'] ?? j['id']),
        employeeName:   emp is Map ? _s(emp['name']) : _s(j['name']),
        department:     emp is Map ? _s(emp['department']) : _s(j['department']),
        totalAnnualPay: _d(j['totalAnnualPay']),
        bonusAmount:    _d(j['bonusAmount']),
        year:           _i(j['year']),
        monthsCounted:  _i(j['monthsCounted']),
        status:         _s(j['status']),
        paidAt:         j['paidAt']?.toString(),
        paidBy:         j['paidBy']?.toString());
  }
}

// ══════════════════════════════════════════════════════════════
//  ANALYTICS  — per-employee performance
// ══════════════════════════════════════════════════════════════
class AnalyticsEmployee {
  final String employeeId, name, department;
  final double hourlyRate, attendanceRate, totalGross, totalBonuses, totalDeductions, totalNetPay;
  final int    months, totalShifts, presentShifts, absentShifts;
  final int    approvedLeaveShifts, totalLateMinutes, perfectMonths, longestStreak, rank;

  const AnalyticsEmployee({
    required this.employeeId, required this.name, required this.department,
    required this.hourlyRate, required this.attendanceRate, required this.months,
    required this.totalShifts, required this.presentShifts, required this.absentShifts,
    required this.approvedLeaveShifts, required this.totalLateMinutes,
    required this.totalGross, required this.totalBonuses, required this.totalDeductions,
    required this.totalNetPay, required this.perfectMonths, required this.longestStreak,
    required this.rank,
  });

  factory AnalyticsEmployee.fromJson(Map<String, dynamic> j) => AnalyticsEmployee(
      employeeId:          _s(j['employeeId']),
      name:                _s(j['name']),
      department:          _s(j['department']),
      hourlyRate:          _d(j['hourlyRate']),
      attendanceRate:      _d(j['attendanceRate']),
      months:              _i(j['months']),
      totalShifts:         _i(j['totalShifts']),
      presentShifts:       _i(j['presentShifts']),
      absentShifts:        _i(j['absentShifts']),
      approvedLeaveShifts: _i(j['approvedLeaveShifts']),
      totalLateMinutes:    _i(j['totalLateMinutes']),
      totalGross:          _d(j['totalGross']),
      totalBonuses:        _d(j['totalBonuses']),
      totalDeductions:     _d(j['totalDeductions']),
      totalNetPay:         _d(j['totalNetPay']),
      perfectMonths:       _i(j['perfectMonths']),
      longestStreak:       _i(j['longestStreak']),
      rank:                _i(j['rank']));
}

class AnalyticsSummary {
  final int    totalEmployees;
  final double totalPayout, avgAttendanceRate;
  const AnalyticsSummary({required this.totalEmployees, required this.totalPayout,
    required this.avgAttendanceRate});
  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) => AnalyticsSummary(
      totalEmployees:   _i(j['totalEmployees']),
      totalPayout:      _d(j['totalPayout']),
      avgAttendanceRate:_d(j['avgAttendanceRate']));
}