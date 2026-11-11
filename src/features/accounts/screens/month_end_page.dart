import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/accounts_models.dart';
import '../services/accounts_api.dart';
import 'accounts_widgets.dart';

final _monthName = DateFormat('MMMM yyyy');
final _monthKey = DateFormat('yyyy-MM');

// ══════════════════════════════════════════════════════════════
//  MONTH END — read only
//
//  The server's checklist before a month is closed: bank lines placed,
//  cheques cleared, bills with their copies, expenses decided, TDS and
//  GST, MSME limits, GSTR-2B, Tally, the lock. Each open item is done on
//  the web; the phone shows how far along the month is.
// ══════════════════════════════════════════════════════════════

class MonthEndPage extends StatefulWidget {
  const MonthEndPage({super.key});

  @override
  State<MonthEndPage> createState() => _MonthEndPageState();
}

class _MonthEndPageState extends State<MonthEndPage> {
  // The month just gone, as the server defaults to.
  late DateTime _month = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month - 1, 1);
  }();
  CloseChecklist? _c;
  String? _error;
  bool _loading = false;
  int _seq = 0;

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

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
      final c = await AccountsApi.closeChecklist(month: _monthKey.format(_month));
      if (mounted && seq == _seq) setState(() => _c = c);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = accountsMessage(e, 'Could not load the checklist'));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months, 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar('Month end', subtitle: 'Closing checklist · read only'),
      body: Column(children: [
        Container(
          color: ErpColors.bgSurface,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(children: [
            IconButton(
              tooltip: 'Month before',
              onPressed: _loading ? null : () => _shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(_monthName.format(_month),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            ),
            IconButton(
              tooltip: 'Month after',
              onPressed: _loading || _isCurrentMonth ? null : () => _shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: c == null
              ? (_error == null ? const Center(child: CircularProgressIndicator()) : accountsCentred(_error!, onRetry: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: TextStyle(color: ErpColors.errorRed)),
                        ),
                      AccountsCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${c.done} of ${c.total} done',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: c.total == 0 ? 0 : c.done / c.total,
                              minHeight: 8,
                              backgroundColor: ErpColors.bgMuted,
                              color: c.done == c.total ? ErpColors.successGreen : ErpColors.accentBlue,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      for (final i in c.items) ...[
                        _item(i),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 6),
                      Text('Each open item is done in Accounts on the web.',
                          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _item(CloseItem i) {
    return AccountsCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(i.ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20, color: i.ok ? ErpColors.successGreen : ErpColors.warningAmber),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            if (i.detail.isNotEmpty) Text(i.detail, style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
          ]),
        ),
        if (!i.ok && (i.amount ?? 0) > 0) ...[
          const SizedBox(width: 8),
          Text(inr0(i.amount!), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
        ],
      ]),
    );
  }
}
