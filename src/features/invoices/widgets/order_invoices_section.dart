import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/features.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../authentication/services/nav_registry.dart';
import '../gst.dart';
import '../models/invoice_models.dart';
import '../screens/invoice_detail_page.dart';
import '../screens/invoice_widgets.dart';
import '../screens/raise_invoice_page.dart';
import '../services/invoice_api.dart';

final _day = DateFormat('dd MMM');

/// The order's invoices and the challans still to go on one, with the
/// way to raise it. Raising needs the Invoices permission; reading
/// comes with Orders, so the card shows for both and the button only
/// for the first.
class OrderInvoicesSection extends StatefulWidget {
  const OrderInvoicesSection({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderInvoicesSection> createState() => _OrderInvoicesSectionState();
}

class _OrderInvoicesSectionState extends State<OrderInvoicesSection> {
  OrderInvoices? _data;
  String? _error;
  bool _loading = true;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.orderId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await InvoiceApi.byOrder(widget.orderId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      // No access to invoices at all: nothing to show, not an error.
      if (e is DioException && e.response?.statusCode == 403) {
        setState(() => _hidden = true);
      } else {
        setState(() => _error = invoiceMessage(e, 'Could not load the invoices'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canRaise => hasFeature(NavRegistry.instance.features, '/invoices');

  Future<void> _raise() async {
    await Get.to(() => RaiseInvoicePage(orderId: widget.orderId));
    // Raised or not, the challans and invoices may have moved.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final d = _data;
    return ErpSectionCard(
      title: 'Invoices',
      icon: Icons.receipt_outlined,
      trailing: d == null || d.invoiced <= 0
          ? null
          : Text(inr0(d.invoiced), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ErpColors.textSecondary)),
      child: () {
        if (_loading && d == null) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (d == null) {
          return Row(children: [
            Expanded(child: Text(_error ?? '', style: TextStyle(fontSize: 12.5, color: ErpColors.textSecondary))),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.invoices.isEmpty)
              Text('No invoice raised for this order yet.',
                  style: TextStyle(fontSize: 12.5, color: ErpColors.textMuted)),
            for (final inv in d.invoices)
              InkWell(
                onTap: () async {
                  await Get.to(() => InvoiceDetailPage(invoiceId: inv.id));
                  _load();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          [inv.invoiceNumber, if (inv.invoiceDate != null) _day.format(inv.invoiceDate!)].join('  ·  '),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        InvoiceChips(invoice: inv),
                      ]),
                    ),
                    Text(inr(inv.totals.grand),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: inv.isCancelled ? ErpColors.textMuted : ErpColors.textPrimary,
                          decoration: inv.isCancelled ? TextDecoration.lineThrough : null,
                        )),
                    Icon(Icons.chevron_right, size: 18, color: ErpColors.textMuted),
                  ]),
                ),
              ),
            if (d.uninvoicedDcs.isNotEmpty) ...[
              const Divider(height: 18),
              Text(
                '${d.uninvoicedDcs.length} challan${d.uninvoicedDcs.length == 1 ? '' : 's'} not invoiced yet: '
                '${d.uninvoicedDcs.map((x) => x.dcNumber).join(', ')}',
                style: TextStyle(fontSize: 12.5, color: ErpColors.textSecondary),
              ),
              if (_canRaise) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _raise,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Raise invoice'),
                ),
              ],
            ],
          ],
        );
      }(),
    );
  }
}
