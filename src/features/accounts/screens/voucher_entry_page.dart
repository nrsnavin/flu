import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../../core/request_id.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/accounts_models.dart';
import '../services/accounts_api.dart';
import '../voucher_math.dart';
import 'accounts_widgets.dart';

final _day = DateFormat('dd MMM yyyy');

// ══════════════════════════════════════════════════════════════
//  RECEIVE MONEY / PAY A SUPPLIER
//
//  Who, how much, which invoices or bills it settles (oldest first,
//  any of them can be unticked), and into or out of which account.
//  Before a payment goes, the server's own checks run — a supplier's
//  bank account changed lately, the same payment twice — and a danger
//  flag is not paid without saying how it was confirmed. A bill that
//  carries TDS is paid on the web, where the TDS is worked out.
// ══════════════════════════════════════════════════════════════

class VoucherEntryPage extends StatefulWidget {
  const VoucherEntryPage({super.key, required this.kind, this.party});

  /// receipt or payment.
  final String kind;

  /// The customer or supplier, when opened from theirs.
  final Party? party;

  @override
  State<VoucherEntryPage> createState() => _VoucherEntryPageState();
}

class _VoucherEntryPageState extends State<VoucherEntryPage> {
  bool get _receipt => widget.kind == 'receipt';
  String get _partyType => _receipt ? 'customer' : 'supplier';

  Party? _party;
  List<OpenDoc>? _docs;
  bool _docsLoading = false;
  String? _docsError;
  final Set<String> _skipped = {};

  List<BankAccount>? _accounts;
  String? _accountsError;
  BankAccount? _account;
  String? _mode;

  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _chequeNo = TextEditingController();
  final _chequeBank = TextEditingController();
  final _narration = TextEditingController();
  late DateTime _date = _today();
  DateTime? _chequeDate;

  bool _saving = false;

  // One id per voucher as it stands: sent again after a timeout it
  // comes back as the voucher already made; changed, it is a new one.
  String _requestId = newRequestId();
  String? _lastKey;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    if (widget.party != null) _choose(widget.party!);
  }

  @override
  void dispose() {
    for (final c in [_amount, _reference, _chequeNo, _chequeBank, _narration]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _accountsError = null);
    try {
      final a = await AccountsApi.bankAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = a;
        _account = a.where((x) => x.isDefault).firstOrNull ?? a.where((x) => x.kind == 'bank').firstOrNull ?? a.firstOrNull;
        _mode = _account?.modes.first;
      });
    } catch (e) {
      if (mounted) setState(() => _accountsError = accountsMessage(e, 'Could not load the accounts'));
    }
  }

  Future<void> _choose(Party p) async {
    setState(() {
      _party = p;
      _docs = null;
      _docsError = null;
      _docsLoading = true;
      _skipped.clear();
    });
    try {
      final r = await AccountsApi.openDocs(_partyType, p.id);
      if (mounted && _party?.id == p.id) setState(() => _docs = oldestFirst(r.docs));
    } catch (e) {
      if (mounted && _party?.id == p.id) setState(() => _docsError = accountsMessage(e, 'Could not load what is open'));
    } finally {
      if (mounted && _party?.id == p.id) setState(() => _docsLoading = false);
    }
  }

  Future<void> _pickParty() async {
    final p = await Navigator.of(context).push<Party>(
      MaterialPageRoute(builder: (_) => PartyPickerPage(partyType: _partyType)),
    );
    if (p != null && p.id != _party?.id) _choose(p);
  }

  double get _amountValue => r2(double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0);

  List<({OpenDoc doc, double amount})> get _allocations =>
      allocateOldestFirst(_amountValue, _docs ?? const [], skipped: _skipped);

  /// The first thing stopping the voucher, in words; null when it can go.
  String? _problem(List<({OpenDoc doc, double amount})> allocations) {
    if (_party == null) return 'Choose the ${_receipt ? 'customer' : 'supplier'}';
    if (_docsLoading) return 'Loading what is open…';
    if (_amountValue <= 0) return 'Enter the amount';
    if (_account == null || _mode == null) return 'Choose the account';
    if (_mode == 'cheque' && _chequeNo.text.trim().isEmpty) return 'Enter the cheque number';
    if (!_receipt) {
      final tds = tdsBlockers(allocations);
      if (tds.isNotEmpty) {
        return '${tds.map((d) => d.docNo).join(', ')} ${tds.length == 1 ? 'carries' : 'carry'} TDS — pay '
            '${tds.length == 1 ? 'it' : 'them'} on the web, where the TDS is worked out, or untick '
            '${tds.length == 1 ? 'it' : 'them'}';
      }
    }
    return null;
  }

  Map<String, dynamic> _body(List<({OpenDoc doc, double amount})> allocations, {String riskNote = ''}) =>
      AccountsApi.voucherBody(
        kind: widget.kind,
        partyType: _partyType,
        party: _party!.id,
        amount: _amountValue,
        mode: _mode!,
        account: _account!.id,
        date: _date,
        allocations: allocations,
        reference: _mode == 'cheque' ? '' : _reference.text,
        chequeNo: _chequeNo.text,
        chequeBank: _chequeBank.text,
        chequeDate: _chequeDate,
        narration: _narration.text,
        riskNote: riskNote,
      );

  Future<void> _submit() async {
    final allocations = _allocations;
    if (_problem(allocations) != null) return;
    final amount = _amountValue;
    final party = _party!;
    var body = _body(allocations);

    // Before money goes out: what the server would stop or warn about.
    // The check is advice — the server runs it again on posting.
    var flags = const <PaymentFlag>[];
    if (!_receipt) {
      setState(() => _saving = true);
      try {
        flags = await AccountsApi.checkPayment(body);
      } catch (_) {
        // Posting checks again and stops a danger flag in words.
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      if (!mounted) return;
    }

    final s = settlement(amount, allocations);
    final settledNos = [for (final a in allocations) if (a.amount > 0) a.doc.docNo];
    final note = await showDialog<String>(
      context: context,
      builder: (_) => ConfirmVoucherDialog(
        title: _receipt ? 'Record ${inr(amount)} received?' : 'Pay ${inr(amount)}?',
        lines: [
          party.name,
          '${_receipt ? 'Into' : 'From'} ${_account!.name} · ${modeLabel(_mode!)} · ${_day.format(_date)}',
          if (settledNos.isNotEmpty) 'Settles ${settledNos.join(', ')}',
          if (s.onAccount > 0) '${inr(s.onAccount)} stays on their account as an advance',
        ],
        flags: flags,
        confirm: _receipt ? 'Record' : 'Pay',
      ),
    );
    if (note == null || !mounted) return;
    if (note.isNotEmpty) body = _body(allocations, riskNote: note);

    final key = jsonEncode(body);
    if (key != _lastKey) {
      _requestId = newRequestId();
      _lastKey = key;
    }
    setState(() => _saving = true);
    try {
      final v = await AccountsApi.createVoucher(body, requestId: _requestId);
      if (!mounted) return;
      accountsToast(context, '${_receipt ? 'Receipt' : 'Payment'} ${v.voucherNo} recorded — ${inr(v.amount)}');
      Navigator.of(context).pop(v);
    } catch (e) {
      if (mounted) {
        accountsToast(context, accountsMessage(e, 'The ${_receipt ? 'receipt' : 'payment'} was not recorded'), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool cheque}) async {
    final now = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: cheque ? (_chequeDate ?? _date) : _date,
      firstDate: now.subtract(const Duration(days: 365)),
      // A cheque can be dated ahead (post-dated); the voucher cannot.
      lastDate: cheque ? now.add(const Duration(days: 180)) : now,
    );
    if (picked == null) return;
    setState(() => cheque ? _chequeDate = picked : _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final allocations = _allocations;
    final problem = _problem(allocations);
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar(_receipt ? 'Receive money' : 'Pay a supplier',
          subtitle: _receipt ? 'Receipt from a customer' : 'Payment to a supplier'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _partyCard(),
          if (_party != null) ...[
            const SizedBox(height: 14),
            accountsLabel('Amount'),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: _receipt ? 'Amount received' : 'Amount to pay',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: ErpColors.bgSurface,
              ),
            ),
            const SizedBox(height: 14),
            ..._docsSection(allocations),
            const SizedBox(height: 14),
            ..._howSection(),
          ],
        ],
      ),
      bottomNavigationBar: _party == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: ErpColors.bgSurface,
                  border: Border(top: BorderSide(color: ErpColors.borderLight)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (problem != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(problem,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              color: problem.contains('TDS') ? ErpColors.errorRed : ErpColors.textMuted)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: problem != null || _saving ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_receipt
                              ? 'Record ${_amountValue > 0 ? inr(_amountValue) : ''} received'.replaceAll('  ', ' ')
                              : 'Pay ${_amountValue > 0 ? inr(_amountValue) : ''}'.trim()),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _partyCard() {
    final p = _party;
    final open = (_docs ?? const <OpenDoc>[]).fold(0.0, (s, d) => s + d.outstanding);
    return AccountsCard(
      onTap: _saving ? null : _pickParty,
      child: Row(children: [
        Icon(_receipt ? Icons.storefront_outlined : Icons.local_shipping_outlined, color: ErpColors.accentBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_receipt ? 'CUSTOMER' : 'SUPPLIER',
                style: TextStyle(fontSize: 9.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: ErpColors.textMuted)),
            Text(p?.name ?? 'Choose the ${_receipt ? 'customer' : 'supplier'}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p == null ? ErpColors.accentBlue : ErpColors.textPrimary)),
            if (p != null && _docs != null)
              Text(
                _docs!.isEmpty ? 'Nothing open' : '${inr(open)} open on ${_docs!.length} ${_docs!.length == 1 ? 'document' : 'documents'}',
                style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
              ),
          ]),
        ),
        Text(p == null ? 'Choose' : 'Change', style: TextStyle(color: ErpColors.accentBlue, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  List<Widget> _docsSection(List<({OpenDoc doc, double amount})> allocations) {
    final docs = _docs;
    final title = _receipt ? 'Settles these invoices' : 'Settles these bills';
    if (_docsLoading) return [accountsLabel(title), const LinearProgressIndicator()];
    if (_docsError != null) {
      return [
        accountsLabel(title),
        AccountsCard(
          child: Row(children: [
            Expanded(child: Text(_docsError!, style: TextStyle(color: ErpColors.errorRed))),
            TextButton(onPressed: () => _choose(_party!), child: const Text('Try again')),
          ]),
        ),
      ];
    }
    if (docs == null) return const [];
    if (docs.isEmpty) {
      return [
        accountsLabel(title),
        AccountsCard(
          child: Text(
            _receipt
                ? 'Nothing is open for ${_party!.name}. What they pay stays on their account as an advance.'
                : 'Nothing is due to ${_party!.name}. What is paid stays with them as an advance — say why in the note.',
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
          ),
        ),
      ];
    }
    final s = settlement(_amountValue, allocations);
    final ticked = tickedTotal(docs, _skipped);
    return [
      Row(children: [
        Expanded(child: accountsLabel(title)),
        if (ticked > 0 && (ticked - _amountValue).abs() > 0.005)
          TextButton(
            onPressed: () => setState(() => _amount.text = ticked.toStringAsFixed(2)),
            child: Text('Fill ${inr(ticked)}'),
          ),
      ]),
      AccountsCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final (i, a) in allocations.indexed) ...[
            if (i > 0) Divider(height: 1, color: ErpColors.borderLight),
            _docRow(a.doc, a.amount),
          ],
        ]),
      ),
      if (_amountValue > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            [
              if (s.docs > 0) 'Settles ${inr(s.settled)} on ${s.docs} ${s.docs == 1 ? 'document' : 'documents'}',
              if (s.onAccount > 0) '${inr(s.onAccount)} stays on account as an advance',
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: s.onAccount > 0 && !_receipt ? ErpColors.warningAmber : ErpColors.textSecondary),
          ),
        ),
    ];
  }

  Widget _docRow(OpenDoc d, double settles) {
    final skipped = _skipped.contains(d.id);
    final tds = !_receipt && d.tdsSection.isNotEmpty;
    return InkWell(
      onTap: () => setState(() => skipped ? _skipped.remove(d.id) : _skipped.add(d.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
        child: Row(children: [
          Checkbox(
            value: !skipped,
            onChanged: (v) => setState(() => v == true ? _skipped.remove(d.id) : _skipped.add(d.id)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d.kindLabel} ${d.docNo}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (d.refNo.isNotEmpty) Text('Ref ${d.refNo}', style: TextStyle(fontSize: 11.5, color: ErpColors.textSecondary)),
                if (d.date != null) Text(_day.format(d.date!), style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
                if (d.overdueDays > 0)
                  Text('${d.overdueDays} days overdue', style: TextStyle(fontSize: 11.5, color: ErpColors.errorRed)),
                if (tds) accountsChip('TDS ${d.tdsSection}', ErpColors.statusCancelledBg, ErpColors.statusCancelledText),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(inr(d.outstanding),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            if (settles > 0)
              Text(settles + 0.005 >= d.outstanding ? 'settled in full' : 'settles ${inr(settles)}',
                  style: TextStyle(fontSize: 11, color: ErpColors.successGreen, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _howSection() {
    final accounts = _accounts;
    return [
      accountsLabel(_receipt ? 'Into' : 'Paid from'),
      if (_accountsError != null)
        AccountsCard(
          child: Row(children: [
            Expanded(child: Text(_accountsError!, style: TextStyle(color: ErpColors.errorRed))),
            TextButton(onPressed: _loadAccounts, child: const Text('Try again')),
          ]),
        )
      else if (accounts == null)
        const LinearProgressIndicator()
      else if (accounts.isEmpty)
        AccountsCard(
          child: Text('No bank or cash account is set up yet. An admin adds them in Accounts on the web.',
              style: TextStyle(color: ErpColors.textSecondary)),
        )
      else ...[
        DropdownButtonFormField<String>(
          key: ValueKey('account-${_account?.id}'),
          // `value`, as every dropdown in the app: `initialValue` is
          // newer than some of the Flutter versions it is built with.
          // ignore: deprecated_member_use
          value: _account?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Account',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: ErpColors.bgSurface,
          ),
          items: [
            for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${inr0(a.balance)}')),
          ],
          onChanged: (id) => setState(() {
            _account = accounts.firstWhere((a) => a.id == id);
            if (!_account!.modes.contains(_mode)) _mode = _account!.modes.first;
          }),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final m in _account?.modes ?? const <String>[])
            ChoiceChip(label: Text(modeLabel(m)), selected: _mode == m, onSelected: (_) => setState(() => _mode = m)),
        ]),
      ],
      const SizedBox(height: 10),
      _dateField('Date', _date, () => _pickDate(cheque: false)),
      const SizedBox(height: 10),
      if (_mode == 'cheque') ...[
        _field(_chequeNo, 'Cheque number', onChanged: true),
        if (_receipt) ...[
          const SizedBox(height: 10),
          _field(_chequeBank, 'Drawn on (bank)'),
        ],
        const SizedBox(height: 10),
        _dateField('Cheque date', _chequeDate ?? _date, () => _pickDate(cheque: true)),
      ] else
        _field(_reference, _mode == 'cash' ? 'Reference (optional)' : 'Reference (UTR, UPI ref)'),
      const SizedBox(height: 10),
      _field(_narration, 'Note (optional)'),
    ];
  }

  Widget _field(TextEditingController c, String label, {bool onChanged = false}) => TextField(
        controller: c,
        onChanged: onChanged ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: ErpColors.bgSurface,
        ),
      );

  Widget _dateField(String label, DateTime value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: ErpColors.bgSurface,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(_day.format(value)),
        ),
      );
}

/// Pick a customer or supplier by name, phone or GSTIN.
class PartyPickerPage extends StatefulWidget {
  const PartyPickerPage({super.key, required this.partyType});

  /// customer or supplier.
  final String partyType;

  @override
  State<PartyPickerPage> createState() => _PartyPickerPageState();
}

class _PartyPickerPageState extends State<PartyPickerPage> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Party>? _rows;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _error = null);
    try {
      final rows = await AccountsApi.parties(widget.partyType, q.trim());
      if (mounted && seq == _seq) setState(() => _rows = rows);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = accountsMessage(e, 'Could not search'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.partyType == 'customer' ? 'customer' : 'supplier';
    final rows = _rows;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar('Choose a $word'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => _search(v));
            },
            decoration: InputDecoration(
              hintText: 'Search by name, phone or GSTIN',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: ErpColors.bgSurface,
            ),
          ),
        ),
        Expanded(
          child: _error != null
              ? accountsCentred(_error!, onRetry: () => _search(_q.text))
              : rows == null
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? accountsCentred('No $word matches "${_q.text.trim()}".')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final p = rows[i];
                            return AccountsCard(
                              onTap: () => Navigator.of(context).pop(p),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p.name,
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                                    if (p.gstin.isNotEmpty)
                                      Text(p.gstin, style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
                                  ]),
                                ),
                                Icon(Icons.chevron_right, color: ErpColors.textMuted),
                              ]),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}

/// The last look before money is recorded: what, from where, what it
/// settles, and the server's flags. A danger flag needs a few words on
/// how it was confirmed. Returns that note ('' with no danger flag), or
/// null when the person backs out.
class ConfirmVoucherDialog extends StatefulWidget {
  const ConfirmVoucherDialog({
    super.key,
    required this.title,
    required this.lines,
    required this.flags,
    required this.confirm,
  });

  final String title;
  final List<String> lines;
  final List<PaymentFlag> flags;
  final String confirm;

  @override
  State<ConfirmVoucherDialog> createState() => _ConfirmVoucherDialogState();
}

class _ConfirmVoucherDialogState extends State<ConfirmVoucherDialog> {
  final _note = TextEditingController();

  bool get _danger => widget.flags.any((f) => f.severity == 'danger');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = !_danger || _note.text.trim().length >= 8;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in widget.lines)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: const TextStyle(fontSize: 13))),
          for (final f in widget.flags)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: f.severity == 'danger'
                    ? ErpColors.statusCancelledBg
                    : f.severity == 'warning'
                        ? ErpColors.statusPartialBg
                        : ErpColors.statusOpenBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  f.severity == 'danger' ? Icons.gpp_maybe_outlined : f.severity == 'warning' ? Icons.warning_amber_rounded : Icons.info_outline,
                  size: 18,
                  color: f.severity == 'danger'
                      ? ErpColors.statusCancelledText
                      : f.severity == 'warning'
                          ? ErpColors.statusPartialText
                          : ErpColors.statusOpenText,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(f.message, style: const TextStyle(fontSize: 12.5))),
              ]),
            ),
          if (_danger) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'How did you confirm it?',
                helperText: 'At least 8 characters — kept with the payment',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, _danger ? _note.text.trim() : '') : null,
          child: Text(widget.flags.any((f) => f.severity != 'info') ? '${widget.confirm} anyway' : widget.confirm),
        ),
      ],
    );
  }
}
