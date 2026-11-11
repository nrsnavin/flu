import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/accounts_models.dart';
import '../services/accounts_api.dart';
import 'accounts_widgets.dart';
import 'voucher_entry_page.dart';

final _day = DateFormat('dd MMM yyyy');

// ══════════════════════════════════════════════════════════════
//  COLLECTIONS
//
//  Customers with money overdue, in the order the server would chase
//  them, each with the next step it suggests. From a customer: send a
//  reminder (written by the server, edited here, sent on the company's
//  WhatsApp line to the number on file), note a call or a promise to
//  pay, or record the money when it comes.
// ══════════════════════════════════════════════════════════════

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<CollectionRow>? _rows;
  bool _whatsapp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await AccountsApi.collections();
      if (!mounted) return;
      setState(() {
        _rows = r.rows;
        _whatsapp = r.whatsapp;
      });
    } catch (e) {
      if (mounted) setState(() => _error = accountsMessage(e, 'Could not load the collections'));
    }
  }

  Future<void> _open(CollectionRow r) async {
    await Get.to(() => CollectionDetailPage(row: r, whatsapp: _whatsapp));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar('Collections', subtitle: 'Money overdue from customers'),
      body: rows == null
          ? (_error == null ? const Center(child: CircularProgressIndicator()) : accountsCentred(_error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: rows.isEmpty
                  ? accountsCentred('No customer is overdue.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        _summary(rows),
                        const SizedBox(height: 10),
                        for (final r in rows) ...[
                          _card(r),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _summary(List<CollectionRow> rows) {
    final chase = rows.where((r) => !r.held).toList();
    final overdue = chase.fold(0.0, (s, r) => s + r.overdue);
    final promised = rows.length - chase.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ErpColors.navyDark, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OVERDUE TO CHASE',
            style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10, letterSpacing: 0.7, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(inr0(overdue), style: TextStyle(color: ErpColors.textOnDark, fontSize: 24, fontWeight: FontWeight.w800)),
        Text(
          [
            '${chase.length} ${chase.length == 1 ? 'customer' : 'customers'}',
            if (promised > 0) '$promised promised to pay',
          ].join(' · '),
          style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _card(CollectionRow r) {
    return AccountsCard(
      onTap: () => _open(r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(r.partyName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          ),
          Text(inr0(r.overdue), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ErpColors.errorRed)),
        ]),
        const SizedBox(height: 2),
        Text(
          '${r.docs.length} overdue · oldest ${r.oldestDays} days${r.total > r.overdue ? ' · ${inr0(r.total)} owed in all' : ''}',
          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (r.held && r.promiseDate != null)
            accountsChip('Promised by ${_day.format(r.promiseDate!)}', ErpColors.statusCompletedBg, ErpColors.statusCompletedText)
          else if (r.promiseBroken && r.promiseDate != null)
            accountsChip('Promise of ${_day.format(r.promiseDate!)} broken', ErpColors.statusCancelledBg, ErpColors.statusCancelledText),
          if (r.recentlyContacted && !r.held) accountsChip('Contacted this week', ErpColors.statusOpenBg, ErpColors.statusOpenText),
          if (r.nextLabel.isNotEmpty && !r.held) accountsChip(r.nextLabel, ErpColors.statusPartialBg, ErpColors.statusPartialText),
        ]),
      ]),
    );
  }
}

/// One customer: what is overdue, who to talk to, what was said last,
/// and the things to do about it.
class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({super.key, required this.row, required this.whatsapp});

  final CollectionRow row;
  final bool whatsapp;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late CollectionRow _row = widget.row;
  bool _busy = false;
  bool _paidOff = false;

  /// The customer's row again, after something was logged or paid.
  Future<void> _refresh() async {
    try {
      final r = await AccountsApi.collections();
      if (!mounted) return;
      final again = r.rows.where((x) => x.party == _row.party).firstOrNull;
      setState(() {
        if (again != null) _row = again;
        _paidOff = again == null;
      });
    } catch (_) {
      // The list behind shows the truth when this page closes.
    }
  }

  Future<void> _logCall() async {
    final note = await askReason(
      context,
      title: 'Log a call',
      message: 'What did ${_row.contactName.isNotEmpty ? _row.contactName : _row.partyName} say?',
      confirm: 'Save',
      minLength: 3,
      hint: 'What was said',
    );
    if (note == null) return;
    await _save(() => AccountsApi.logCollection(customer: _row.party, kind: 'call', note: note), 'Call noted');
  }

  Future<void> _logPromise() async {
    final p = await showDialog<({DateTime date, double? amount, String note})>(
      context: context,
      builder: (_) => _PromiseDialog(overdue: _row.overdue),
    );
    if (p == null) return;
    await _save(
      () => AccountsApi.logCollection(
          customer: _row.party, kind: 'promise', promiseDate: p.date, promiseAmount: p.amount, note: p.note),
      'Promise noted — not chased till ${_day.format(p.date)}',
    );
  }

  Future<void> _save(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      accountsToast(context, done);
      await _refresh();
    } catch (e) {
      if (mounted) accountsToast(context, accountsMessage(e, 'That was not saved'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remind() async {
    final sent = await Get.to<bool>(() => ReminderPage(row: _row, whatsapp: widget.whatsapp));
    if (sent == true) await _refresh();
  }

  Future<void> _receive() async {
    final v = await Get.to(() => VoucherEntryPage(kind: 'receipt', party: Party(id: _row.party, name: _row.partyName)));
    if (v != null) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final r = _row;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar(r.partyName, subtitle: 'Collections'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (_paidOff)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AccountsCard(
                borderColor: ErpColors.successGreen,
                child: Text('Nothing is overdue from ${r.partyName} any more.',
                    style: TextStyle(color: ErpColors.successGreen, fontWeight: FontWeight.w600)),
              ),
            ),
          AccountsCard(
            child: Row(children: [
              Expanded(child: _figure('Overdue', inr(r.overdue), ErpColors.errorRed)),
              Expanded(child: _figure('Owed in all', inr(r.total), ErpColors.textPrimary)),
              Expanded(child: _figure('Oldest', '${r.oldestDays} days', ErpColors.textPrimary)),
            ]),
          ),
          if (r.onAccount > 0) ...[
            const SizedBox(height: 8),
            AccountsCard(
              child: Text('${inr(r.onAccount)} paid ahead is on their account — set it off on the web before chasing.',
                  style: TextStyle(fontSize: 12.5, color: ErpColors.textSecondary)),
            ),
          ],
          const SizedBox(height: 14),
          accountsLabel('Next step'),
          AccountsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.held && r.promiseDate != null)
                Text('They promised ${r.promiseAmount > 0 ? '${inr(r.promiseAmount)} ' : ''}by ${_day.format(r.promiseDate!)} — not chased till then.',
                    style: TextStyle(fontSize: 13, color: ErpColors.successGreen, fontWeight: FontWeight.w600))
              else ...[
                Text(r.nextLabel.isEmpty ? 'Send a reminder' : r.nextLabel,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                if (r.promiseBroken && r.promiseDate != null)
                  Text('They promised to pay by ${_day.format(r.promiseDate!)}${r.promiseNote.isNotEmpty ? ' — "${r.promiseNote}"' : ''}.',
                      style: TextStyle(fontSize: 12, color: ErpColors.errorRed)),
              ],
              if (r.lastContact.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Last: ${r.lastContact}${r.lastContactAt != null ? ' on ${_day.format(r.lastContactAt!)}' : ''}'
                  '${r.lastNote.isNotEmpty ? ' — "${r.lastNote}"' : ''}',
                  style: TextStyle(fontSize: 12, color: ErpColors.textMuted),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          accountsLabel('Who to talk to'),
          AccountsCard(
            child: Row(children: [
              Icon(Icons.person_outline, color: ErpColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.contactName.isNotEmpty ? r.contactName : 'No contact on file',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ErpColors.textPrimary)),
                  Text(r.phone.isNotEmpty ? r.phone : 'No phone number on file',
                      style: TextStyle(fontSize: 12, color: ErpColors.textMuted)),
                ]),
              ),
              if (r.phone.isNotEmpty)
                IconButton(
                  tooltip: 'Copy the number',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: r.phone));
                    accountsToast(context, 'Number copied');
                  },
                ),
            ]),
          ),
          const SizedBox(height: 14),
          accountsLabel('Overdue'),
          AccountsCard(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            child: Column(children: [
              for (final (i, d) in r.docs.indexed) ...[
                if (i > 0) Divider(height: 1, color: ErpColors.borderLight),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d.kindLabel} ${d.docNo}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ErpColors.textPrimary)),
                        Text(
                          [
                            if (d.refNo.isNotEmpty) 'Ref ${d.refNo}',
                            if (d.date != null) _day.format(d.date!),
                            if (d.overdueDays > 0) '${d.overdueDays} days overdue',
                          ].join(' · '),
                          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
                        ),
                      ]),
                    ),
                    Text(inr(d.outstanding),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            border: Border(top: BorderSide(color: ErpColors.borderLight)),
          ),
          child: _busy
              ? const LinearProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _remind,
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('Send a reminder'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _receive,
                        icon: const Icon(Icons.south_west_rounded, size: 18),
                        label: const Text('Record payment'),
                      ),
                    ),
                  ]),
                  Row(children: [
                    Expanded(child: TextButton(onPressed: _logCall, child: const Text('Log a call'))),
                    Expanded(child: TextButton(onPressed: _logPromise, child: const Text('Log a promise'))),
                  ]),
                ]),
        ),
      ),
    );
  }

  Widget _figure(String label, String value, Color colour) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 9.5, letterSpacing: 0.5, fontWeight: FontWeight.w700, color: ErpColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colour)),
      ]);
}

/// When they said they would pay, how much, and anything else said.
class _PromiseDialog extends StatefulWidget {
  const _PromiseDialog({required this.overdue});

  final double overdue;

  @override
  State<_PromiseDialog> createState() => _PromiseDialogState();
}

class _PromiseDialogState extends State<_PromiseDialog> {
  DateTime? _date;
  late final _amount = TextEditingController(text: widget.overdue.toStringAsFixed(2));
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 120)),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log a promise to pay'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: _pick,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'They will pay by',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(_date == null ? 'Choose the day' : _day.format(_date!)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(
          onPressed: _date == null
              ? null
              : () => Navigator.pop(context, (
                    date: _date!,
                    amount: double.tryParse(_amount.text.replaceAll(',', '').trim()),
                    note: _note.text.trim(),
                  )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// A reminder written by the server in the tone asked for, edited here,
/// and sent on the company's WhatsApp line — or copied, to send by hand.
class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key, required this.row, required this.whatsapp});

  final CollectionRow row;
  final bool whatsapp;

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  late String _tone = widget.row.nextTone == 'firm' ? 'firm' : 'gentle';
  final _message = TextEditingController();
  String _to = '';
  bool _drafting = false;
  bool _sending = false;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _draft();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    final seq = ++_seq;
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final d = await AccountsApi.draftReminder(widget.row.party, tone: _tone);
      if (!mounted || seq != _seq) return;
      setState(() {
        _message.text = d.message;
        _to = d.to;
      });
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = accountsMessage(e, 'Could not write the reminder'));
    } finally {
      if (mounted && seq == _seq) setState(() => _drafting = false);
    }
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final r = await AccountsApi.sendReminder(
          to: _to, message: _message.text.trim(), customer: widget.row.party, tone: _tone);
      if (!mounted) return;
      if (r.sent) {
        accountsToast(context, 'Sent to $_to on WhatsApp');
        Navigator.of(context).pop(true);
      } else if (r.dryRun) {
        accountsToast(context, 'Not sent — WhatsApp is not connected on the server. Copy the message and send it by hand.',
            error: true);
      } else {
        accountsToast(context, r.error.isEmpty ? 'WhatsApp did not take the message' : 'Not sent: ${r.error}', error: true);
      }
    } catch (e) {
      if (mounted) accountsToast(context, accountsMessage(e, 'The reminder was not sent'), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.whatsapp && _to.isNotEmpty && _message.text.trim().length >= 20 && !_drafting && !_sending;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar('Reminder', subtitle: widget.row.partyName),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gentle', label: Text('Gentle')),
              ButtonSegment(value: 'firm', label: Text('Firm')),
            ],
            selected: {_tone},
            onSelectionChanged: _drafting
                ? null
                : (s) {
                    setState(() => _tone = s.first);
                    _draft();
                  },
          ),
          const SizedBox(height: 12),
          if (_drafting) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text('Writing the reminder…', style: TextStyle(fontSize: 12, color: ErpColors.textMuted)),
            const SizedBox(height: 6),
          ],
          if (_error != null)
            AccountsCard(
              child: Row(children: [
                Expanded(child: Text(_error!, style: TextStyle(color: ErpColors.errorRed))),
                TextButton(onPressed: _draft, child: const Text('Try again')),
              ]),
            ),
          TextField(
            controller: _message,
            minLines: 8,
            maxLines: 16,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: ErpColors.bgSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _to.isNotEmpty
                ? 'To $_to — the number on file'
                : 'No phone number on file for ${widget.row.partyName}. Add one to the customer to send from here.',
            style: TextStyle(fontSize: 12, color: _to.isEmpty ? ErpColors.warningAmber : ErpColors.textMuted),
          ),
          if (!widget.whatsapp)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('WhatsApp is not connected on the server — copy the message and send it from your phone.',
                  style: TextStyle(fontSize: 12, color: ErpColors.textMuted)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _message.text.trim().isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: _message.text.trim()));
                        accountsToast(context, 'Message copied');
                      },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
            ),
            if (widget.whatsapp) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: canSend ? _send : null,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send on WhatsApp'),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
