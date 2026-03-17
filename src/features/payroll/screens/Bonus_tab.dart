// lib/src/features/payroll/screens/bonus_tab.dart
//
// Full Bonus tab — three inner tabs:
//   1. Overview  — config panel + trigger + summary cards
//   2. Records   — per-employee bonus records with pay button
//   3. Rates     — set per-employee bonus %
//
// Wire into payroll_page.dart:
//   a) Add:  case PayrollView.bonus: body = BonusTab(c: c); break;
//   b) Add:  _tab(c, '🎁', 'Bonus', PayrollView.bonus)  in _Tabs
//   c) Add:  PayrollView.bonus  to the PayrollView enum
//   d) Add:  case PayrollView.bonus: c.bonus.fetchConfig(); ... in refresh handler
//
// This widget self-manages a BonusController via GetX.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/bonus_controller.dart';

// ── Palette (matches payroll_page.dart) ────────────────────────
const _bg     = Color(0xFF060D18);
const _s1     = Color(0xFF0B1626);
const _s2     = Color(0xFF0F1F33);
const _s3     = Color(0xFF162540);
const _bdr    = Color(0xFF1A2E4A);
const _blue   = Color(0xFF2563EB);
const _blueLt = Color(0xFF60A5FA);
const _green  = Color(0xFF10B981);
const _greenLt= Color(0xFF34D399);
const _amber  = Color(0xFFF59E0B);
const _amberLt= Color(0xFFFBBF24);
const _red    = Color(0xFFEF4444);
const _redLt  = Color(0xFFFCA5A5);
const _purple = Color(0xFF8B5CF6);
const _purpLt = Color(0xFFC4B5FD);
const _tp     = Color(0xFFF0F6FF);
const _ts     = Color(0xFF8BA4C2);
const _tm     = Color(0xFF3D5470);

// Tier colours
const _tierS = Color(0xFF10B981); // green
const _tierA = Color(0xFF2563EB); // blue
const _tierB = Color(0xFFF59E0B); // amber
const _tierC = Color(0xFFEF4444); // red

Color _tierColor(String tier) {
  switch (tier) {
    case 'S': return _tierS;
    case 'A': return _tierA;
    case 'B': return _tierB;
    default:  return _tierC;
  }
}

String _tierLabel(String tier) {
  switch (tier) {
    case 'S': return 'S ≥90%';
    case 'A': return 'A ≥75%';
    case 'B': return 'B ≥60%';
    default:  return 'C <60%';
  }
}

// ══════════════════════════════════════════════════════════════
//  ROOT WIDGET
// ══════════════════════════════════════════════════════════════
class BonusTab extends StatefulWidget {
  const BonusTab({super.key});
  @override State<BonusTab> createState() => _BonusTabState();
}

class _BonusTabState extends State<BonusTab> {
  late final BonusController c;

  @override
  void initState() {
    super.initState();
    Get.delete<BonusController>(force: true);
    c = Get.put(BonusController());
  }

  @override
  void dispose() {
    Get.delete<BonusController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(children: [
      Container(
        color: _s1,
        child: const TabBar(
          indicatorColor: _amber,
          labelColor: _amberLt,
          unselectedLabelColor: _ts,
          labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: '📊 Overview'),
            Tab(text: '🧾 Records'),
            Tab(text: '⚙️ Rates'),
          ],
        ),
      ),
      Expanded(child: TabBarView(children: [
        _OverviewTab(c: c),
        _RecordsTab(c: c),
        _RatesTab(c: c),
      ])),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  TAB 1 — OVERVIEW
// ══════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final BonusController c;
  const _OverviewTab({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoadingCfg.value) return const _Spin();
    if (c.cfgError.value != null) return _Err(c.cfgError.value!);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Year picker ─────────────────────────────────
        _YearPicker(c: c),
        const SizedBox(height: 14),

        // ── Summary cards ────────────────────────────────
        if (c.summary.value != null) ...[
          _SumCards(c: c),
          const SizedBox(height: 14),
        ],

        // ── Status banner ────────────────────────────────
        _StatusBanner(c: c),
        const SizedBox(height: 14),

        // ── Config panel ─────────────────────────────────
        _ConfigPanel(c: c),
        const SizedBox(height: 14),

        // ── Attendance tiers legend ───────────────────────
        _TiersLegend(),
        const SizedBox(height: 14),

        // ── Trigger / Reset ──────────────────────────────
        _TriggerPanel(c: c),
        const SizedBox(height: 30),
      ]),
    );
  });
}

// Year picker
class _YearPicker extends StatelessWidget {
  final BonusController c;
  const _YearPicker({required this.c});
  @override
  Widget build(BuildContext ctx) {
    final now = DateTime.now().year;
    return Row(children: [
      const Text('Bonus Year', style: TextStyle(color: _ts, fontSize: 11, fontWeight: FontWeight.w700)),
      const Spacer(),
      ...List.generate(3, (i) => now - 1 + i).map((yr) => Obx(() {
        final active = c.selectedYear.value == yr;
        return GestureDetector(
            onTap: () => c.changeYear(yr),
            child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: active ? _amber.withOpacity(0.15) : _s2,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: active ? _amber.withOpacity(0.5) : _bdr)),
                child: Text('$yr', style: TextStyle(
                    color: active ? _amberLt : _ts,
                    fontSize: 12, fontWeight: FontWeight.w700))));
      })),
    ]);
  }
}

// Summary cards
class _SumCards extends StatelessWidget {
  final BonusController c;
  const _SumCards({required this.c});
  @override
  Widget build(BuildContext ctx) {
    final s = c.summary.value!;
    return Row(children: [
      Expanded(child: _KpiCard('Total', '₹${_fmt(s.totalPayout)}', _amber, '${s.totalRecords} employees')),
      const SizedBox(width: 8),
      Expanded(child: _KpiCard('Paid', '${s.paidRecords}', _green, 'records')),
      const SizedBox(width: 8),
      Expanded(child: _KpiCard('Pending', '${s.pendingRecords}', _red, 'records')),
    ]);
  }
}

// Status banner
class _StatusBanner extends StatelessWidget {
  final BonusController c;
  const _StatusBanner({required this.c});
  @override
  Widget build(BuildContext ctx) {
    final cfg = c.config.value;
    if (cfg == null) return const SizedBox.shrink();
    final (color, icon, label) = switch (cfg.status) {
      'triggered'  => (_amber,  '🔔', 'Bonus triggered — payments in progress'),
      'completed'  => (_green,  '✅', 'All bonuses paid for ${cfg.year}'),
      _            => (_purple, '⏳', 'Bonus not yet triggered for ${cfg.year}'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
        if (cfg.triggeredAt != null)
          Text(_shortDate(cfg.triggeredAt!), style: const TextStyle(color: _tm, fontSize: 10)),
      ]),
    );
  }
}

// Config panel
class _ConfigPanel extends StatefulWidget {
  final BonusController c;
  const _ConfigPanel({required this.c});
  @override State<_ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<_ConfigPanel> {
  late TextEditingController _lblCtrl;
  late TextEditingController _daysCtrl;

  @override
  void initState() {
    super.initState();
    _lblCtrl  = TextEditingController(text: widget.c.tfBonusLabel.value);
    _daysCtrl = TextEditingController(text: widget.c.tfWorkingDays.value);
  }

  @override
  void dispose() {
    _lblCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: _s2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('⚙️ Bonus Configuration',
          style: TextStyle(color: _tp, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),

      // Label
      const _FLbl('Occasion Label (e.g. Diwali 2025)'),
      const SizedBox(height: 5),
      _TF(_lblCtrl, 'Diwali 2025', (v) => widget.c.tfBonusLabel.value = v),
      const SizedBox(height: 10),

      // Bonus date
      const _FLbl('Target Payout Date'),
      const SizedBox(height: 5),
      Obx(() => GestureDetector(
        onTap: () async {
          final d = await showDatePicker(
              context: ctx,
              initialDate: widget.c.selectedDate.value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: _amber, onSurface: _tp),
                      dialogBackgroundColor: _s2),
                  child: child!));
          if (d != null) widget.c.selectedDate.value = d;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: _s3, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _bdr)),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: _amber, size: 14),
            const SizedBox(width: 8),
            Text(
                widget.c.selectedDate.value != null
                    ? _shortDate(widget.c.selectedDate.value!) : 'Pick a date',
                style: TextStyle(
                    color: widget.c.selectedDate.value != null ? _tp : _tm,
                    fontSize: 12)),
            const Spacer(),
            if (widget.c.selectedDate.value != null)
              GestureDetector(
                  onTap: () => widget.c.selectedDate.value = null,
                  child: const Icon(Icons.close_rounded, color: _ts, size: 14)),
          ]),
        ),
      )),
      const SizedBox(height: 10),

      // Working days
      const _FLbl('Yearly Working Days (attendance denominator)'),
      const SizedBox(height: 5),
      _TF(_daysCtrl, '300', (v) => widget.c.tfWorkingDays.value = v,
          keyboard: TextInputType.number,
          formatter: FilteringTextInputFormatter.digitsOnly),
      const SizedBox(height: 4),
      const Text('Number of expected shift-days per year. Used to compute attendance %.',
          style: TextStyle(color: _tm, fontSize: 10)),
      const SizedBox(height: 12),

      // Save button
      Obx(() => _GBtn(
        widget.c.isSavingCfg.value ? 'Saving…' : '💾 Save Config',
        _blue,
        widget.c.isSavingCfg.value,
        widget.c.saveConfig,
      )),
      Obx(() {
        if (widget.c.cfgSaveOk.value)
          return const Padding(padding: EdgeInsets.only(top: 6),
              child: Text('✅ Config saved', style: TextStyle(color: _greenLt, fontSize: 11)));
        if (widget.c.cfgSaveErr.value != null)
          return Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('⚠️ ${widget.c.cfgSaveErr.value}',
                  style: const TextStyle(color: _redLt, fontSize: 11)));
        return const SizedBox.shrink();
      }),
    ]),
  );
}

// Attendance tiers legend
class _TiersLegend extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: _s2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📈 Attendance Tiers',
          style: TextStyle(color: _tp, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Bonus = Annual Earnings × Bonus% × Attendance Multiplier',
          style: TextStyle(color: _tm, fontSize: 10)),
      const SizedBox(height: 10),
      Row(children: [
        _TierBadge('S', _tierS, '≥ 90%', '×1.00'),
        const SizedBox(width: 6),
        _TierBadge('A', _tierA, '≥ 75%', '×0.75'),
        const SizedBox(width: 6),
        _TierBadge('B', _tierB, '≥ 60%', '×0.50'),
        const SizedBox(width: 6),
        _TierBadge('C', _tierC, '< 60%', '×0.25'),
      ]),
    ]),
  );
}

class _TierBadge extends StatelessWidget {
  final String tier, range, mult;
  final Color color;
  const _TierBadge(this.tier, this.color, this.range, this.mult);
  @override
  Widget build(BuildContext ctx) => Expanded(child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(tier, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      Text(range, style: TextStyle(color: color.withOpacity(0.8), fontSize: 9)),
      Text(mult,  style: const TextStyle(color: _ts, fontSize: 9)),
    ]),
  ));
}

// Trigger panel
class _TriggerPanel extends StatelessWidget {
  final BonusController c;
  const _TriggerPanel({required this.c});

  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: _s2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _amber.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🚀 Trigger Bonus',
          style: TextStyle(color: _amberLt, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text(
          'Calculates annual earnings + attendance for every employee and creates bonus records. '
              'Safe to re-trigger — existing pending records are refreshed. Paid records are never touched.',
          style: TextStyle(color: _tm, fontSize: 10, height: 1.5)),
      const SizedBox(height: 12),
      Obx(() => _GBtn(
        c.isTriggering.value ? 'Computing…' : '⚡ Compute & Trigger Bonus',
        _amber,
        c.isTriggering.value,
            () => _confirmTrigger(ctx),
      )),
      Obx(() {
        if (c.triggerOk.value)
          return const Padding(padding: EdgeInsets.only(top: 6),
              child: Text('✅ Bonus triggered! Check Records tab.',
                  style: TextStyle(color: _greenLt, fontSize: 11)));
        if (c.triggerErr.value != null)
          return Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('⚠️ ${c.triggerErr.value}',
                  style: const TextStyle(color: _redLt, fontSize: 11)));
        return const SizedBox.shrink();
      }),
      const SizedBox(height: 12),
      const Divider(color: _bdr),
      const SizedBox(height: 10),
      const Text('🔄 Reset (Pending Only)',
          style: TextStyle(color: _ts, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('Deletes pending records and resets status. Paid records are kept.',
          style: TextStyle(color: _tm, fontSize: 10)),
      const SizedBox(height: 8),
      Obx(() => _GBtn(
        c.isResetting.value ? 'Resetting…' : '🔄 Reset Pending',
        _red,
        c.isResetting.value,
            () => _confirmReset(ctx),
      )),
      Obx(() {
        if (c.resetOk.value)
          return const Padding(padding: EdgeInsets.only(top: 6),
              child: Text('✅ Reset complete', style: TextStyle(color: _greenLt, fontSize: 11)));
        if (c.resetErr.value != null)
          return Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('⚠️ ${c.resetErr.value}',
                  style: const TextStyle(color: _redLt, fontSize: 11)));
        return const SizedBox.shrink();
      }),
    ]),
  );

  void _confirmTrigger(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: 'Trigger Bonus?',
        body: 'This will compute bonuses for ALL employees based on their annual earnings, '
            'bonus %, and attendance tier. Proceed?',
        confirmLabel: 'Trigger',
        confirmColor: _amber,
        onConfirm: () { Get.back(); c.triggerBonus(); },
      ),
    );
  }

  void _confirmReset(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: 'Reset Pending Bonuses?',
        body: 'All pending (unpaid) records for this year will be deleted. '
            'Already paid records are preserved. Proceed?',
        confirmLabel: 'Reset',
        confirmColor: _red,
        onConfirm: () { Get.back(); c.resetBonus(); },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 2 — RECORDS
// ══════════════════════════════════════════════════════════════
class _RecordsTab extends StatefulWidget {
  final BonusController c;
  const _RecordsTab({required this.c});
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  BonusController get c => widget.c;

  @override
  void initState() {
    super.initState();
    for (final rx in <RxInterface>[
      c.isLoadingRecs,
      c.recsError,
      c.records,
      c.statusFilter,
      c.recordsSummary,
    ]) {
      ever(rx, (_) { if (mounted) setState(() {}); });
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    // Filter chips
    Container(
      color: _s1,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        _fchip('All',     'all',     _blue),
        const SizedBox(width: 6),
        _fchip('Pending', 'pending', _amber),
        const SizedBox(width: 6),
        _fchip('Paid',    'paid',    _green),
        const Spacer(),
        if (c.recordsSummary.value != null)
          Text('₹${_fmt(c.recordsSummary.value!.pendingPayout)} pending',
              style: const TextStyle(color: _amberLt, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),

    Expanded(child: _body()),
  ]);

  Widget _fchip(String label, String val, Color color) {
    final active = c.statusFilter.value == val;
    return GestureDetector(
      onTap: () { c.statusFilter.value = val; c.fetchRecords(); },
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: active ? color.withOpacity(0.15) : _s2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: active ? color.withOpacity(0.5) : _bdr)),
          child: Text(label, style: TextStyle(
              color: active ? color : _ts,
              fontSize: 11, fontWeight: FontWeight.w700))),
    );
  }

  Widget _body() {
    if (c.isLoadingRecs.value) return const _Spin();
    if (c.recsError.value != null) return _Err(c.recsError.value!);
    if (c.records.isEmpty)
      return const _Hint('No bonus records yet. Trigger from the Overview tab.');
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: c.records.length,
      itemBuilder: (_, i) => _RecordCard(rec: c.records[i], c: c),
    );
  }
}

class _RecordCard extends StatefulWidget {
  final BonusRecord rec;
  final BonusController c;
  const _RecordCard({required this.rec, required this.c});
  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  BonusRecord get rec => widget.rec;
  BonusController get c => widget.c;

  @override
  void initState() {
    super.initState();
    ever(c.payingId, (_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext ctx) {
    final tc = _tierColor(rec.attendanceTier);
    final paying = c.payingId.value == rec.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _s2, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: rec.isPaid ? _green.withOpacity(0.25) : _bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          // Tier badge
          Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: tc.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tc.withOpacity(0.4))),
              child: Center(child: Text(rec.attendanceTier,
                  style: TextStyle(color: tc, fontSize: 14, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rec.employeeName, style: const TextStyle(
                color: _tp, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(rec.department, style: const TextStyle(color: _ts, fontSize: 10)),
          ])),
          // Bonus amount
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${_fmt(rec.bonusAmount)}',
                style: const TextStyle(color: _amberLt, fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${rec.bonusPercent.toStringAsFixed(0)}% × ${(rec.multiplier * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: _tm, fontSize: 9)),
          ]),
        ]),
        const SizedBox(height: 10),
        // Stats row
        Wrap(spacing: 6, runSpacing: 4, children: [
          _Tag('📅 ${rec.attendanceDays}/${rec.totalWorkingDays} days'),
          _Tag('📊 ${rec.attendanceRate.toStringAsFixed(1)}% · ${_tierLabel(rec.attendanceTier)}'),
          _Tag('⏱ ${rec.hoursWorked.toStringAsFixed(0)}h worked'),
          _Tag('₹${_fmt(rec.annualEarnings)} earnings'),
          _Tag('Raw ₹${_fmt(rec.rawBonusAmount)}'),
        ]),
        const SizedBox(height: 10),
        // Pay button or paid badge
        if (!rec.isPaid)
          _SmBtn(
              paying ? 'Processing…' : '✅ Mark Paid',
              _green, paying, () => c.markPaid(rec.id))
        else
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: _greenLt, size: 14),
            const SizedBox(width: 6),
            Text('Paid ${rec.paidAt != null ? _shortDate(rec.paidAt!) : ''}',
                style: const TextStyle(color: _greenLt, fontSize: 11)),
          ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 3 — PER-EMPLOYEE BONUS %
// ══════════════════════════════════════════════════════════════
class _RatesTab extends StatelessWidget {
  final BonusController c;
  const _RatesTab({required this.c});

  @override
  Widget build(BuildContext context) {
    // Trigger load on first render
    if (c.empRates.isEmpty && !c.isLoadingEmpRates.value) {
      c.fetchEmpRates();
    }
    return Column(children: [
      Container(
        color: _s1,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Per-Employee Bonus %',
                style: TextStyle(color: _tp, fontSize: 12, fontWeight: FontWeight.w800)),
            Text('Override the default 10% for senior or skilled employees.',
                style: TextStyle(color: _tm, fontSize: 10)),
          ])),
          GestureDetector(
              onTap: c.fetchEmpRates,
              child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: _bdr)),
                  child: const Icon(Icons.refresh_rounded, color: _ts, size: 16))),
        ]),
      ),
      Expanded(child: Obx(() {
        if (c.isLoadingEmpRates.value) return const _Spin();
        if (c.empRates.isEmpty) return const _Hint('No employees found.');
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: c.empRates.length,
          itemBuilder: (_, i) => _EmpRateRow(emp: c.empRates[i], c: c),
        );
      })),
    ]);
  }
}

class _EmpRateRow extends StatefulWidget {
  final EmployeeBonusRate emp;
  final BonusController c;
  const _EmpRateRow({required this.emp, required this.c});
  @override State<_EmpRateRow> createState() => _EmpRateRowState();
}
class _EmpRateRowState extends State<_EmpRateRow> {
  late TextEditingController _tf;
  @override
  void initState() {
    super.initState();
    _tf = TextEditingController(text: widget.emp.bonusPercent.toStringAsFixed(0));
  }
  @override
  void didUpdateWidget(_EmpRateRow old) {
    super.didUpdateWidget(old);
    if (old.emp.bonusPercent != widget.emp.bonusPercent)
      _tf.text = widget.emp.bonusPercent.toStringAsFixed(0);
  }
  @override void dispose() { _tf.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final pct = double.tryParse(_tf.text) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bdr)),
      child: Row(children: [
        _Avatar(widget.emp.name, _amber),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.emp.name, style: const TextStyle(
              color: _tp, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(widget.emp.department, style: const TextStyle(color: _ts, fontSize: 10)),
        ])),
        const SizedBox(width: 8),
        SizedBox(width: 64, child: TextField(
          controller: _tf,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}$'))],
          style: const TextStyle(color: _tp, fontSize: 14, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
              suffixText: '%', suffixStyle: const TextStyle(color: _ts, fontSize: 12),
              filled: true, fillColor: _s3,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: _bdr)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: _bdr)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: _amber, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          onChanged: (_) => setState(() {}),
        )),
        const SizedBox(width: 6),
        Obx(() {
          final saving = widget.c.savingEmpId.value == widget.emp.id;
          return GestureDetector(
              onTap: saving || pct <= 0 ? null
                  : () => widget.c.saveEmpPercent(widget.emp.id, pct),
              child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: saving || pct <= 0 ? _s3 : _amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: saving || pct <= 0 ? _bdr : _amber.withOpacity(0.4))),
                  child: saving
                      ? const Center(child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: _amber, strokeWidth: 2)))
                      : const Icon(Icons.check_rounded, color: _amber, size: 18)));
        }),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHARED ATOMS
// ══════════════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _KpiCard(this.label, this.value, this.color, this.sub);
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _ts, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
      Text(sub, style: const TextStyle(color: _tm, fontSize: 9)),
    ]),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext ctx) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: _s3, borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: const TextStyle(color: _ts, fontSize: 10)));
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  const _Avatar(this.name, this.color);
  @override
  Widget build(BuildContext ctx) => Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Center(child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800))));
}

class _FLbl extends StatelessWidget {
  final String text;
  const _FLbl(this.text);
  @override
  Widget build(BuildContext ctx) => Text(text,
      style: const TextStyle(color: _ts, fontSize: 11, fontWeight: FontWeight.w700));
}

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType keyboard;
  final TextInputFormatter? formatter;
  const _TF(this.ctrl, this.hint, this.onChanged, {
    this.keyboard = TextInputType.text,
    this.formatter,
  });
  @override
  Widget build(BuildContext ctx) => TextField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: formatter != null ? [formatter!] : null,
      style: const TextStyle(color: _tp, fontSize: 13),
      onChanged: onChanged,
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _tm, fontSize: 12),
          filled: true, fillColor: _s3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _bdr)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _bdr)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _blue, width: 1.5))));
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
              border: Border.all(color: loading ? _bdr : color.withOpacity(0.45))),
          child: Center(child: loading
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: _ts, strokeWidth: 2))
              : Text(label, style: TextStyle(
              color: loading ? _ts : color,
              fontSize: 13, fontWeight: FontWeight.w800)))));
}

class _SmBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _SmBtn(this.label, this.color, this.loading, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withOpacity(0.4))),
          child: Center(child: loading
              ? SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)))));
}

class _ConfirmDialog extends StatelessWidget {
  final String title, body, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  const _ConfirmDialog({
    required this.title, required this.body, required this.confirmLabel,
    required this.confirmColor, required this.onConfirm,
  });
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    backgroundColor: _s2,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: confirmColor.withOpacity(0.4))),
    title: Text(title, style: const TextStyle(color: _tp, fontSize: 14)),
    content: Text(body, style: const TextStyle(color: _ts, fontSize: 12, height: 1.5)),
    actions: [
      TextButton(onPressed: Get.back,
          child: const Text('Cancel', style: TextStyle(color: _ts))),
      TextButton(onPressed: onConfirm,
          child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.w800))),
    ],
  );
}

class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext ctx) => const Center(
      child: CircularProgressIndicator(color: _amber, strokeWidth: 2));
}

class _Err extends StatelessWidget {
  final String msg;
  const _Err(this.msg);
  @override
  Widget build(BuildContext ctx) => Center(
      child: Text('⚠️ $msg', style: const TextStyle(color: _redLt, fontSize: 12)));
}

class _Hint extends StatelessWidget {
  final String msg;
  const _Hint(this.msg);
  @override
  Widget build(BuildContext ctx) => Center(
      child: Text(msg, style: const TextStyle(color: _tm, fontSize: 12)));
}

// ── Utilities ──────────────────────────────────────────────────
String _fmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String _shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';