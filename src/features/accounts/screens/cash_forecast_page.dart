import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/accounts_models.dart';
import '../services/accounts_api.dart';
import 'accounts_widgets.dart';

final _short = DateFormat('dd MMM');

// ══════════════════════════════════════════════════════════════
//  CASH FORECAST — read only
//
//  The server's week-by-week view of cash: today's balances, plus what
//  customers are likely to pay (placed by how each has paid before, or
//  by a promise), less the bills, claims, salaries and taxes falling
//  due. The first week it goes below zero is the one to act on.
// ══════════════════════════════════════════════════════════════

class CashForecastPage extends StatefulWidget {
  const CashForecastPage({super.key});

  @override
  State<CashForecastPage> createState() => _CashForecastPageState();
}

class _CashForecastPageState extends State<CashForecastPage> {
  int _weeks = 6;
  CashForecast? _f;
  String? _error;
  bool _loading = false;
  final Set<int> _open = {};
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
    try {
      final f = await AccountsApi.forecast(weeks: _weeks);
      if (mounted && seq == _seq) {
        setState(() {
          _f = f;
          _open.clear();
        });
      }
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = accountsMessage(e, 'Could not load the forecast'));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar('Cash forecast', subtitle: 'Week by week · read only'),
      body: f == null
          ? (_error == null ? const Center(child: CircularProgressIndicator()) : accountsCentred(_error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Row(children: [
                    for (final w in const [6, 13]) ...[
                      ChoiceChip(
                        label: Text('$w weeks'),
                        selected: _weeks == w,
                        onSelected: _loading
                            ? null
                            : (_) {
                                setState(() => _weeks = w);
                                _load();
                              },
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Spacer(),
                    if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 8),
                  _headline(f),
                  const SizedBox(height: 10),
                  for (final (i, w) in f.weeks.indexed) ...[
                    _week(i, w),
                    const SizedBox(height: 8),
                  ],
                  if (f.laterIn > 0 || f.laterOut > 0)
                    AccountsCard(
                      child: Text(
                        'After these weeks: ${inr0(f.laterIn)} expected in, ${inr0(f.laterOut)} due out.',
                        style: TextStyle(fontSize: 12.5, color: ErpColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Customers are placed by how each has paid before, or by the day they promised. '
                    'Bills, claims, salaries and taxes by when they fall due.',
                    style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _headline(CashForecast f) {
    final short = f.firstShortWeek;
    final last = f.weeks.isEmpty ? f.opening : f.weeks.last.closing;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ErpColors.navyDark, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CASH AND BANK NOW',
            style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10, letterSpacing: 0.7, fontWeight: FontWeight.w700)),
        Text(inr0(f.opening), style: TextStyle(color: ErpColors.textOnDark, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(short != null ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 16, color: short != null ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              short != null
                  ? 'Runs short in the week of ${_short.format(short)}'
                  : 'Stays above zero for ${f.weeks.length} weeks — ${inr0(last)} at the end',
              style: TextStyle(color: ErpColors.textOnDark, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _week(int i, ForecastWeek w) {
    final open = _open.contains(i);
    final short = w.closing < 0;
    return AccountsCard(
      onTap: w.items.isEmpty ? null : () => setState(() => open ? _open.remove(i) : _open.add(i)),
      borderColor: short ? ErpColors.statusCancelledBorder : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              w.from == null ? 'Week ${i + 1}' : '${_short.format(w.from!)} – ${_short.format(w.to ?? w.from!)}',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ErpColors.textPrimary),
            ),
          ),
          Text(inr0(w.closing),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: short ? ErpColors.errorRed : ErpColors.textPrimary)),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          Text('In ${inr0(w.inflow)}', style: TextStyle(fontSize: 12, color: ErpColors.successGreen, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text('Out ${inr0(w.outflow)}', style: TextStyle(fontSize: 12, color: ErpColors.errorRed, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('at week end', style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
          if (w.items.isNotEmpty) Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: ErpColors.textMuted),
        ]),
        if (open) ...[
          const SizedBox(height: 6),
          Divider(height: 1, color: ErpColors.borderLight),
          for (final l in w.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text([l.party, l.docNo].where((s) => s.isNotEmpty).join(' · '),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ErpColors.textPrimary)),
                    if (l.basis.isNotEmpty) Text(l.basis, style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('${l.inflow ? '+' : '−'}${inr0(l.amount)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: l.inflow ? ErpColors.successGreen : ErpColors.errorRed)),
              ]),
            ),
        ],
      ]),
    );
  }
}
