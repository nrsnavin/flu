// ══════════════════════════════════════════════════════════════
//  PAYROLL PAGE  v4
//  File: lib/src/features/payroll/screens/payroll_page.dart
//
//  Views: dashboard · payslip · rates · settings · leave
//         analytics · advance
//  ZERO Obx — all reactive widgets are StatefulWidgets + ever()
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/payroll_controller.dart';
import '../models/payroll_models.dart';
import 'Bonus_tab.dart';

// ── Palette ────────────────────────────────────────────────────
const _bg = Color(0xFF060D18);
const _s1 = Color(0xFF0B1626);
const _s2 = Color(0xFF0F1F33);
const _s3 = Color(0xFF162540);
const _bdr = Color(0xFF1A2E4A);
const _blue = Color(0xFF2563EB);
const _blueLt = Color(0xFF60A5FA);
const _green = Color(0xFF10B981);
const _greenLt = Color(0xFF34D399);
const _amber = Color(0xFFF59E0B);
const _amberLt = Color(0xFFFBBF24);
const _red = Color(0xFFEF4444);
const _redLt = Color(0xFFFCA5A5);
const _purple = Color(0xFF8B5CF6);
const _purpLt = Color(0xFFC4B5FD);
const _teal = Color(0xFF14B8A6);
const _tealLt = Color(0xFF5EEAD4);
const _gold = Color(0xFFEAB308);
const _goldLt = Color(0xFFFDE047);
const _tp = Color(0xFFF0F6FF);
const _ts = Color(0xFF8BA4C2);
const _tm = Color(0xFF3D5470);

String _(double v) => '₹${v.toStringAsFixed(0)}';
String _k(double v) => v >= 1000 ? '₹${(v / 1000).toStringAsFixed(1)}k' : _(v);

// ══════════════════════════════════════════════════════════════
//  ROOT
// ══════════════════════════════════════════════════════════════
class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});
  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late final PayrollController c;
  @override
  void initState() {
    super.initState();
    Get.delete<PayrollController>(force: true);
    c = Get.put(PayrollController());
    ever(c.activeView, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body = switch (c.activeView.value) {
      PayrollView.dashboard => _DashView(c: c),
      PayrollView.payslip => _SlipView(c: c),
      PayrollView.rates => _RatesView(c: c),
      PayrollView.settings => _SettingsView(c: c),
      PayrollView.leave => _LeaveView(c: c),
      PayrollView.analytics => _AnalyticsView(c: c),
      PayrollView.advance => _AdvanceView(c: c),
      PayrollView.bonus => BonusTab(),
    };
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _TopBar(c: c),
          _Tabs(c: c),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TOP BAR
// ══════════════════════════════════════════════════════════════
class _TopBar extends StatefulWidget {
  final PayrollController c;
  const _TopBar({required this.c});
  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    ever(c.activeView, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext ctx) {
    final top = MediaQuery.of(ctx).padding.top;
    return Container(
      color: _s1,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 10),
      child: Row(
        children: [
          _IBtn(Icons.arrow_back_ios_new, 14, Get.back),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payroll',
                  style: TextStyle(
                    color: _tp,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Hourly · Shift-based · Auto-compute',
                  style: TextStyle(color: _tm, fontSize: 10),
                ),
              ],
            ),
          ),
          _IBtn(Icons.refresh_rounded, 16, _refresh),
        ],
      ),
    );
  }

  void _refresh() {
    switch (c.activeView.value) {
      case PayrollView.dashboard:
        c.fetchDashboard();
        break;
      case PayrollView.rates:
        c.fetchRates();
        break;
      case PayrollView.settings:
        c.fetchSettings();
        break;
      case PayrollView.leave:
        c.fetchLeaveRequests();
        break;
      case PayrollView.advance:
        c.fetchAdvances();
        break;
      case PayrollView.analytics:
        c.fetchAnalytics();
        break;
      default:
        break;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  TABS
// ══════════════════════════════════════════════════════════════
class _Tabs extends StatefulWidget {
  final PayrollController c;
  const _Tabs({required this.c});
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    ever(c.activeView, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext ctx) {
    final av = c.activeView.value;
    return Container(
      color: _s1,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _t('💰', 'Monthly', PayrollView.dashboard, av),
            _t('₹', 'Rates', PayrollView.rates, av),
            _t('⚙️', 'Settings', PayrollView.settings, av),
            _t('🏖', 'Leave', PayrollView.leave, av),
            _t('📊', 'Analytics', PayrollView.analytics, av),
            _t('💳', 'Advance', PayrollView.advance, av),
            _t('🎁', 'Bonus', PayrollView.bonus, av),
            if (av == PayrollView.payslip)
              _t('🧾', 'Payslip', PayrollView.payslip, av),
          ].expand((w) => [w, const SizedBox(width: 6)]).toList()..removeLast(),
        ),
      ),
    );
  }

  Widget _t(String ic, String lb, PayrollView v, PayrollView av) {
    final on = av == v;
    return GestureDetector(
      onTap: () => c.activeView.value = v,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: on ? _blue.withOpacity(0.18) : _s3,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: on ? _blue.withOpacity(0.5) : _bdr),
        ),
        child: Text(
          '$ic $lb',
          style: TextStyle(
            color: on ? _blueLt : _ts,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 1 — DASHBOARD
// ══════════════════════════════════════════════════════════════
class _DashView extends StatefulWidget {
  final PayrollController c;
  const _DashView({required this.c});
  @override
  State<_DashView> createState() => _DashViewState();
}

class _DashViewState extends State<_DashView> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingDash,
      c.dashError,
      c.dashboard,
      c.isGenerating,
      c.generateMsg,
      c.generateError,
      c.selectedMonth,
      c.selectedYear,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext ctx) => Column(
    children: [
      _MonthBar(c: c),
      Expanded(child: _body()),
    ],
  );
  Widget _body() {
    if (c.isLoadingDash.value) return const _Spin();
    if (c.dashError.value != null) return _Err(c.dashError.value!);
    final d = c.dashboard.value;
    if (d == null || d.totalEmployees == 0) return _EmptyDash(c: c);
    return _DashBody(c: c, d: d);
  }
}

class _MonthBar extends StatelessWidget {
  final PayrollController c;
  const _MonthBar({required this.c});
  @override
  Widget build(BuildContext ctx) => Container(
    color: _s1,
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
    child: Column(
      children: [
        Row(
          children: [
            _IBtn(Icons.chevron_left_rounded, 20, c.prevMonth),
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: Text(
                  c.monthLabel,
                  style: const TextStyle(
                    color: _tp,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IBtn(
              Icons.chevron_right_rounded,
              20,
              c.canGoNextMonth ? c.nextMonth : () {},
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GBtn(
          c.isGenerating.value ? 'Generating…' : '⚡ Generate Payroll',
          _green,
          c.isGenerating.value,
          c.generateAll,
        ),
        if (c.generateMsg.value != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              c.generateMsg.value!,
              style: const TextStyle(color: _greenLt, fontSize: 11),
            ),
          ),
        if (c.generateError.value != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              c.generateError.value!,
              style: const TextStyle(color: _redLt, fontSize: 11),
            ),
          ),
      ],
    ),
  );
}

class _EmptyDash extends StatelessWidget {
  final PayrollController c;
  const _EmptyDash({required this.c});
  @override
  Widget build(BuildContext ctx) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('💰', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 10),
        const Text(
          'No payroll generated',
          style: TextStyle(color: _ts, fontSize: 13),
        ),
        const SizedBox(height: 6),
        const Text(
          'Set hourly rates first, then tap Generate',
          style: TextStyle(color: _tm, fontSize: 11),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => c.activeView.value = PayrollView.rates,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _blue.withOpacity(0.4)),
            ),
            child: const Text(
              'Set Employee Rates →',
              style: TextStyle(
                color: _blueLt,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DashBody extends StatelessWidget {
  final PayrollController c;
  final PayrollDashboard d;
  const _DashBody({required this.c, required this.d});
  @override
  Widget build(BuildContext ctx) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      Row(
        children: [
          Expanded(child: _Kpi(_k(d.totalNetPay), 'Net Payout', _green)),
          const SizedBox(width: 8),
          Expanded(child: _Kpi(_k(d.totalGross), 'Gross', _blueLt)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _Kpi2(_k(d.totalDeductions), 'Deductions', _red)),
          const SizedBox(width: 6),
          Expanded(child: _Kpi2(_k(d.totalBonuses), 'Bonuses', _amber)),
          const SizedBox(width: 6),
          Expanded(child: _Kpi2('${d.perfectCount}', '🏆 Perfect', _green)),
        ],
      ),
      const SizedBox(height: 8),
      _StatusBar(
        paid: d.paidCount,
        finalized: d.finalizedCount,
        draft: d.draftCount,
        total: d.totalEmployees,
      ),
      const SizedBox(height: 14),
      const _SecLbl('👷 Employees'),
      const SizedBox(height: 8),
      ...d.employees.map((r) => _EmpRow(row: r, c: c)),
      const SizedBox(height: 30),
    ],
  );
}

class _StatusBar extends StatelessWidget {
  final int paid, finalized, draft, total;
  const _StatusBar({
    required this.paid,
    required this.finalized,
    required this.draft,
    required this.total,
  });
  @override
  Widget build(BuildContext ctx) {
    if (total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _s2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (paid > 0)
                    Expanded(
                      flex: paid,
                      child: Container(color: _green),
                    ),
                  if (finalized > 0)
                    Expanded(
                      flex: finalized,
                      child: Container(color: _amber),
                    ),
                  if (draft > 0)
                    Expanded(
                      flex: draft,
                      child: Container(color: _s3),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LegDot(_green, 'Paid ($paid)'),
              _LegDot(_amber, 'Finalised ($finalized)'),
              _LegDot(_s3, 'Draft ($draft)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmpRow extends StatelessWidget {
  final PayrollRow row;
  final PayrollController c;
  const _EmpRow({required this.row, required this.c});
  @override
  Widget build(BuildContext ctx) {
    final sc = row.status == 'paid'
        ? _green
        : row.status == 'finalized'
        ? _amber
        : _ts;
    return GestureDetector(
      onTap: () => c.openPayslip(row.employeeId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _s2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: row.excessAbsents > 0 ? _red.withOpacity(0.35) : _bdr,
          ),
        ),
        child: Row(
          children: [
            _Avatar(row.name, row.perfectAttendance ? _green : _blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: const TextStyle(
                            color: _tp,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (row.perfectAttendance)
                        const Text('🏆', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${row.hourlyRate.toStringAsFixed(0)}/hr',
                        style: const TextStyle(color: _ts, fontSize: 10),
                      ),
                      const Text(
                        '  ·  ',
                        style: TextStyle(color: _tm, fontSize: 10),
                      ),
                      Text(
                        '${row.presentShifts}P  ${row.absentShifts}A',
                        style: const TextStyle(color: _ts, fontSize: 10),
                      ),
                      if (row.totalAdvanceDeduction > 0) ...[
                        const Text('  ', style: TextStyle(fontSize: 10)),
                        Text(
                          '−${_(row.totalAdvanceDeduction)} adv',
                          style: const TextStyle(color: _redLt, fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _(row.netPay),
                  style: const TextStyle(
                    color: _tp,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    row.status.toUpperCase(),
                    style: TextStyle(
                      color: sc,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 14, color: _tm),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 2 — PAYSLIP
// ══════════════════════════════════════════════════════════════
class _SlipView extends StatefulWidget {
  final PayrollController c;
  const _SlipView({required this.c});
  @override
  State<_SlipView> createState() => _SlipViewState();
}

class _SlipViewState extends State<_SlipView> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingPayslip,
      c.payslipError,
      c.payslip,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext ctx) {
    if (c.isLoadingPayslip.value) return const _Spin();
    if (c.payslipError.value != null) return _Err(c.payslipError.value!);
    final ps = c.payslip.value;
    if (ps == null) return const _Hint('Tap an employee to view payslip');
    return _SlipBody(ps: ps, c: c);
  }
}

class _SlipBody extends StatelessWidget {
  final PayrollDoc ps;
  final PayrollController c;
  const _SlipBody({required this.ps, required this.c});
  @override
  Widget build(BuildContext ctx) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      // Header card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B2040), Color(0xFF071630)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _blue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _Avatar(ps.employeeName, _blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ps.employeeName,
                        style: const TextStyle(
                          color: _tp,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ps.department,
                        style: const TextStyle(color: _ts, fontSize: 11),
                      ),
                      Text(
                        '${ps.monthLabel} ${ps.year}',
                        style: const TextStyle(
                          color: _blueLt,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(ps.status),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _(ps.netPay),
              style: const TextStyle(
                color: _greenLt,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'NET PAY',
              style: TextStyle(color: _ts, fontSize: 10, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniPay('Gross', _(ps.grossEarnings), _blueLt),
                if (ps.totalDeductions > 0) ...[
                  const Text(' − ', style: TextStyle(color: _tm)),
                  _MiniPay('Deductions', _(ps.totalDeductions), _redLt),
                ],
                if (ps.totalBonuses > 0) ...[
                  const Text(' + ', style: TextStyle(color: _tm)),
                  _MiniPay('Bonuses', _(ps.totalBonuses), _amberLt),
                ],
              ],
            ),
            if (ps.totalAdvanceDeduction > 0) ...[
              const SizedBox(height: 6),
              _Chip2(
                '💳 Advance deducted: ${_(ps.totalAdvanceDeduction)}',
                _red,
              ),
            ],
            if (ps.perfectAttendance) ...[
              const SizedBox(height: 6),
              const _Chip2('🏆 Perfect Attendance', _green),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Rate
      const _SecLbl('💵 Rate & Shifts'),
      const SizedBox(height: 8),
      _card(
        Column(
          children: [
            _R2('Hourly Rate', '${_(ps.hourlyRate)}/hr'),
            _R2('DAY (12h)', _(ps.hourlyRate * 12)),
            _R2('NIGHT (8h)', _(ps.hourlyRate * 8)),
            const Divider(color: _bdr, height: 12),
            _R2(
              'DAY shifts',
              '${ps.dayShiftsWorked}  →  ${_(ps.dayShiftEarnings)}',
            ),
            _R2(
              'NIGHT shifts',
              '${ps.nightShiftsWorked}  →  ${_(ps.nightShiftEarnings)}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Attendance
      const _SecLbl('📊 Attendance'),
      const SizedBox(height: 8),
      _card(
        Column(
          children: [
            _R2('Total Shifts', '${ps.totalShifts}'),
            _R2('✅ Present / Late', '${ps.presentShifts}', vc: _green),
            _R2('🔶 Half Day', '${ps.halfDayShifts}', vc: _amber),
            _R2(
              '✅ Approved Leave (paid)',
              '${ps.approvedLeaveShifts}',
              vc: _teal,
            ),
            _R2(
              '❌ Unapproved Absent',
              '${ps.unapprovedAbsents}',
              vc: ps.unapprovedAbsents > 0 ? _red : _ts,
            ),
            if (ps.excessAbsents > 0)
              _R2('⚠️ Excess (penalised)', '${ps.excessAbsents}', vc: _redLt),
            _R2('⏰ Late Minutes', '${ps.totalLateMinutes}m', vc: _amber),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (ps.earnings.isNotEmpty) ...[
        const _SecLbl('💰 Earnings'),
        const SizedBox(height: 8),
        _LineTable(items: ps.earnings, color: _green),
        const SizedBox(height: 12),
      ],
      if (ps.deductions.isNotEmpty) ...[
        const _SecLbl('❌ Deductions'),
        const SizedBox(height: 8),
        _LineTable(items: ps.deductions, color: _red),
        const SizedBox(height: 12),
      ],
      if (ps.bonuses.isNotEmpty) ...[
        const _SecLbl('🎁 Bonuses'),
        const SizedBox(height: 8),
        _LineTable(items: ps.bonuses, color: _amber),
        const SizedBox(height: 12),
      ],
      _SlipActions(ps: ps, c: c),
      const SizedBox(height: 30),
    ],
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _s2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _bdr),
    ),
    child: child,
  );
}

class _SlipActions extends StatefulWidget {
  final PayrollDoc ps;
  final PayrollController c;
  const _SlipActions({required this.ps, required this.c});
  @override
  State<_SlipActions> createState() => _SlipActionsState();
}

class _SlipActionsState extends State<_SlipActions> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    ever(c.payslip, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext ctx) {
    final live = c.payslip.value ?? widget.ps;
    return Column(
      children: [
        if (live.status == 'draft')
          _GBtn('🔒 Finalise', _amber, false, () => c.finalizePayroll(live.id)),
        if (live.status == 'finalized') ...[
          const SizedBox(height: 8),
          _GBtn('✅ Mark as Paid', _green, false, () => _payDlg(ctx, live.id)),
        ],
        if (live.status == 'paid' && (live.paidAt ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: _green, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Paid${(live.paidBy ?? '').isNotEmpty ? " · by ${live.paidBy}" : ""}',
                  style: const TextStyle(color: _greenLt, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _payDlg(BuildContext ctx, String id) {
    String note = '';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _s2,
        title: const Text(
          'Confirm Payment',
          style: TextStyle(color: _tp, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _green.withOpacity(0.4)),
        ),
        content: TextField(
          style: const TextStyle(color: _tp, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Payment note',
            hintStyle: TextStyle(color: _tm),
            border: UnderlineInputBorder(),
          ),
          onChanged: (v) => note = v,
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: _ts)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              c.markAsPaid(id, note);
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: _green, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineTable extends StatelessWidget {
  final List<PayrollLineItem> items;
  final Color color;
  const _LineTable({required this.items, required this.color});
  @override
  Widget build(BuildContext ctx) => Container(
    decoration: BoxDecoration(
      color: _s2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _bdr),
    ),
    child: Column(
      children: items.asMap().entries.map((e) {
        final last = e.key == items.length - 1;
        final item = e.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: _bdr)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(color: _ts, fontSize: 11),
                ),
              ),
              Text(
                item.amount >= 0
                    ? '+${_(item.amount)}'
                    : '−${_(item.amount.abs())}',
                style: TextStyle(
                  color: item.amount >= 0 ? color : _redLt,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  VIEW 3 — RATES
// ══════════════════════════════════════════════════════════════
class _RatesView extends StatefulWidget {
  final PayrollController c;
  const _RatesView({required this.c});
  @override
  State<_RatesView> createState() => _RatesViewState();
}

class _RatesViewState extends State<_RatesView> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingRates,
      c.ratesError,
      c.employees,
      c.rateSaveMsg,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext ctx) {
    if (c.isLoadingRates.value) return const _Spin();
    if (c.ratesError.value != null) return _Err(c.ratesError.value!);
    return Column(
      children: [
        Container(
          color: _s1,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hourly Rates',
                      style: TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'DAY = rate × 12h  ·  NIGHT = rate × 8h',
                      style: TextStyle(color: _tm, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (c.rateSaveMsg.value != null)
                Text(
                  c.rateSaveMsg.value!,
                  style: TextStyle(
                    color: c.rateSaveMsg.value!.startsWith('✅')
                        ? _greenLt
                        : _redLt,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: c.employees.length,
            itemBuilder: (_, i) => _RateRow(emp: c.employees[i], c: c),
          ),
        ),
      ],
    );
  }
}

class _RateRow extends StatefulWidget {
  final EmployeeRate emp;
  final PayrollController c;
  const _RateRow({required this.emp, required this.c});
  @override
  State<_RateRow> createState() => _RateRowState();
}

class _RateRowState extends State<_RateRow> {
  late TextEditingController _tf;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _tf = TextEditingController(
      text: widget.emp.hourlyRate > 0
          ? widget.emp.hourlyRate.toStringAsFixed(0)
          : '',
    );
    ever(widget.c.isSavingRate, (v) {
      if (mounted) setState(() => _saving = v == widget.emp.id);
    });
  }

  @override
  void didUpdateWidget(_RateRow old) {
    super.didUpdateWidget(old);
    if (old.emp.hourlyRate != widget.emp.hourlyRate)
      _tf.text = widget.emp.hourlyRate > 0
          ? widget.emp.hourlyRate.toStringAsFixed(0)
          : '';
  }

  @override
  void dispose() {
    _tf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final rate = double.tryParse(_tf.text) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _s2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.emp.hourlyRate == 0 ? _amber.withOpacity(0.35) : _bdr,
        ),
      ),
      child: Row(
        children: [
          _Avatar(widget.emp.name, widget.emp.hourlyRate > 0 ? _green : _amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.emp.name,
                  style: const TextStyle(
                    color: _tp,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${widget.emp.department}  ·  ${widget.emp.role}',
                  style: const TextStyle(color: _ts, fontSize: 10),
                ),
                if (widget.emp.hourlyRate > 0)
                  Text(
                    '☀️ ${_(widget.emp.dayShiftPay)}/day  🌙 ${_(widget.emp.nightShiftPay)}/night',
                    style: const TextStyle(color: _tm, fontSize: 9),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              controller: _tf,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: _tp,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                prefixText: '₹',
                prefixStyle: const TextStyle(color: _ts, fontSize: 12),
                hintText: '0',
                hintStyle: const TextStyle(color: _tm),
                filled: true,
                fillColor: _s3,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: _bdr),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: _bdr),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: _blue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _saving || rate <= 0
                ? null
                : () => widget.c.saveEmployeeRate(widget.emp.id, rate),
            child: Container(
              width: 44,
              height: 40,
              decoration: BoxDecoration(
                color: _saving || rate <= 0 ? _s3 : _green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: _saving || rate <= 0 ? _bdr : _green.withOpacity(0.4),
                ),
              ),
              child: _saving
                  ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: _green,
                    strokeWidth: 2,
                  ),
                ),
              )
                  : const Icon(Icons.check_rounded, color: _green, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 4 — SETTINGS
// ══════════════════════════════════════════════════════════════
class _SettingsView extends StatefulWidget {
  final PayrollController c;
  const _SettingsView({required this.c});
  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingSettings,
      c.isSavingSettings,
      c.settingsSaveOk,
      c.settingsError,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext ctx) {
    if (c.isLoadingSettings.value) return const _Spin();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _s2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _amber.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⏱ Shift Hours',
                  style: TextStyle(
                    color: _amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InfoBox('☀️ DAY', '12 hours', _amber)),
                    const SizedBox(width: 8),
                    Expanded(child: _InfoBox('🌙 NIGHT', '8 hours', _purple)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Pay = hourly rate × shift hours",
                  style: TextStyle(color: _tm, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SecLbl('🏖 Leave Quota'),
          const SizedBox(height: 4),
          const Text(
            'Within quota: shift pay lost only.  Beyond quota: extra penalty added.',
            style: TextStyle(color: _tm, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Field('Casual Leaves', c.tfCasualLeaves, hint: '2'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _Field('Sick Leaves', c.tfSickLeaves, hint: '1')),
            ],
          ),
          const SizedBox(height: 14),
          const _SecLbl('⚠️ Penalty'),
          const SizedBox(height: 8),
          _Field(
            'Penalty per Excess Absent (₹)',
            c.tfPenaltyPerExcess,
            hint: '200',
          ),
          const SizedBox(height: 8),
          _Field(
            'Late Grace Period (mins)',
            c.tfGraceMins,
            hint: '10',
            sub: 'Late below this = no deduction',
          ),
          const SizedBox(height: 14),
          const _SecLbl('🏆 Bonuses'),
          const SizedBox(height: 8),
          _Field(
            'No-Leave Bonus (₹)',
            c.tfNoLeaveBonus,
            hint: '300',
            sub: 'Zero leaves all month',
          ),
          const SizedBox(height: 8),
          _Field(
            'Perfect Attendance Bonus (₹)',
            c.tfPerfectBonus,
            hint: '500',
            sub: 'Zero unapproved absents',
          ),
          const SizedBox(height: 8),
          _Field('Streak Bonus / 7 Days (₹)', c.tfStreakBonus, hint: '100'),
          const SizedBox(height: 18),
          _GBtn(
            c.isSavingSettings.value ? 'Saving…' : '💾 Save Settings',
            _green,
            c.isSavingSettings.value,
            c.saveSettings,
          ),
          if (c.settingsSaveOk.value)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '✅ Settings saved',
                style: TextStyle(color: _greenLt, fontSize: 12),
              ),
            ),
          if (c.settingsError.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ ${c.settingsError.value}',
                style: const TextStyle(color: _redLt, fontSize: 12),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 5 — LEAVE
// ══════════════════════════════════════════════════════════════
class _LeaveView extends StatelessWidget {
  final PayrollController c;
  const _LeaveView({required this.c});
  @override
  Widget build(BuildContext ctx) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        Container(
          color: _s1,
          child: const TabBar(
            indicatorColor: _blue,
            labelColor: _blueLt,
            unselectedLabelColor: _ts,
            tabs: [
              Tab(text: 'Pending Approvals'),
              Tab(text: 'Apply Leave'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _LeaveList(c: c),
              _LeaveForm(c: c),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LeaveList extends StatefulWidget {
  final PayrollController c;
  const _LeaveList({required this.c});
  @override
  State<_LeaveList> createState() => _LeaveListState();
}

class _LeaveListState extends State<_LeaveList> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingLeave,
      c.leaveError,
      c.leaveRequests,
      c.leaveFilter,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext ctx) => Column(
    children: [
      Container(
        color: _s1,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            _fchip('Pending', 'pending'),
            const SizedBox(width: 6),
            _fchip('Approved', 'approved'),
            const SizedBox(width: 6),
            _fchip('Rejected', 'rejected'),
            const SizedBox(width: 6),
            _fchip('All', 'all'),
          ],
        ),
      ),
      Expanded(child: _body()),
    ],
  );
  Widget _fchip(String label, String val) {
    final on = c.leaveFilter.value == val;
    return GestureDetector(
      onTap: () {
        c.leaveFilter.value = val;
        c.fetchLeaveRequests();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? _blue.withOpacity(0.15) : _s2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: on ? _blue.withOpacity(0.5) : _bdr),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? _blueLt : _ts,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (c.isLoadingLeave.value) return const _Spin();
    if (c.leaveError.value != null) return _Err(c.leaveError.value!);
    if (c.leaveRequests.isEmpty)
      return const _Hint('No leave requests for this period');
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: c.leaveRequests.length,
      itemBuilder: (_, i) => _LeaveCard(req: c.leaveRequests[i], c: c),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequest req;
  final PayrollController c;
  const _LeaveCard({required this.req, required this.c});
  Color get _bc => req.status == LeaveRequestStatus.approved
      ? _green
      : req.status == LeaveRequestStatus.rejected
      ? _red
      : _amber;
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _s2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _bc.withOpacity(0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    req.name,
                    style: const TextStyle(
                      color: _tp,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    req.department,
                    style: const TextStyle(color: _ts, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (req.status == LeaveRequestStatus.approved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    color: _tealLt,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            _Chip2(
              req.status == LeaveRequestStatus.approved
                  ? '✅ Approved'
                  : req.status == LeaveRequestStatus.rejected
                  ? '❌ Rejected'
                  : '⏳ Pending',
              _bc,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _Tag(
              '📅 ${req.startDate.length >= 10 ? req.startDate.substring(5, 10) : req.startDate} → ${req.endDate.length >= 10 ? req.endDate.substring(5, 10) : req.endDate}',
            ),
            _Tag('⏱ ${req.shift}'),
            _Tag('${req.leaveType.toUpperCase()} · ${req.totalDays}d'),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _s3,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            req.reason,
            style: const TextStyle(color: _ts, fontSize: 11),
          ),
        ),
        if (req.status == LeaveRequestStatus.approved)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '✅ Full shift pay credited — no deduction',
              style: TextStyle(color: _tealLt, fontSize: 10),
            ),
          ),
        if (req.status == LeaveRequestStatus.pending) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmBtn(
                  '✅ Approve',
                  _green,
                      () => c.approveLeave(req.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmBtn('❌ Reject', _red, () => _rejDlg(ctx, req.id)),
              ),
            ],
          ),
        ],
      ],
    ),
  );
  void _rejDlg(BuildContext ctx, String id) {
    String rem = '';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _s2,
        title: const Text(
          'Reject Leave',
          style: TextStyle(color: _tp, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _red.withOpacity(0.4)),
        ),
        content: TextField(
          style: const TextStyle(color: _tp, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: _tm),
            border: UnderlineInputBorder(),
          ),
          onChanged: (v) => rem = v,
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: _ts)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              c.rejectLeave(id, rem);
            },
            child: const Text(
              'Reject',
              style: TextStyle(color: _red, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveForm extends StatefulWidget {
  final PayrollController c;
  const _LeaveForm({required this.c});
  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  PayrollController get c => widget.c;
  final _tfEmpId = TextEditingController();
  EmployeeRate? _selectedEmp;
  @override
  void initState() {
    ever(c.employees, (_) {
      if (mounted) setState(() {});
    });
    super.initState();
    for (final rx in <RxInterface>[
      c.leaveShift,
      c.leaveType,
      c.leaveStartDate,
      c.leaveSubmitting,
      c.leaveEndDate,
      c.leaveSubmitOk,
      c.leaveSubmitErr,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tfEmpId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      const Text(
        'Apply for Leave',
        style: TextStyle(color: _tp, fontSize: 14, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Approved leave = full shift pay credited, no deductions.',
        style: TextStyle(color: _tealLt, fontSize: 10),
      ),
      const SizedBox(height: 14),
      // Employee ID (admin enters on behalf)
      const _FLbl('Employee'),
      const SizedBox(height: 5),
      _EmpDropdown(
        employees: c.employees,
        selected: _selectedEmp,
        onChanged: (emp) {
          setState(() => _selectedEmp = emp);
          c.openLeaveFormFor(emp!.id);
        },
      ),
      const SizedBox(height: 12),
      const _FLbl('Shift'),
      const SizedBox(height: 5),
      Row(
        children: ['DAY', 'NIGHT', 'BOTH'].map((s) {
          final on = c.leaveShift.value == s;
          return GestureDetector(
            onTap: () {
              c.leaveShift.value = s;
              c.openLeaveFormFor(
                _tfEmpId.text.trim().isEmpty ? '' : _tfEmpId.text.trim(),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: on ? _purple.withOpacity(0.15) : _s2,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: on ? _purple.withOpacity(0.5) : _bdr),
              ),
              child: Text(
                s,
                style: TextStyle(
                  color: on ? _purpLt : _ts,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      const _FLbl('Leave Type'),
      const SizedBox(height: 5),
      Row(
        children: [
          _typeBtn('Casual', 'casual', _amber),
          const SizedBox(width: 8),
          _typeBtn('Sick', 'sick', _red),
          const SizedBox(width: 8),
          _typeBtn('Unpaid', 'unpaid', _ts),
        ],
      ),
      const SizedBox(height: 12),
      const _FLbl('Date Range'),
      const SizedBox(height: 5),
      Row(
        children: [
          Expanded(
            child: _datePick(ctx, 'From', c.leaveStartDate.value, (d) {
              c.leaveStartDate.value = d;
              if (d.isAfter(c.leaveEndDate.value)) c.leaveEndDate.value = d;
            }),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward, color: _tm, size: 14),
          ),
          Expanded(
            child: _datePick(
              ctx,
              'To',
              c.leaveEndDate.value,
                  (d) => c.leaveEndDate.value = d,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const _FLbl('Reason'),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: _s2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr),
        ),
        child: TextField(
          maxLines: 3,
          style: const TextStyle(color: _tp, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Reason for leave…',
            hintStyle: TextStyle(color: _tm, fontSize: 11),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(12),
          ),
          onChanged: (v) => c.leaveReason.value = v,
        ),
      ),
      const SizedBox(height: 12),
      _GBtn(
        c.leaveSubmitting.value ? 'Submitting…' : '📤 Submit Request',
        _purple,
        c.leaveSubmitting.value,
            () {
          if (_selectedEmp == null) {
            c.leaveSubmitErr.value = 'Please select an employee';
            return;
          }
          c.openLeaveFormFor(_selectedEmp!.id);
          c.submitLeaveRequest();
        },
      ),
      if (c.leaveSubmitOk.value)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '✅ Request submitted — awaiting admin approval',
            style: TextStyle(color: _greenLt, fontSize: 11),
          ),
        ),
      if (c.leaveSubmitErr.value != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '⚠️ ${c.leaveSubmitErr.value}',
            style: const TextStyle(color: _redLt, fontSize: 11),
          ),
        ),
      const SizedBox(height: 30),
    ],
  );
  Widget _typeBtn(String label, String val, Color color) {
    final on = c.leaveType.value == val;
    return GestureDetector(
      onTap: () => c.leaveType.value = val,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color.withOpacity(0.15) : _s2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: on ? color.withOpacity(0.5) : _bdr),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? color : _ts,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _datePick(
      BuildContext ctx,
      String label,
      DateTime date,
      void Function(DateTime) onPick,
      ) => GestureDetector(
    onTap: () async {
      final d = await showDatePicker(
        context: ctx,
        initialDate: date,
        firstDate: DateTime(2023),
        lastDate: DateTime.now().add(const Duration(days: 60)),
        builder: (c, child) => Theme(
          data: Theme.of(c).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _purple,
              surface: _s2,
              onSurface: _tp,
            ),
          ),
          child: child!,
        ),
      );
      if (d != null) onPick(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _s2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 12, color: _tm),
          const SizedBox(width: 6),
          Text(
            '$label: ${date.day}/${date.month}/${date.year}',
            style: const TextStyle(
              color: _tp,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  VIEW 6 — ANALYTICS
// ══════════════════════════════════════════════════════════════
class _AnalyticsView extends StatefulWidget {
  final PayrollController c;
  const _AnalyticsView({required this.c});
  @override
  State<_AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<_AnalyticsView> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingAna,
      c.anaError,
      c.analytics,
      c.anaSummary,
      c.anaYear,
      c.anaMonth,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext ctx) => Column(
    children: [
      _AnaHeader(c: c),
      Expanded(child: _body()),
    ],
  );
  Widget _body() {
    if (c.isLoadingAna.value) return const _Spin();
    if (c.anaError.value != null) return _Err(c.anaError.value!);
    if (c.analytics.isEmpty)
      return const _Hint('No payroll data for this period');
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _AnaSummaryBar(c: c),
        const SizedBox(height: 14),
        ..._yearlyBonusSection(context),
        const _SecLbl('🏅 Attendance Leaderboard'),
        const SizedBox(height: 8),
        ...c.analytics.map((e) => _AnaCard(emp: e)),
        const SizedBox(height: 30),
      ],
    );
  }

  List<Widget> _yearlyBonusSection(BuildContext ctx) {
    if (c.anaMonth.value != 0) return [];
    return [
      Row(
        children: [
          const Expanded(child: _SecLbl('🎁 Yearly Bonus (10% of annual pay)')),
          GestureDetector(
            onTap: c.isComputingYB.value ? null : c.computeYearlyBonuses,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _gold.withOpacity(0.4)),
              ),
              child: Text(
                c.isComputingYB.value ? 'Computing…' : '⚡ Compute',
                style: const TextStyle(
                  color: _goldLt,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (c.isLoadingYB.value)
        const _Spin()
      else if (c.yearlyBonuses.isEmpty)
        const Text(
          'No yearly bonuses computed yet.',
          style: TextStyle(color: _tm, fontSize: 11),
        )
      else
        ...c.yearlyBonuses.map((yb) => _YBCard(yb: yb, c: c)),
      const SizedBox(height: 14),
    ];
  }
}

class _AnaHeader extends StatelessWidget {
  final PayrollController c;
  const _AnaHeader({required this.c});
  @override
  Widget build(BuildContext ctx) => Container(
    color: _s1,
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Year', style: TextStyle(color: _ts, fontSize: 11)),
            const SizedBox(width: 8),
            _IBtn(Icons.chevron_left_rounded, 16, () {
              c.anaYear.value--;
              c.fetchAnalytics();
              c.fetchYearlyBonuses();
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '${c.anaYear.value}',
                style: const TextStyle(
                  color: _tp,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _IBtn(Icons.chevron_right_rounded, 16, () {
              c.anaYear.value++;
              c.fetchAnalytics();
              c.fetchYearlyBonuses();
            }),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
            [
              _mchip(c, 0, 'All Year'),
              ...List.generate(
                12,
                    (i) => _mchip(c, i + 1, kMonths[i + 1].substring(0, 3)),
              ),
            ].expand((w) => [w, const SizedBox(width: 6)]).toList()
              ..removeLast(),
          ),
        ),
      ],
    ),
  );
  Widget _mchip(PayrollController c, int m, String label) {
    final on = c.anaMonth.value == m;
    return GestureDetector(
      onTap: () {
        c.anaMonth.value = m;
        c.fetchAnalytics();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: on ? _teal.withOpacity(0.15) : _s2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: on ? _teal.withOpacity(0.5) : _bdr),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? _tealLt : _ts,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AnaSummaryBar extends StatelessWidget {
  final PayrollController c;
  const _AnaSummaryBar({required this.c});
  @override
  Widget build(BuildContext ctx) {
    final s = c.anaSummary.value;
    if (s == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(child: _Kpi2('${s.totalEmployees}', 'Employees', _blueLt)),
        const SizedBox(width: 6),
        Expanded(child: _Kpi2(_k(s.totalPayout), 'Total Payout', _green)),
        const SizedBox(width: 6),
        Expanded(
          child: _Kpi2('${s.avgAttendanceRate}%', 'Avg Attendance', _teal),
        ),
      ],
    );
  }
}

class _AnaCard extends StatelessWidget {
  final AnalyticsEmployee emp;
  const _AnaCard({required this.emp});
  @override
  Widget build(BuildContext ctx) {
    final rankColor = emp.rank == 1
        ? _gold
        : emp.rank == 2
        ? _ts
        : emp.rank == 3
        ? _amber
        : _tm;
    final attColor = emp.attendanceRate >= 90
        ? _green
        : emp.attendanceRate >= 70
        ? _amber
        : _red;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _s2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emp.rank == 1 ? _gold.withOpacity(0.4) : _bdr,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: rankColor.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    '#${emp.rank}',
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Avatar(emp.name, attColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: const TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      emp.department,
                      style: const TextStyle(color: _ts, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${emp.attendanceRate}%',
                    style: TextStyle(
                      color: attColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'attendance',
                    style: TextStyle(color: _tm, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: emp.attendanceRate / 100,
              backgroundColor: _s3,
              valueColor: AlwaysStoppedAnimation(attColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children:
            [
              _Stat('✅ Present', '${emp.presentShifts}', _green),
              _Stat('✅ Approved', '${emp.approvedLeaveShifts}', _teal),
              _Stat('❌ Absent', '${emp.absentShifts}', _red),
              _Stat('🏆 Perfect Mo.', '${emp.perfectMonths}', _gold),
              _Stat('🔥 Streak', '${emp.longestStreak}d', _amber),
            ].expand((w) => [w, const SizedBox(width: 4)]).toList()
              ..removeLast(),
          ),
          const SizedBox(height: 8),
          Row(
            children:
            [
              _Stat('💰 Net Pay', _k(emp.totalNetPay), _green),
              _Stat('🎁 Bonuses', _k(emp.totalBonuses), _amber),
              _Stat('⏰ Late Mins', '${emp.totalLateMinutes}m', _purple),
            ].expand((w) => [w, const SizedBox(width: 4)]).toList()
              ..removeLast(),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext ctx) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: _tm, fontSize: 7),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _YBCard extends StatelessWidget {
  final YearlyBonus yb;
  final PayrollController c;
  const _YBCard({required this.yb, required this.c});
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _s2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: yb.status == 'paid'
            ? _green.withOpacity(0.35)
            : _gold.withOpacity(0.3),
      ),
    ),
    child: Row(
      children: [
        _Avatar(yb.employeeName, _gold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                yb.employeeName,
                style: const TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${yb.monthsCounted} months  ·  Annual: ${_k(yb.totalAnnualPay)}',
                style: const TextStyle(color: _ts, fontSize: 10),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _(yb.bonusAmount),
              style: const TextStyle(
                color: _goldLt,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text('10% bonus', style: TextStyle(color: _tm, fontSize: 9)),
          ],
        ),
        const SizedBox(width: 8),
        if (yb.status != 'paid')
          GestureDetector(
            onTap: () => _payDlg(ctx, yb.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _green.withOpacity(0.4)),
              ),
              child: const Text(
                'Pay',
                style: TextStyle(
                  color: _greenLt,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
        else
          const Icon(Icons.check_circle_rounded, color: _green, size: 18),
      ],
    ),
  );
  void _payDlg(BuildContext ctx, String id) {
    String note = '';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _s2,
        title: const Text(
          'Pay Yearly Bonus',
          style: TextStyle(color: _tp, fontSize: 14),
        ),
        content: TextField(
          style: const TextStyle(color: _tp, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Payment note',
            hintStyle: TextStyle(color: _tm),
            border: UnderlineInputBorder(),
          ),
          onChanged: (v) => note = v,
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: _ts)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              c.payYearlyBonus(id, note);
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: _green, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 7 — ADVANCE SALARY
// ══════════════════════════════════════════════════════════════
class _AdvanceView extends StatelessWidget {
  final PayrollController c;
  const _AdvanceView({required this.c});
  @override
  Widget build(BuildContext ctx) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        Container(
          color: _s1,
          child: const TabBar(
            indicatorColor: _blue,
            labelColor: _blueLt,
            unselectedLabelColor: _ts,
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Request Advance'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _AdvList(c: c),
              _AdvForm(c: c),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdvList extends StatefulWidget {
  final PayrollController c;
  const _AdvList({required this.c});
  @override
  State<_AdvList> createState() => _AdvListState();
}

class _AdvListState extends State<_AdvList> {
  PayrollController get c => widget.c;
  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingAdv,
      c.advError,
      c.advances,
      c.advFilter,
      c.advApproving,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext ctx) => Column(
    children: [
      Container(
        color: _s1,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            _fchip('Pending', 'pending'),
            const SizedBox(width: 6),
            _fchip('Approved', 'approved'),
            const SizedBox(width: 6),
            _fchip('Rejected', 'rejected'),
            const SizedBox(width: 6),
            _fchip('All', 'all'),
          ],
        ),
      ),
      Expanded(child: _body()),
    ],
  );
  Widget _fchip(String label, String val) {
    final on = c.advFilter.value == val;
    return GestureDetector(
      onTap: () {
        c.advFilter.value = val;
        c.fetchAdvances();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? _blue.withOpacity(0.15) : _s2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: on ? _blue.withOpacity(0.5) : _bdr),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? _blueLt : _ts,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (c.isLoadingAdv.value) return const _Spin();
    if (c.advError.value != null) return _Err(c.advError.value!);
    if (c.advances.isEmpty) return const _Hint('No advance requests');
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: c.advances.length,
      itemBuilder: (_, i) => _AdvCard(
        adv: c.advances[i],
        c: c,
        isApproving: c.advApproving.value == c.advances[i].id,
      ),
    );
  }
}

class _AdvCard extends StatelessWidget {
  final AdvanceRequest adv;
  final PayrollController c;
  final bool isApproving;
  const _AdvCard({
    required this.adv,
    required this.c,
    required this.isApproving,
  });
  Color get _bc => adv.status == AdvanceStatus.approved
      ? _green
      : adv.status == AdvanceStatus.rejected
      ? _red
      : _amber;
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _s2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _bc.withOpacity(0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adv.employeeName,
                    style: const TextStyle(
                      color: _tp,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    adv.department,
                    style: const TextStyle(color: _ts, fontSize: 10),
                  ),
                ],
              ),
            ),
            Text(
              _(adv.amount),
              style: const TextStyle(
                color: _tp,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            _Chip2(
              adv.status == AdvanceStatus.approved
                  ? '✅ Approved'
                  : adv.status == AdvanceStatus.rejected
                  ? '❌ Rejected'
                  : '⏳ Pending',
              _bc,
            ),
          ],
        ),
        if (adv.reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _s3,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              adv.reason,
              style: const TextStyle(color: _ts, fontSize: 11),
            ),
          ),
        ],
        if (adv.status == AdvanceStatus.approved) ...[
          const SizedBox(height: 6),
          Text(
            'Deduct: ${kMonths[adv.deductMonth ?? 1]} ${adv.deductYear}  ${adv.deductedInPayroll ? "✅ Already deducted" : "⏳ Pending deduction"}',
            style: TextStyle(
              color: adv.deductedInPayroll ? _greenLt : _amberLt,
              fontSize: 10,
            ),
          ),
        ],
        if (adv.adminNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Admin: ${adv.adminNotes}',
              style: const TextStyle(
                color: _tm,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (adv.status == AdvanceStatus.pending) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmBtn(
                  isApproving ? '…' : '✅ Approve',
                  _green,
                      () => _approveDlg(ctx, adv.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmBtn('❌ Reject', _red, () => _rejectDlg(ctx, adv.id)),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  void _approveDlg(BuildContext ctx, String id) {
    int month = DateTime.now().month, year = DateTime.now().year;
    String notes = '';
    final mCtrl = TextEditingController(text: '$month');
    final yCtrl = TextEditingController(text: '$year');
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _s2,
        title: const Text(
          'Approve Advance',
          style: TextStyle(color: _tp, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _green.withOpacity(0.4)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Deduct from which month?',
              style: TextStyle(color: _ts, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: mCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: _tp, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Month (1-12)',
                      labelStyle: TextStyle(color: _ts, fontSize: 11),
                      border: UnderlineInputBorder(),
                    ),
                    onChanged: (v) => month = int.tryParse(v) ?? month,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: yCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: _tp, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      labelStyle: TextStyle(color: _ts, fontSize: 11),
                      border: UnderlineInputBorder(),
                    ),
                    onChanged: (v) => year = int.tryParse(v) ?? year,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: _tp, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Admin notes (optional)',
                hintStyle: TextStyle(color: _tm),
                border: UnderlineInputBorder(),
              ),
              onChanged: (v) => notes = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: _ts)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              c.approveAdvance(id, month, year, notes);
            },
            child: const Text(
              'Approve',
              style: TextStyle(color: _green, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _rejectDlg(BuildContext ctx, String id) {
    String notes = '';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _s2,
        title: const Text(
          'Reject Advance',
          style: TextStyle(color: _tp, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _red.withOpacity(0.4)),
        ),
        content: TextField(
          style: const TextStyle(color: _tp, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Reason',
            hintStyle: TextStyle(color: _tm),
            border: UnderlineInputBorder(),
          ),
          onChanged: (v) => notes = v,
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: _ts)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              c.rejectAdvance(id, notes);
            },
            child: const Text(
              'Reject',
              style: TextStyle(color: _red, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvForm extends StatefulWidget {
  final PayrollController c;
  const _AdvForm({required this.c});
  @override
  State<_AdvForm> createState() => _AdvFormState();
}

class _AdvFormState extends State<_AdvForm> {
  EmployeeRate? _selectedEmp;
  PayrollController get c => widget.c;

  final _tfAmount = TextEditingController();
  @override
  void initState() {
    ever(c.employees, (_) {
      if (mounted) setState(() {});
    });
    super.initState();
    for (final rx in <RxInterface>[
      c.advSubmitting,
      c.advSubmitOk,
      c.advSubmitErr,
    ]) {
      ever(rx, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tfAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      const Text(
        'Request Advance Salary',
        style: TextStyle(color: _tp, fontSize: 14, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Approved advance will be deducted from the specified month\'s payout.',
        style: TextStyle(color: _tm, fontSize: 11),
      ),
      const SizedBox(height: 16),
      const _FLbl('Employee'),
      const SizedBox(height: 5),
      _EmpDropdown(
        employees: c.employees,
        selected: _selectedEmp,
        onChanged: (emp) {
          setState(() => _selectedEmp = emp);
          c.openAdvanceFormFor(emp!.id);
        },
      ),
      const SizedBox(height: 12),
      _Field(
        'Amount (₹)',
        _tfAmount,
        hint: '5000',
        sub: 'How much advance is needed',
      ),
      const SizedBox(height: 12),
      const _FLbl('Reason'),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: _s2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr),
        ),
        child: TextField(
          maxLines: 3,
          style: const TextStyle(color: _tp, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Why is the advance needed?',
            hintStyle: TextStyle(color: _tm, fontSize: 11),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(12),
          ),
          onChanged: (v) => c.advReason.value = v,
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _amber.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _amber.withOpacity(0.25)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💳 How it works',
              style: TextStyle(
                color: _amberLt,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '1. Employee submits request',
              style: TextStyle(color: _ts, fontSize: 10),
            ),
            Text(
              '2. Admin approves + selects deduction month',
              style: TextStyle(color: _ts, fontSize: 10),
            ),
            Text(
              '3. Advance amount is deducted from that month\'s payroll',
              style: TextStyle(color: _ts, fontSize: 10),
            ),
            Text(
              '4. Shows as "Advance Salary Recovery" in payslip line items',
              style: TextStyle(color: _ts, fontSize: 10),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _GBtn(
        c.advSubmitting.value ? 'Submitting…' : '📤 Submit Request',
        _purple,
        c.advSubmitting.value,
            () {
          if (_selectedEmp == null) {
            c.advSubmitErr.value = 'Please select an employee';
            return;
          }
          c.openAdvanceFormFor(_selectedEmp!.id);
          final amount = double.tryParse(_tfAmount.text.trim()) ?? 0;
          c.submitAdvanceRequest(amount);
        },
      ),
      if (c.advSubmitOk.value)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '✅ Request submitted — awaiting admin approval',
            style: TextStyle(color: _greenLt, fontSize: 11),
          ),
        ),
      if (c.advSubmitErr.value != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '⚠️ ${c.advSubmitErr.value}',
            style: const TextStyle(color: _redLt, fontSize: 11),
          ),
        ),
      const SizedBox(height: 30),
    ],
  );
}

class _EmpDropdown extends StatelessWidget {
  final List<EmployeeRate> employees;
  final EmployeeRate? selected;
  final void Function(EmployeeRate?) onChanged;
  const _EmpDropdown({
    required this.employees,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _s2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr),
        ),
        child: const Text(
          'No employees — open Rates tab first',
          style: TextStyle(color: _tm, fontSize: 11),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _s2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected != null ? _blue.withOpacity(0.5) : _bdr,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EmployeeRate>(
          value: selected,
          isExpanded: true,
          dropdownColor: _s2,
          iconEnabledColor: _ts,
          hint: const Text(
            'Select employee…',
            style: TextStyle(color: _tm, fontSize: 12),
          ),
          // Full row shown in the dropdown list
          items: employees
              .map(
                (emp) => DropdownMenuItem<EmployeeRate>(
              value: emp,
              child: Row(
                children: [
                  _Avatar(emp.name, emp.hourlyRate > 0 ? _green : _amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emp.name,
                          style: const TextStyle(
                            color: _tp,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          emp.department,
                          style: const TextStyle(color: _ts, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (emp.hourlyRate > 0)
                    Text(
                      '₹${emp.hourlyRate.toStringAsFixed(0)}/hr',
                      style: const TextStyle(color: _tm, fontSize: 10),
                    ),
                ],
              ),
            ),
          )
              .toList(),
          // Compact text shown after selection (no overflow)
          selectedItemBuilder: (_) => employees
              .map(
                (emp) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${emp.name}  ·  ${emp.department}',
                style: const TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHARED ATOMS
// ══════════════════════════════════════════════════════════════
class _IBtn extends StatelessWidget {
  final IconData icon;
  final double sz;
  final VoidCallback cb;
  const _IBtn(this.icon, this.sz, this.cb);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: cb,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _s2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Icon(icon, size: sz, color: _ts),
    ),
  );
}

class _GBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _GBtn(this.label, this.color, this.loading, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: loading ? _s3 : color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: loading ? _bdr : color.withOpacity(0.45)),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(color: _ts, strokeWidth: 2),
        )
            : Text(
          label,
          style: TextStyle(
            color: loading ? _ts : color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _SmBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _Kpi extends StatelessWidget {
  final String val, lbl;
  final Color c;
  const _Kpi(this.val, this.lbl, this.c);
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Text(lbl, style: const TextStyle(color: _ts, fontSize: 11)),
      ],
    ),
  );
}

class _Kpi2 extends StatelessWidget {
  final String val, lbl;
  final Color c;
  const _Kpi2(this.val, this.lbl, this.c);
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _s2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _bdr),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w900),
        ),
        Text(lbl, style: const TextStyle(color: _tm, fontSize: 9)),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color c;
  const _Avatar(this.name, this.c);
  @override
  Widget build(BuildContext ctx) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.withOpacity(0.12),
      border: Border.all(color: c.withOpacity(0.4)),
    ),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);
  @override
  Widget build(BuildContext ctx) {
    final c = status == 'paid'
        ? _green
        : status == 'finalized'
        ? _amber
        : _ts;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Chip2 extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip2(this.label, this.color);
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _s3,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: const TextStyle(color: _ts, fontSize: 10)),
  );
}

class _InfoBox extends StatelessWidget {
  final String title, sub;
  final Color c;
  const _InfoBox(this.title, this.sub, this.c);
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: c.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800),
        ),
        Text(sub, style: const TextStyle(color: _ts, fontSize: 10)),
      ],
    ),
  );
}

class _MiniPay extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniPay(this.label, this.value, this.color);
  @override
  Widget build(BuildContext ctx) => Column(
    children: [
      Text(label, style: const TextStyle(color: _tm, fontSize: 9)),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _LegDot extends StatelessWidget {
  final Color c;
  final String label;
  const _LegDot(this.c, this.label);
  @override
  Widget build(BuildContext ctx) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: _ts, fontSize: 10)),
    ],
  );
}

class _R2 extends StatelessWidget {
  final String k, v;
  final Color? vc;
  const _R2(this.k, this.v, {this.vc});
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(color: _ts, fontSize: 11)),
        ),
        Text(
          v,
          style: TextStyle(
            color: vc ?? _tp,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SecLbl extends StatelessWidget {
  final String text;
  const _SecLbl(this.text);
  @override
  Widget build(BuildContext ctx) => Text(
    text,
    style: const TextStyle(
      color: _ts,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
  );
}

class _FLbl extends StatelessWidget {
  final String text;
  const _FLbl(this.text);
  @override
  Widget build(BuildContext ctx) => Text(
    text,
    style: const TextStyle(
      color: _ts,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint, sub;
  const _Field(this.label, this.ctrl, {this.hint = '', this.sub = ''});
  @override
  Widget build(BuildContext ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _ts,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (sub.isNotEmpty)
        Text(sub, style: const TextStyle(color: _tm, fontSize: 9)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        style: const TextStyle(color: _tp, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _tm, fontSize: 11),
          filled: true,
          fillColor: _s3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _bdr),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _bdr),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    ],
  );
}

class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext ctx) => const Center(
    child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
  );
}

class _Err extends StatelessWidget {
  final String msg;
  const _Err(this.msg);
  @override
  Widget build(BuildContext ctx) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        msg,
        style: const TextStyle(color: _redLt, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  final String msg;
  const _Hint(this.msg);
  @override
  Widget build(BuildContext ctx) => Center(
    child: Text(msg, style: const TextStyle(color: _tm, fontSize: 12)),
  );
}