import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/invoice_controllers.dart';
import '../gst.dart';
import '../models/invoice_models.dart';
import 'invoice_detail_page.dart';
import 'invoice_widgets.dart';

final _day = DateFormat('dd MMM yyyy');

class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  late final InvoiceListController c;

  @override
  void initState() {
    super.initState();
    Get.delete<InvoiceListController>(force: true);
    c = Get.put(InvoiceListController());
  }

  @override
  void dispose() {
    Get.delete<InvoiceListController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        elevation: 0,
        title: const Text('Invoices'),
      ),
      body: Column(
        children: [
          _billboard(),
          _filters(),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value && c.invoices.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.errorMsg.value != null) {
                return _centred(c.errorMsg.value!, onRetry: c.fetch);
              }
              if (c.invoices.isEmpty) {
                return _centred(c.search.value.isNotEmpty || c.filter.value != null
                    ? 'No invoices match this filter.'
                    : 'No invoices yet. Open an order and raise one against its despatched challans.');
              }
              return RefreshIndicator(
                onRefresh: c.fetch,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: c.invoices.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => i == c.invoices.length
                      ? _Pager(c: c)
                      : _InvoiceCard(invoice: c.invoices[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Search, and what is on screen at a glance.
  Widget _billboard() => Container(
        width: double.infinity,
        color: ErpColors.navyDark,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: c.setSearch,
              style: TextStyle(color: ErpColors.textOnDark, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Invoice no., buyer, GSTIN, challan or order no…',
                hintStyle: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 19, color: ErpColors.textOnDarkSub),
                filled: true,
                fillColor: ErpColors.navyMid,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Obx(() {
              final shown = c.invoices;
              // What is ON SCREEN, said as such: not the business's
              // receivables, which the accounts own.
              final issued = shown.where((i) => !i.isCancelled);
              final value = issued.fold<double>(0, (s, i) => s + i.totals.grand);
              final owed = issued.fold<double>(0, (s, i) => s + i.owed);
              return Row(
                children: [
                  _stat('${c.total.value}', 'invoices'),
                  const SizedBox(width: 22),
                  _stat(inr0(value), 'on this page'),
                  const SizedBox(width: 22),
                  _stat(inr0(owed), 'owed on these'),
                ],
              );
            }),
          ],
        ),
      );

  Widget _stat(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(color: ErpColors.textOnDark, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 11)),
        ],
      );

  Widget _filters() => SizedBox(
        height: 46,
        child: Obx(() {
          final active = c.filter.value;
          final entries = InvoiceListController.filters.entries.toList();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(entries[i].value, style: const TextStyle(fontSize: 12)),
              selected: active == entries[i].key,
              onSelected: (_) => c.setFilter(entries[i].key),
              visualDensity: VisualDensity.compact,
            ),
          );
        }),
      );

  Widget _centred(String text, {VoidCallback? onRetry}) => LayoutBuilder(
        builder: (_, box) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: box.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(text, textAlign: TextAlign.center, style: TextStyle(color: ErpColors.textSecondary)),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Get.to(() => InvoiceDetailPage(invoiceId: inv.id)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The buyer is how a person recognises it; the
                        // number is how it is filed.
                        Text(inv.buyer.name.isEmpty ? inv.customerName : inv.buyer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            inv.invoiceNumber,
                            if (inv.invoiceDate != null) _day.format(inv.invoiceDate!),
                            if (inv.orderNo != null) 'Order #${inv.orderNo}',
                          ].join('  ·  '),
                          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    inr(inv.totals.grand),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: inv.isCancelled ? ErpColors.textMuted : ErpColors.textPrimary,
                      decoration: inv.isCancelled ? TextDecoration.lineThrough : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              InvoiceChips(invoice: inv),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.c});

  final InvoiceListController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.pages.value <= 1) return const SizedBox(height: 8);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: c.page.value > 1 ? () => c.goToPage(c.page.value - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Page ${c.page.value} of ${c.pages.value}',
                style: TextStyle(color: ErpColors.textSecondary, fontSize: 12.5)),
            IconButton(
              tooltip: 'Next page',
              onPressed: c.page.value < c.pages.value ? () => c.goToPage(c.page.value + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
    });
  }
}
