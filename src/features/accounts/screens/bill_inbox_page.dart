import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../../core/pdf_preview_page.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/accounts_models.dart';
import '../services/accounts_api.dart';
import 'accounts_widgets.dart';

final _day = DateFormat('dd MMM yyyy');
final _when = DateFormat('dd MMM, h:mm a');

// ══════════════════════════════════════════════════════════════
//  THE BILLS MAILBOX
//
//  Supplier bills mailed to the company, already read by the server:
//  who sent it, the bill number and amount it found, and whether that
//  bill is in the books already. On the phone: look at it, and dismiss
//  what is not a bill to enter (a duplicate, a statement, not ours).
//  Entering one — GST, lines, the purchase order — is done on the web.
// ══════════════════════════════════════════════════════════════

class BillInboxPage extends StatefulWidget {
  const BillInboxPage({super.key});

  @override
  State<BillInboxPage> createState() => _BillInboxPageState();
}

class _BillInboxPageState extends State<BillInboxPage> {
  List<MailedBill>? _bills;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await AccountsApi.mailedBills();
      if (mounted) setState(() => _bills = b);
    } catch (e) {
      if (mounted) setState(() => _error = accountsMessage(e, 'Could not load the mailbox'));
    }
  }

  Future<void> _open(MailedBill b) async {
    final changed = await Get.to<bool>(() => MailedBillPage(bill: b));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final bills = _bills;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar('Bills mailbox', subtitle: 'Supplier bills read from mail'),
      body: bills == null
          ? (_error == null ? const Center(child: CircularProgressIndicator()) : accountsCentred(_error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: bills.isEmpty
                  ? accountsCentred('No bills are waiting in the mailbox.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: bills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _card(bills[i]),
                    ),
            ),
    );
  }

  Widget _card(MailedBill b) {
    return AccountsCard(
      onTap: () => _open(b),
      borderColor: b.alreadyEntered != null ? ErpColors.statusCancelledBorder : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(b.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, size: 20, color: ErpColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(b.supplierName.isNotEmpty ? b.supplierName : b.from,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          ),
          if (b.grand != null)
            Text(inr(b.grand!), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
        ]),
        const SizedBox(height: 3),
        Text(
          [
            if (b.billNo.isNotEmpty) 'Bill ${b.billNo}',
            if (b.receivedAt != null) 'mailed ${_when.format(b.receivedAt!)}',
          ].join(' · '),
          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
        ),
        if (b.subject.isNotEmpty)
          Text(b.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: ErpColors.textSecondary)),
        if (b.alreadyEntered != null || !b.senderKnown || !b.supplierMatched) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (b.alreadyEntered != null)
              accountsChip('Already entered as ${b.alreadyEntered}', ErpColors.statusCancelledBg, ErpColors.statusCancelledText),
            if (!b.senderKnown) accountsChip('Sender not on file', ErpColors.statusPartialBg, ErpColors.statusPartialText),
            if (!b.supplierMatched) accountsChip('Supplier not matched', ErpColors.statusPartialBg, ErpColors.statusPartialText),
          ]),
        ],
      ]),
    );
  }
}

/// One mailed bill: what was read from it, the file itself, and a way
/// to dismiss it. Pops true when it was dismissed.
class MailedBillPage extends StatefulWidget {
  const MailedBillPage({super.key, required this.bill});

  final MailedBill bill;

  @override
  State<MailedBillPage> createState() => _MailedBillPageState();
}

class _MailedBillPageState extends State<MailedBillPage> {
  late final Future<Uint8List> _file = AccountsApi.mailedBillFile(widget.bill.id);
  bool _busy = false;

  Future<void> _dismiss() async {
    final b = widget.bill;
    final reason = await askReason(
      context,
      title: 'Dismiss this bill?',
      message: 'It leaves the mailbox and is not entered. Say why — a duplicate, a statement, not ours.',
      confirm: 'Dismiss',
      minLength: 3,
      hint: 'Why',
      confirmColor: ErpColors.errorRed,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await AccountsApi.dismissMailedBill(b.id, reason);
      if (!mounted) return;
      accountsToast(context, 'Dismissed');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) accountsToast(context, accountsMessage(e, 'It was not dismissed'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final title = b.supplierName.isNotEmpty ? b.supplierName : b.from;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar(b.billNo.isNotEmpty ? 'Bill ${b.billNo}' : 'Mailed bill', subtitle: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (b.alreadyEntered != null)
            _notice(Icons.content_copy_rounded, 'This bill is already in the books as ${b.alreadyEntered}. Dismiss this copy.',
                ErpColors.statusCancelledBg, ErpColors.statusCancelledText),
          if (!b.senderKnown)
            _notice(Icons.mark_email_read_outlined,
                'The sender, ${b.from}, is not on any supplier\'s file. Check the bill is genuine before it is entered.',
                ErpColors.statusPartialBg, ErpColors.statusPartialText),
          AccountsCard(
            child: Column(children: [
              _fact('Supplier', b.supplierName.isNotEmpty ? b.supplierName : 'Not matched to a supplier'),
              _fact('From', b.from),
              if (b.subject.isNotEmpty) _fact('Subject', b.subject),
              if (b.receivedAt != null) _fact('Mailed', _when.format(b.receivedAt!)),
              if (b.billNo.isNotEmpty) _fact('Bill number', b.billNo),
              if (b.billDate != null) _fact('Bill date', _day.format(b.billDate!)),
              if (b.grand != null) _fact('Amount', inr(b.grand!)),
            ]),
          ),
          const SizedBox(height: 14),
          accountsLabel('The bill'),
          FutureBuilder<Uint8List>(
            future: _file,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              final bytes = snap.data;
              if (snap.hasError || bytes == null || bytes.isEmpty) {
                return AccountsCard(
                  child: Text(snap.hasError ? accountsMessage(snap.error!, 'Could not load the file') : 'The file is empty',
                      style: TextStyle(color: ErpColors.errorRed)),
                );
              }
              if (b.isImage) {
                return GestureDetector(
                  onTap: () => Get.to(() => _ImageViewer(bytes: bytes, title: title)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes, fit: BoxFit.contain, height: 360),
                  ),
                );
              }
              return AccountsCard(
                onTap: () => Get.to(() => DocumentPdfPage(
                      bytes: bytes,
                      title: b.filename.isNotEmpty ? b.filename : 'Bill ${b.billNo}',
                      subtitle: title,
                    )),
                child: Row(children: [
                  Icon(Icons.picture_as_pdf_outlined, color: ErpColors.errorRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(b.filename.isNotEmpty ? b.filename : 'Open the bill',
                        style: TextStyle(fontWeight: FontWeight.w600, color: ErpColors.textPrimary)),
                  ),
                  Text('Open', style: TextStyle(color: ErpColors.accentBlue, fontWeight: FontWeight.w600)),
                ]),
              );
            },
          ),
          const SizedBox(height: 14),
          Text('To enter it, open Accounts → Bills mailbox on the web, where its GST and lines are checked against the purchase order.',
              style: TextStyle(fontSize: 12, color: ErpColors.textMuted)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _dismiss,
            style: OutlinedButton.styleFrom(
              foregroundColor: ErpColors.errorRed,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.block_rounded, size: 18),
            label: const Text('Dismiss…'),
          ),
        ),
      ),
    );
  }

  Widget _notice(IconData icon, String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: fg, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _fact(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(label, style: TextStyle(fontSize: 12, color: ErpColors.textMuted))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: ErpColors.textPrimary))),
        ]),
      );
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title)),
        body: InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(bytes))),
      );
}
