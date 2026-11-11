import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/accounts_models.dart';
import '../services/accounts_api.dart';
import 'accounts_widgets.dart';

final _day = DateFormat('dd MMM yyyy');

/// Expenses and claims waiting for a yes or a no, and the approved
/// claims still to be paid back to the person.
///
/// The server decides who may approve — the admin or accounts role, and
/// never the person who entered it — and says so in words when the
/// answer is no; this page shows those words rather than guessing.
class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: accountsAppBar(
          'Approvals',
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: ErpColors.textOnDarkSub,
            indicatorColor: ErpColors.accentBlue,
            tabs: const [Tab(text: 'To approve'), Tab(text: 'To pay back')],
          ),
        ),
        body: const TabBarView(children: [_ExpenseList(status: 'pending'), _ExpenseList(status: 'approved')]),
      ),
    );
  }
}

class _ExpenseList extends StatefulWidget {
  const _ExpenseList({required this.status});

  final String status;

  @override
  State<_ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<_ExpenseList> {
  List<ExpenseRow>? _rows;
  String? _error;
  String? _busy;

  bool get _toPay => widget.status == 'approved';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await AccountsApi.expenses(widget.status);
      if (mounted) setState(() => _rows = _toPay ? rows.where((r) => r.toPay > 0).toList() : rows);
    } catch (e) {
      if (mounted) setState(() => _error = accountsMessage(e, 'Could not load the expenses'));
    }
  }

  Future<void> _run(ExpenseRow e, Future<String> Function() action) async {
    setState(() => _busy = e.id);
    try {
      final msg = await action();
      if (mounted) accountsToast(context, msg);
      await _load();
    } catch (err) {
      if (mounted) accountsToast(context, accountsMessage(err, 'That did not go through'), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _approve(ExpenseRow e) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ApproveDialog(expense: e),
    );
    if (note == null) return;
    await _run(e, () async {
      await AccountsApi.approveExpense(e.id, note: note);
      return '${e.expenseNo} approved';
    });
  }

  Future<void> _reject(ExpenseRow e) async {
    final reason = await askReason(
      context,
      title: 'Reject ${e.expenseNo}?',
      message: '${inr(e.amount)} — ${e.description}. The person sees the reason with the claim.',
      confirm: 'Reject',
      minLength: 8,
      hint: 'Reason (at least 8 characters)',
      confirmColor: ErpColors.errorRed,
    );
    if (reason == null) return;
    await _run(e, () async {
      await AccountsApi.rejectExpense(e.id, reason);
      return '${e.expenseNo} rejected';
    });
  }

  Future<void> _pay(ExpenseRow e) async {
    final r = await showModalBottomSheet<({String account, String mode, String reference})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaySheet(expense: e),
    );
    if (r == null) return;
    await _run(e, () async {
      final no = await AccountsApi.payExpense(e.id, account: r.account, mode: r.mode, reference: r.reference);
      return no.isEmpty ? 'Paid' : 'Paid — voucher $no';
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null) {
      return _error == null ? const Center(child: CircularProgressIndicator()) : accountsCentred(_error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: rows.isEmpty
          ? accountsCentred(_toPay ? 'Every approved claim has been paid back.' : 'Nothing is waiting for approval.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(rows[i]),
            ),
    );
  }

  Widget _card(ExpenseRow e) {
    final busy = _busy == e.id;
    return AccountsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(e.description,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Text(inr(_toPay ? e.toPay : e.amount),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
        ]),
        const SizedBox(height: 3),
        Text(
          [
            if (e.payeeName.isNotEmpty) e.payeeName,
            e.categoryName,
            if (e.date != null) _day.format(e.date!),
            e.expenseNo,
            if (e.attachments > 0) 'receipt attached',
          ].where((s) => s.isNotEmpty).join('  ·  '),
          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
        ),
        if (e.submittedBy.isNotEmpty && e.submittedBy != e.payeeName)
          Text('Entered by ${e.submittedBy}', style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
        const SizedBox(height: 8),
        Row(children: [
          if (e.isClaim) accountsChip('Claim', ErpColors.statusOpenBg, ErpColors.statusOpenText),
          const Spacer(),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_toPay)
            FilledButton(onPressed: () => _pay(e), child: const Text('Pay back…'))
          else ...[
            TextButton(
              onPressed: () => _reject(e),
              child: Text('Reject…', style: TextStyle(color: ErpColors.errorRed)),
            ),
            const SizedBox(width: 6),
            FilledButton(onPressed: () => _approve(e), child: const Text('Approve')),
          ],
        ]),
      ]),
    );
  }
}

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.expense});

  final ExpenseRow expense;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    return AlertDialog(
      title: Text('Approve ${inr(e.amount)}?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${e.description}${e.payeeName.isEmpty ? '' : ' — ${e.payeeName}'}', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Text(e.isClaim ? 'It is then owed to the person, and paid back from To pay back.' : 'It goes into the books as an expense.',
            style: TextStyle(fontSize: 12, color: ErpColors.textMuted)),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(onPressed: () => Navigator.pop(context, _note.text.trim()), child: const Text('Approve')),
      ],
    );
  }
}

/// Pay an approved claim back: from which account, how, and the
/// reference the bank gave.
class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.expense});

  final ExpenseRow expense;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  List<BankAccount>? _accounts;
  String? _error;
  BankAccount? _account;
  String? _mode;
  final _ref = TextEditingController();

  @override
  void initState() {
    super.initState();
    AccountsApi.bankAccounts().then((a) {
      if (!mounted) return;
      setState(() {
        _accounts = a;
        _account = a.where((x) => x.isDefault).firstOrNull ?? a.firstOrNull;
        _mode = _account?.modes.first;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _error = accountsMessage(e, 'Could not load the accounts'));
    });
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pay back ${inr(e.toPay)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text('${e.payeeName.isEmpty ? e.description : e.payeeName} · ${e.expenseNo}',
            style: TextStyle(fontSize: 12, color: ErpColors.textMuted)),
        const SizedBox(height: 14),
        if (_error != null) Text(_error!, style: TextStyle(color: ErpColors.errorRed)),
        if (_accounts == null && _error == null) const LinearProgressIndicator(),
        if (_accounts != null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('pay-from-${_account?.id}'),
            // ignore: deprecated_member_use
            value: _account?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pay from', border: OutlineInputBorder()),
            items: [for (final a in _accounts!) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${inr0(a.balance)}'))],
            onChanged: (id) => setState(() {
              _account = _accounts!.firstWhere((a) => a.id == id);
              _mode = _account!.modes.first;
            }),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [
            for (final m in _account?.modes ?? const <String>[])
              ChoiceChip(label: Text(modeLabel(m)), selected: _mode == m, onSelected: (_) => setState(() => _mode = m)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _ref,
            decoration: const InputDecoration(labelText: 'Reference (UTR, cheque no.)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _account == null || _mode == null
                  ? null
                  : () => Navigator.pop(context, (account: _account!.id, mode: _mode!, reference: _ref.text.trim())),
              child: Text('Pay ${inr(e.toPay)}'),
            ),
          ),
        ],
      ]),
    );
  }
}
