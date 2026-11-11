import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../authentication/controllers/login_controller.dart';
import '../controllers/invoice_controllers.dart';
import '../gst.dart';
import '../services/invoice_api.dart';
import 'invoice_detail_page.dart';
import 'invoice_widgets.dart';

final _day = DateFormat('dd MMM yyyy');

/// Raise a tax invoice for an order. Opened from the order's Invoices
/// card; returns the new invoice's id when one was raised.
class RaiseInvoicePage extends StatefulWidget {
  const RaiseInvoicePage({super.key, required this.orderId});

  final String orderId;

  @override
  State<RaiseInvoicePage> createState() => _RaiseInvoicePageState();
}

class _RaiseInvoicePageState extends State<RaiseInvoicePage> {
  late final RaiseInvoiceController c;

  // The rate, HSN and GST fields keep what was typed across rebuilds.
  final _rate = <String, TextEditingController>{};
  final _hsn = <String, TextEditingController>{};
  final _gst = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    c = Get.put(RaiseInvoiceController(widget.orderId), tag: widget.orderId);
  }

  @override
  void dispose() {
    for (final m in [_rate, _hsn, _gst]) {
      for (final t in m.values) {
        t.dispose();
      }
    }
    Get.delete<RaiseInvoiceController>(tag: widget.orderId, force: true);
    super.dispose();
  }

  TextEditingController _field(Map<String, TextEditingController> m, String key, String initial) =>
      m.putIfAbsent(key, () => TextEditingController(text: initial));

  String _num(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  bool get _isAdmin => LoginController.find.user.value.role.toLowerCase() == 'admin';

  Future<void> _raise() async {
    final info = c.info.value;
    if (info == null || !c.canRaise) return;
    final grand = c.priced.totals.grand;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raise this invoice?'),
        content: Text(
          '${inr(grand)} to ${info.buyer.name}, for ${c.selected.length} challan${c.selected.length == 1 ? '' : 's'}.\n\n'
          'It goes on the customer\'s account at once and can be cancelled, not edited.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Raise invoice')),
        ],
      ),
    );
    if (go != true) return;
    await _submit();
  }

  Future<void> _submit({String? creditOverride}) async {
    try {
      final inv = await c.raise(creditOverride: creditOverride);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invoice ${inv.invoiceNumber} raised'),
        backgroundColor: ErpColors.solidSuccess,
      ));
      Get.off(() => InvoiceDetailPage(invoiceId: inv.id));
    } catch (e) {
      if (!mounted) return;
      if (isCreditHold(e)) return _creditHold(invoiceMessage(e, 'The customer is on credit hold.'));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(invoiceMessage(e, 'Could not raise the invoice')),
        backgroundColor: ErpColors.solidError,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  /// On credit hold: an admin may release this one invoice with a
  /// reason, which the server records; anyone else is told why not.
  Future<void> _creditHold(String message) async {
    if (!_isAdmin) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Customer on credit hold'),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _OverrideDialog(message: message),
    );
    if (reason != null) await _submit(creditOverride: reason);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: c.invoiceDate.value,
      firstDate: DateTime(now.year - 1, 4, 1),
      lastDate: now,
    );
    if (d != null) c.invoiceDate.value = d;
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
                Text('Raise invoice', style: ErpTextStyles.pageTitle),
                Text(
                  c.info.value?.orderNo == null ? 'Order' : 'Order #${c.info.value!.orderNo}',
                  style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10),
                ),
              ],
            )),
      ),
      body: Obx(() {
        final info = c.info.value;
        if (c.isLoading.value && info == null) return const Center(child: CircularProgressIndicator());
        if (info == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.errorMsg.value ?? 'Could not load the order',
                    textAlign: TextAlign.center, style: TextStyle(color: ErpColors.textSecondary)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: c.load, child: const Text('Try again')),
              ]),
            ),
          );
        }
        // Read every observable the lazy parts depend on, here.
        final lines = c.lines;
        final priced = c.priced;
        final selected = c.selected.toSet();
        final inter = info.supplyType != 'intra';
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
          children: [
            _card(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.buyer.name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (info.orderNo != null) 'Order #${info.orderNo}',
                    if (info.po.isNotEmpty) 'PO ${info.po}',
                  ].join('  ·  '),
                  style: TextStyle(fontSize: 12, color: ErpColors.textMuted),
                ),
                const SizedBox(height: 8),
                invoiceChip(
                  inter ? 'IGST — inter-state (${info.placeOfSupply})' : 'CGST + SGST — in-state',
                  inter ? ErpColors.statusOpenBg : ErpColors.bgMuted,
                  inter ? ErpColors.statusOpenText : ErpColors.textSecondary,
                ),
              ]),
            ),
            if (c.needsWeb) ...[
              const SizedBox(height: 10),
              _warn('This customer is set up for export or SEZ supplies. Raise this invoice on the web, '
                  'where the LUT, currency and port are entered.'),
            ],
            if (info.problems.isNotEmpty && !c.needsWeb) ...[
              const SizedBox(height: 10),
              _warn('The invoice can be raised, but the e-invoice portal will refuse it until this is fixed:\n'
                  '${info.problems.map((p) => '•  $p').join('\n')}'),
            ],
            const SizedBox(height: 14),
            _label('Delivery challans'),
            if (info.dcs.isEmpty)
              _muted('No challans have been raised against this order.')
            else
              _card(Column(children: [
                for (final dc in info.dcs)
                  CheckboxListTile(
                    value: selected.contains(dc.id),
                    onChanged: dc.eligible ? (_) => c.toggle(dc) : null,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(dc.dcNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                      [
                        if (dc.dispatchDate != null) _day.format(dc.dispatchDate!),
                        '${qty(dc.totalQuantity)} m',
                        if (dc.invoicedOn != null) 'on ${dc.invoicedOn}' else if (!dc.eligible) dc.status,
                      ].join('  ·  '),
                      style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
                    ),
                  ),
              ])),
            const SizedBox(height: 14),
            _label('Lines'),
            if (lines.isEmpty)
              _muted('Tick a challan to see its lines.')
            else
              for (final p in priced.lines) ...[
                _lineCard(p),
                const SizedBox(height: 8),
              ],
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 6),
              _card(Column(children: [
                InvoiceRow('Taxable value', inr(priced.totals.taxable)),
                if (!inter) ...[
                  InvoiceRow('CGST', inr(priced.totals.cgst)),
                  InvoiceRow('SGST', inr(priced.totals.sgst)),
                ] else
                  InvoiceRow('IGST', inr(priced.totals.igst)),
                if (priced.totals.roundOff != 0) InvoiceRow('Round off', inr(priced.totals.roundOff)),
                const Divider(height: 14),
                InvoiceRow('Grand total', inr(priced.totals.grand), bold: true),
              ])),
            ],
            const SizedBox(height: 14),
            _label('Details'),
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(Icons.event_outlined, size: 18, color: ErpColors.textSecondary),
                    const SizedBox(width: 8),
                    Text('Invoice date', style: TextStyle(fontSize: 13, color: ErpColors.textSecondary)),
                    const Spacer(),
                    Text(_day.format(c.invoiceDate.value),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: c.shipToCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Ship to', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: c.notesCtrl,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Notes on the invoice', border: OutlineInputBorder(), isDense: true),
              ),
            ])),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final info = c.info.value;
        if (info == null || c.needsWeb) return const SizedBox.shrink();
        final unpriced = c.unpriced;
        final grand = c.priced.totals.grand;
        final raising = c.isRaising.value;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              border: Border(top: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (unpriced.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Enter a rate for ${unpriced.map((l) => l.name).join(', ')}',
                      style: TextStyle(fontSize: 12, color: ErpColors.errorRed)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: c.canRaise ? _raise : null,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: raising
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(c.selected.isEmpty ? 'Tick a challan' : 'Raise invoice · ${inr(grand)}'),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _lineCard(PricedLine p) {
    final l = p.line;
    final noRate = !(l.rate > 0);
    final inputStyle = const TextStyle(fontSize: 13);
    InputDecoration deco(String label, {String? error}) => InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          errorText: error,
        );
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(l.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
        ),
        Text(inr(p.amount),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      const SizedBox(height: 2),
      Text('${qty(l.quantity)} ${l.unit}  ·  ${l.dcNumbers.join(', ')}',
          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: _field(_rate, l.elastic, _num(l.rate)),
            style: inputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: deco('Rate ₹/${l.unit}', error: noRate ? 'Enter a rate' : null),
            onChanged: (v) => c.setOverride(l.elastic, rate: double.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _field(_hsn, l.elastic, l.hsn),
            style: inputStyle,
            keyboardType: TextInputType.number,
            decoration: deco('HSN'),
            onChanged: (v) => c.setOverride(l.elastic, hsn: v.trim()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _field(_gst, l.elastic, _num(l.gstPercent)),
            style: inputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: deco('GST %'),
            onChanged: (v) => c.setOverride(l.elastic, gstPercent: double.tryParse(v) ?? 0),
          ),
        ),
      ]),
      if (l.rateSource == 'order' || l.rateSource == 'challan')
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Rate from the ${l.rateSource}', style: TextStyle(fontSize: 10.5, color: ErpColors.textMuted)),
        ),
    ]));
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: child,
      );

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(s.toUpperCase(),
            style: TextStyle(fontSize: 10.5, letterSpacing: 0.7, fontWeight: FontWeight.w700, color: ErpColors.textMuted)),
      );

  Widget _muted(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(s, style: TextStyle(fontSize: 12.5, color: ErpColors.textMuted)),
      );

  Widget _warn(String s) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: ErpColors.statusPartialBg, borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: ErpColors.statusPartialText),
          const SizedBox(width: 8),
          Expanded(child: Text(s, style: TextStyle(fontSize: 12.5, color: ErpColors.statusPartialText, height: 1.35))),
        ]),
      );
}

class _OverrideDialog extends StatefulWidget {
  const _OverrideDialog({required this.message});

  final String message;

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
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
      title: const Text('Customer on credit hold'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.message, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Reason to release this invoice',
            hintText: 'At least 8 characters; it is recorded on the invoice',
            border: OutlineInputBorder(),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
          child: const Text('Release and raise'),
        ),
      ],
    );
  }
}
