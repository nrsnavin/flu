import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../models/payroll_models.dart' show kMonths;
import '../models/payroll_review_models.dart';
import '../services/payroll_review_api.dart';

// The payroll page's own dark palette (screens/payroll_page.dart), so
// these read as part of it.
const _bg = Color(0xFF060D18);
const _s1 = Color(0xFF0B1626);
const _s2 = Color(0xFF0F1F33);
const _s3 = Color(0xFF162540);
const _bdr = Color(0xFF1A2E4A);
const _blueLt = Color(0xFF60A5FA);
const _green = Color(0xFF10B981);
const _greenLt = Color(0xFF34D399);
const _amber = Color(0xFFF59E0B);
const _amberLt = Color(0xFFFBBF24);
const _red = Color(0xFFEF4444);
const _redLt = Color(0xFFFCA5A5);
const _tp = Color(0xFFF0F6FF);
const _ts = Color(0xFF8BA4C2);
const _tm = Color(0xFF3D5470);

final _day = DateFormat('dd MMM yyyy');

PreferredSizeWidget _bar(String title, String subtitle) => AppBar(
      backgroundColor: _s1,
      foregroundColor: _tp,
      elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(color: _tp, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(subtitle, style: const TextStyle(color: _ts, fontSize: 10.5)),
      ]),
    );

Widget _centred(String text, {VoidCallback? onRetry, Color colour = _ts}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: colour, fontSize: 13)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ]),
      ),
    );

BoxDecoration _card([Color? border]) => BoxDecoration(
      color: _s2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border ?? _bdr),
    );

// ══════════════════════════════════════════════════════════════
//  CHECK BEFORE PAYING
//
//  Each slip of the month against the worker's own last three months:
//  very likely wrong (negative pay, pay with no shift worked), unusual
//  (a big jump, heavy overtime, many absences, heavy deductions), or
//  worth knowing (a first month, a new rate). Nothing here changes a
//  slip. Tapping a worker pops with their id, to open the payslip.
// ══════════════════════════════════════════════════════════════

class PayrollCheckPage extends StatefulWidget {
  const PayrollCheckPage({super.key, required this.year, required this.month});

  final int year, month;

  @override
  State<PayrollCheckPage> createState() => _PayrollCheckPageState();
}

class _PayrollCheckPageState extends State<PayrollCheckPage> {
  PayrollCheck? _c;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final c = await PayrollReviewApi.check(year: widget.year, month: widget.month);
      if (mounted) setState(() => _c = c);
    } catch (e) {
      if (mounted) setState(() => _error = payrollMessage(e, 'Could not check the payslips'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _bar('Check before paying', '${kMonths[widget.month]} ${widget.year}'),
      body: c == null
          ? (_error == null ? const Center(child: CircularProgressIndicator()) : _centred(_error!, onRetry: _load, colour: _redLt))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _summary(c),
                  const SizedBox(height: 12),
                  if (c.slips == 0)
                    _centred('No payslips for ${kMonths[widget.month]} yet — generate them first.')
                  else if (c.rows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _card(_green.withValues(alpha: 0.4)),
                      child: const Text('Every slip looks like its worker\'s recent months.',
                          style: TextStyle(color: _greenLt, fontSize: 13, fontWeight: FontWeight.w600)),
                    )
                  else
                    for (final r in c.rows) ...[
                      _row(r),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _summary(PayrollCheck c) {
    final diff = c.totalNet - c.lastMonthNet;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c.slips} ${c.slips == 1 ? 'slip' : 'slips'} · ${inr0(c.totalNet)} net',
            style: const TextStyle(color: _tp, fontSize: 16, fontWeight: FontWeight.w800)),
        if (c.lastMonthNet > 0)
          Text(
            'Last month ${inr0(c.lastMonthNet)} — ${diff >= 0 ? 'up' : 'down'} ${inr0(diff.abs())}',
            style: const TextStyle(color: _ts, fontSize: 11.5),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _count(c.high, 'very likely wrong', _red),
          _count(c.check, 'unusual', _amber),
          _count(c.info, 'worth knowing', _blueLt),
        ]),
      ]),
    );
  }

  Widget _count(int n, String what, Color colour) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: n > 0 ? 0.15 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colour.withValues(alpha: n > 0 ? 0.5 : 0.15)),
        ),
        child: Text('$n $what', style: TextStyle(color: n > 0 ? colour : _tm, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _row(PayslipCheckRow r) {
    final colour = switch (r.worst) { 'high' => _red, 'check' => _amber, _ => _blueLt };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: r.employeeId.isEmpty ? null : () => Navigator.of(context).pop(r.employeeId),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _card(colour.withValues(alpha: 0.45)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: const TextStyle(color: _tp, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  Text([r.department, r.status].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(color: _ts, fontSize: 10.5)),
                ]),
              ),
              Text(inr0(r.netPay),
                  style: TextStyle(color: r.netPay < 0 ? _redLt : _tp, fontSize: 15, fontWeight: FontWeight.w900)),
              const Icon(Icons.chevron_right, color: _tm, size: 18),
            ]),
            const SizedBox(height: 8),
            for (final f in r.flags)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    switch (f.severity) {
                      'high' => Icons.error_outline,
                      'check' => Icons.warning_amber_rounded,
                      _ => Icons.info_outline,
                    },
                    size: 15,
                    color: switch (f.severity) { 'high' => _redLt, 'check' => _amberLt, _ => _blueLt },
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.reason, style: const TextStyle(color: _tp, fontSize: 12))),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  A WORKER'S LEDGER
//
//  Every rupee that changed what the factory owes one worker — pay,
//  overtime, bonuses, penalties, PF/ESI, advances given and recovered,
//  salary handed over — newest first, each with the balance after it,
//  and the balance carried in from before the window.
// ══════════════════════════════════════════════════════════════

class EmployeeLedgerPage extends StatefulWidget {
  const EmployeeLedgerPage({super.key, required this.employeeId, required this.name});

  final String employeeId, name;

  @override
  State<EmployeeLedgerPage> createState() => _EmployeeLedgerPageState();
}

class _EmployeeLedgerPageState extends State<EmployeeLedgerPage> {
  int _months = 3;
  EmployeeLedger? _l;
  String? _error;
  bool _loading = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = DateTime(to.year, to.month - _months, to.day);
    try {
      final l = await PayrollReviewApi.ledger(widget.employeeId, from: from, to: to);
      if (mounted && seq == _seq) setState(() => _l = l);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = payrollMessage(e, 'Could not load the ledger'));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _bar(widget.name, 'Ledger'),
      body: Column(children: [
        Container(
          color: _s1,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(children: [
            for (final m in const [3, 6, 12]) ...[
              ChoiceChip(
                label: Text('$m months'),
                selected: _months == m,
                onSelected: _loading
                    ? null
                    : (_) {
                        setState(() => _months = m);
                        _load();
                      },
              ),
              const SizedBox(width: 6),
            ],
            const Spacer(),
            if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        ),
        Expanded(
          child: l == null
              ? (_error == null ? const Center(child: CircularProgressIndicator()) : _centred(_error!, onRetry: _load, colour: _redLt))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: const TextStyle(color: _redLt, fontSize: 12)),
                        ),
                      _balance(l),
                      const SizedBox(height: 10),
                      _totals(l),
                      const SizedBox(height: 12),
                      if (l.lines.isEmpty)
                        _centred('Nothing on the ledger in the last $_months months.')
                      else
                        Container(
                          decoration: _card(),
                          child: Column(children: [
                            for (final (i, line) in l.lines.reversed.indexed) ...[
                              if (i > 0) const Divider(height: 1, color: _bdr),
                              _line(line),
                            ],
                          ]),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        l.from == null ? '' : 'Carried in on ${_day.format(l.from!)}: ${inr(l.opening)}',
                        style: const TextStyle(color: _tm, fontSize: 11),
                      ),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _balance(EmployeeLedger l) {
    final owed = l.closing;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          owed >= 0 ? 'STILL PAYABLE TO ${widget.name.toUpperCase()}' : '${widget.name.toUpperCase()} OWES THE FACTORY',
          style: const TextStyle(color: _ts, fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(inr(owed.abs()),
            style: TextStyle(color: owed >= 0 ? _tp : _redLt, fontSize: 24, fontWeight: FontWeight.w900)),
        Text('${inr(l.opening)} at the start of the window', style: const TextStyle(color: _ts, fontSize: 11)),
      ]),
    );
  }

  Widget _totals(EmployeeLedger l) {
    const names = {
      'earnings': 'Earned',
      'bonuses': 'Bonuses',
      'penalties': 'Penalties',
      'statutory': 'PF / ESI',
      'advances': 'Advances',
      'payments': 'Paid',
      'writtenOff': 'Written off',
    };
    final shown = [for (final e in names.entries) if ((l.totals[e.key] ?? 0).abs() > 0.004) (e.value, l.totals[e.key]!)];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (label, v) in shown)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: _s3, borderRadius: BorderRadius.circular(8), border: Border.all(color: _bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: const TextStyle(color: _ts, fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.w700)),
            Text('${v >= 0 ? '+' : '−'}${inr0(v.abs())}',
                style: TextStyle(color: v >= 0 ? _greenLt : _redLt, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
    ]);
  }

  Widget _line(LedgerLine l) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.label.isNotEmpty ? l.label : l.kindLabel,
                  style: const TextStyle(color: _tp, fontSize: 12.5, fontWeight: FontWeight.w600)),
              Text([if (l.date != null) _day.format(l.date!), l.kindLabel].join(' · '),
                  style: const TextStyle(color: _ts, fontSize: 10.5)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${l.amount >= 0 ? '+' : '−'}${inr(l.amount.abs())}',
                style: TextStyle(color: l.amount >= 0 ? _greenLt : _redLt, fontSize: 12.5, fontWeight: FontWeight.w800)),
            Text(inr(l.balance), style: const TextStyle(color: _ts, fontSize: 10.5)),
          ]),
        ]),
      );
}
