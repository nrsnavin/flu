import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/pdf_preview_page.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/invoice_controllers.dart';
import '../gst.dart';
import '../models/invoice_models.dart';
import 'invoice_widgets.dart';

final _day = DateFormat('dd MMM yyyy');

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late final InvoiceDetailController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(InvoiceDetailController(widget.invoiceId), tag: widget.invoiceId);
  }

  @override
  void dispose() {
    Get.delete<InvoiceDetailController>(tag: widget.invoiceId, force: true);
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ErpColors.solidError : ErpColors.solidSuccess,
      duration: Duration(seconds: msg.length > 80 ? 7 : 4),
    ));
  }

  Future<void> _openPdf(Invoice inv) async {
    final r = await c.pdf();
    if (r.error != null) return _toast(r.error!, error: true);
    if (r.bytes == null || !mounted) return;
    await Get.to(() => DocumentPdfPage(
          bytes: r.bytes!,
          title: 'Invoice ${inv.invoiceNumber}',
          subtitle: inv.buyer.name,
        ));
  }

  Future<void> _cancel(Invoice inv) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(invoice: inv),
    );
    if (reason == null) return;
    final r = await c.cancel(reason);
    if (r.message.isNotEmpty) _toast(r.message, error: !r.ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        elevation: 0,
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.invoice.value?.invoiceNumber ?? 'Invoice', style: ErpTextStyles.pageTitle),
                Text('Invoices  ›  Detail',
                    style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
              ],
            )),
        actions: [
          Obx(() {
            final inv = c.invoice.value;
            if (inv == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Invoice PDF',
              onPressed: c.isFetchingPdf.value ? null : () => _openPdf(inv),
              icon: c.isFetchingPdf.value
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_outlined),
            );
          }),
        ],
      ),
      body: Obx(() {
        final inv = c.invoice.value;
        if (c.isLoading.value && inv == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (inv == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.errorMsg.value ?? 'Invoice not found',
                    textAlign: TextAlign.center, style: TextStyle(color: ErpColors.textSecondary)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: c.fetch, child: const Text('Try again')),
              ]),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              _Billboard(invoice: inv),
              if (inv.isCancelled) ...[
                const SizedBox(height: 10),
                _Banner(
                  icon: Icons.block,
                  color: ErpColors.errorRed,
                  bg: ErpColors.statusCancelledBg,
                  text: inv.cancelReason.isEmpty ? 'Cancelled' : 'Cancelled: ${inv.cancelReason}',
                ),
              ],
              if (!inv.isCancelled) ...[
                const SizedBox(height: 10),
                _Money(invoice: inv),
              ],
              const SizedBox(height: 10),
              _Actions(
                invoice: inv,
                busyPdf: c.isFetchingPdf.value,
                busyCancel: c.isCancelling.value,
                onPdf: () => _openPdf(inv),
                onCancel: () => _cancel(inv),
              ),
              const SizedBox(height: 12),
              _Parties(invoice: inv),
              const SizedBox(height: 10),
              _Lines(invoice: inv),
              const SizedBox(height: 10),
              _Totals(invoice: inv),
              const SizedBox(height: 10),
              _Einvoice(invoice: inv),
              if (inv.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                ErpSectionCard(
                  title: 'Notes',
                  icon: Icons.notes_outlined,
                  child: Text(inv.notes, style: TextStyle(color: ErpColors.textPrimary, fontSize: 13)),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// The grand total first and largest: it is the number somebody opened
/// the invoice to read.
class _Billboard extends StatelessWidget {
  const _Billboard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ErpColors.navyDark, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(inv.buyer.name.isEmpty ? inv.customerName : inv.buyer.name,
              style: TextStyle(color: ErpColors.textOnDark, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            [
              inv.invoiceNumber,
              if (inv.invoiceDate != null) _day.format(inv.invoiceDate!),
              inv.taxLabel,
            ].join('  ·  '),
            style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Text(
            inr(inv.totals.grand),
            style: TextStyle(
              color: inv.isCancelled ? ErpColors.textOnDarkSub : ErpColors.textOnDark,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              decoration: inv.isCancelled ? TextDecoration.lineThrough : null,
              decorationColor: ErpColors.textOnDarkSub,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (inv.amountInWords.isNotEmpty)
            Text(inv.amountInWords,
                style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 11, height: 1.3)),
          const SizedBox(height: 12),
          InvoiceChips(invoice: inv),
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final pay = paymentLine(inv);
    return ErpSectionCard(
      title: 'Money in',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(children: [
        InvoiceRow('Invoice total', inr(inv.totals.grand)),
        if (inv.paidAmount > 0) InvoiceRow('Received', inr(inv.paidAmount)),
        if (inv.creditedAmount > 0) InvoiceRow('Credit notes', inr(inv.creditedAmount)),
        if (inv.debitedAmount > 0) InvoiceRow('Debit notes', inr(inv.debitedAmount)),
        if (inv.dueDate != null) InvoiceRow('Due', _day.format(inv.dueDate!)),
        const Divider(height: 14),
        InvoiceRow(
          inv.paymentState == PaymentState.paid ? 'Settled' : 'Owed',
          inv.paymentState == PaymentState.paid ? 'Paid' : inr(inv.owed),
          bold: true,
          color: pay.late ? ErpColors.errorRed : null,
        ),
        if (inv.paymentState != PaymentState.paid)
          Align(
            alignment: Alignment.centerRight,
            child: Text(pay.text.split(' · ').last,
                style: TextStyle(
                    fontSize: 11.5,
                    color: pay.late ? ErpColors.errorRed : ErpColors.textMuted,
                    fontWeight: pay.late ? FontWeight.w700 : FontWeight.w400)),
          ),
      ]),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.invoice,
    required this.busyPdf,
    required this.busyCancel,
    required this.onPdf,
    required this.onCancel,
  });

  final Invoice invoice;
  final bool busyPdf, busyCancel;
  final VoidCallback onPdf, onCancel;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    // The server refuses to cancel an invoice with money set against
    // it; saying so here beats a button that fails.
    final moneyAgainst = inv.paidAmount > 0 || inv.creditedAmount > 0 || inv.debitedAmount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: busyPdf ? null : onPdf,
          icon: busyPdf
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Open PDF to share or print'),
          style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (!inv.isCancelled) ...[
          const SizedBox(height: 6),
          if (moneyAgainst)
            Text(
              'Receipts or credit / debit notes are set against this invoice, so it cannot be cancelled until those are.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
            )
          else
            TextButton.icon(
              onPressed: busyCancel ? null : onCancel,
              icon: busyCancel
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.cancel_outlined, size: 18, color: ErpColors.errorRed),
              label: Text('Cancel invoice…', style: TextStyle(color: ErpColors.errorRed)),
            ),
        ],
      ],
    );
  }
}

class _Parties extends StatelessWidget {
  const _Parties({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final b = inv.buyer;
    final sameShip = inv.shipTo.trim().isEmpty || inv.shipTo.trim() == b.place.replaceAll('\n', ', ').trim();
    Text label(String s) => Text(s.toUpperCase(),
        style: TextStyle(fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: ErpColors.textMuted));
    final body = TextStyle(fontSize: 13, color: ErpColors.textPrimary, height: 1.35);
    return ErpSectionCard(
      title: 'Parties',
      icon: Icons.storefront_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label('Billed to'),
          const SizedBox(height: 3),
          Text(b.name, style: body.copyWith(fontWeight: FontWeight.w700)),
          if (b.gstin.isNotEmpty) Text('GSTIN ${b.gstin}', style: body),
          if (b.place.isNotEmpty) Text(b.place, style: body.copyWith(color: ErpColors.textSecondary)),
          if (!sameShip) ...[
            const SizedBox(height: 10),
            label('Shipped to'),
            const SizedBox(height: 3),
            Text(inv.shipTo, style: body.copyWith(color: ErpColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          label('Order'),
          const SizedBox(height: 3),
          Text(
            [
              if (inv.orderNo != null) 'Order #${inv.orderNo}',
              if (inv.customerPo.isNotEmpty) 'PO ${inv.customerPo}',
            ].join('  ·  '),
            style: body,
          ),
          if (inv.dcNumbers.isNotEmpty) ...[
            const SizedBox(height: 10),
            label('Challans'),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in inv.dcNumbers) invoiceChip(n, ErpColors.bgMuted, ErpColors.textSecondary),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    return ErpSectionCard(
      title: 'Lines',
      icon: Icons.list_alt_outlined,
      trailing: Text('${inv.lines.length}', style: TextStyle(color: ErpColors.textMuted, fontSize: 12)),
      child: Column(
        children: [
          for (final l in inv.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${qty(l.quantity)} ${l.unit} × ${inr(l.rate)}',
                            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
                        Text(
                          [
                            if (l.hsn.isNotEmpty) 'HSN ${l.hsn}',
                            'GST ${qty(l.gstPercent)}%',
                            if (l.boxes > 0) '${l.boxes} box${l.boxes == 1 ? '' : 'es'}',
                          ].join('  ·  '),
                          style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(inr(l.amount),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final t = invoice.totals;
    return ErpSectionCard(
      title: 'Totals',
      icon: Icons.calculate_outlined,
      child: Column(children: [
        InvoiceRow('Taxable value', inr(t.taxable)),
        if (t.cgst > 0 || t.sgst > 0) ...[
          InvoiceRow('CGST', inr(t.cgst)),
          InvoiceRow('SGST', inr(t.sgst)),
        ],
        if (t.igst > 0) InvoiceRow('IGST', inr(t.igst)),
        if (t.roundOff != 0) InvoiceRow('Round off', inr(t.roundOff)),
        const Divider(height: 14),
        InvoiceRow('Grand total', inr(t.grand), bold: true),
      ]),
    );
  }
}

class _Einvoice extends StatelessWidget {
  const _Einvoice({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final pending = !inv.irnRegistered && inv.einvoiceStatus != 'cancelled' && !inv.isCancelled;
    return ErpSectionCard(
      title: 'e-Invoice and e-way bill',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvoiceRow('IRN', switch (inv.einvoiceStatus) {
            'registered' => 'Registered',
            'cancelled' => 'Cancelled',
            _ => 'Not registered yet',
          }),
          if (inv.irn.isNotEmpty)
            GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: inv.irn));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IRN copied')));
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(inv.irn,
                    style: TextStyle(fontSize: 10.5, color: ErpColors.textSecondary, fontFamily: 'monospace')),
              ),
            ),
          if (inv.ackNo.isNotEmpty)
            InvoiceRow('Ack no.',
                [inv.ackNo, if (inv.ackDate != null) _day.format(inv.ackDate!)].join('  ·  ')),
          InvoiceRow(
            'E-way bill',
            inv.ewaybillNumber.isEmpty
                ? 'Not generated'
                : [
                    inv.ewaybillNumber,
                    if (inv.ewaybillValidUpto != null) 'valid to ${_day.format(inv.ewaybillValidUpto!)}',
                  ].join('  ·  '),
          ),
          if (pending && inv.einvoiceProblems.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Banner(
              icon: Icons.warning_amber_rounded,
              color: ErpColors.statusPartialText,
              bg: ErpColors.statusPartialBg,
              text: 'The e-invoice portal will refuse this until it is fixed:\n'
                  '${inv.einvoiceProblems.map((p) => '•  $p').join('\n')}',
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 6),
            Text('The IRN and the e-way bill are registered on the web, where the GST portal connection is set up.',
                style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.bg, required this.text});

  final IconData icon;
  final Color color, bg;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.35))),
          ],
        ),
      );
}

/// Cancelling cannot be undone and the IRN goes with it, so the dialog
/// says both and wants a reason the audit trail can keep (eight
/// characters at least, as the server requires).
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.invoice});

  final Invoice invoice;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ctrl.text.trim().length >= 8;
    return AlertDialog(
      title: Text('Cancel ${widget.invoice.invoiceNumber}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.invoice.irnRegistered
                ? 'The IRN is cancelled with it. The challans on it can go on a new invoice. This cannot be undone.'
                : 'The challans on it can go on a new invoice. This cannot be undone.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Why it is being cancelled (at least 8 characters)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep it')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ErpColors.errorRed),
          onPressed: ok ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
          child: const Text('Cancel invoice'),
        ),
      ],
    );
  }
}
