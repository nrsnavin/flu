// ══════════════════════════════════════════════════════════════
//  BEFORE THE WAGES GO, AND AFTER
//
//  The month's payslips checked against each worker's own recent
//  months (GET /payroll/check — services/payrollCheck.js), and one
//  worker's money trail with a running balance (GET /payroll/ledger/:id
//  — services/ledgerService.js). Both are read only.
// ══════════════════════════════════════════════════════════════

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String _s(Object? v) => v?.toString() ?? '';
DateTime? _date(Object? v) => v == null || '$v'.isEmpty ? null : DateTime.tryParse('$v')?.toLocal();
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

/// One reason a slip wants a look. Severity: high (very likely wrong —
/// negative pay, pay with no shift worked), check (unusual for this
/// worker), info (worth knowing — a first month, a rate change).
class PayslipFlag {
  const PayslipFlag({required this.code, required this.severity, required this.reason});

  final String code, severity, reason;

  factory PayslipFlag.fromJson(Map<String, dynamic> j) =>
      PayslipFlag(code: _s(j['code']), severity: _s(j['severity']), reason: _s(j['reason']));
}

class PayslipCheckRow {
  const PayslipCheckRow({
    required this.payrollId,
    required this.employeeId,
    required this.name,
    this.department = '',
    this.status = '',
    this.netPay = 0,
    this.flags = const [],
  });

  final String payrollId, employeeId, name, department, status;
  final double netPay;

  /// Worst first.
  final List<PayslipFlag> flags;

  String get worst => flags.isEmpty ? 'info' : flags.first.severity;

  factory PayslipCheckRow.fromJson(Map<String, dynamic> j) => PayslipCheckRow(
        payrollId: _s(j['payrollId']),
        employeeId: _s(j['employeeId']),
        name: _s(j['name']),
        department: _s(j['department']),
        status: _s(j['status']),
        netPay: _d(j['netPay']),
        flags: _maps(j['flags']).map(PayslipFlag.fromJson).toList(),
      );
}

/// A month's slips, checked. Only slips with something to say are rows.
class PayrollCheck {
  const PayrollCheck({
    required this.year,
    required this.month,
    this.slips = 0,
    this.high = 0,
    this.check = 0,
    this.info = 0,
    this.totalNet = 0,
    this.lastMonthNet = 0,
    this.rows = const [],
  });

  final int year, month, slips, high, check, info;
  final double totalNet, lastMonthNet;
  final List<PayslipCheckRow> rows;

  factory PayrollCheck.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : const <String, dynamic>{};
    return PayrollCheck(
      year: _i(j['year']),
      month: _i(j['month']),
      slips: _i(s['slips']),
      high: _i(s['high']),
      check: _i(s['check']),
      info: _i(s['info']),
      totalNet: _d(s['totalNet']),
      lastMonthNet: _d(s['lastMonthNet']),
      rows: _maps(j['rows']).map(PayslipCheckRow.fromJson).toList(),
    );
  }
}

/// One line on a worker's ledger. The amount is signed from the
/// worker's side: + the factory owes more (pay, bonus), − it owes less
/// (penalties, PF/ESI, an advance given or recovered, salary paid).
class LedgerLine {
  const LedgerLine({required this.id, this.date, required this.kind, this.label = '', this.amount = 0, this.balance = 0});

  final String id;
  final DateTime? date;
  final String kind, label;
  final double amount;

  /// Still payable to the worker after this line.
  final double balance;

  String get kindLabel => switch (kind) {
        'shift_salary' => 'Shift pay',
        'overtime' => 'Overtime',
        'bonus' => 'Bonus',
        'diwali_bonus' => 'Diwali bonus',
        'penalty' => 'Penalty',
        'absence' => 'Absence',
        'statutory' => 'PF / ESI',
        'advance_issued' => 'Advance given',
        'advance_recovered' => 'Advance recovered',
        'payment' => 'Salary paid',
        'adjustment' => 'Adjustment',
        'write_off' => 'Written off',
        _ => kind,
      };

  factory LedgerLine.fromJson(Map<String, dynamic> j) => LedgerLine(
        id: _s(j['_id']),
        date: _date(j['date']),
        kind: _s(j['kind']),
        label: _s(j['label']),
        amount: _d(j['amount']),
        balance: _d(j['balance']),
      );
}

class EmployeeLedger {
  const EmployeeLedger({
    this.name = '',
    this.department = '',
    this.from,
    this.to,
    this.opening = 0,
    this.closing = 0,
    this.lines = const [],
    this.totals = const {},
  });

  final String name, department;
  final DateTime? from, to;
  final double opening, closing;

  /// Oldest first, as the server sends them.
  final List<LedgerLine> lines;

  /// earnings, bonuses, penalties, statutory, advances, payments, writtenOff.
  final Map<String, double> totals;

  factory EmployeeLedger.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] is Map ? Map<String, dynamic>.from(j['employee'] as Map) : const <String, dynamic>{};
    final range = j['range'] is Map ? Map<String, dynamic>.from(j['range'] as Map) : const <String, dynamic>{};
    final t = j['totals'] is Map ? Map<String, dynamic>.from(j['totals'] as Map) : const <String, dynamic>{};
    return EmployeeLedger(
      name: _s(emp['name']),
      department: _s(emp['department']),
      from: _date(range['from']),
      to: _date(range['to']),
      opening: _d(j['openingBalance']),
      closing: _d(j['closingBalance']),
      lines: _maps(j['entries']).map(LedgerLine.fromJson).toList(),
      totals: {for (final e in t.entries) e.key: _d(e.value)},
    );
  }
}
