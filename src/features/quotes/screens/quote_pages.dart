import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/quote_controller.dart';
import '../models/quote.dart';

// ══════════════════════════════════════════════════════════════
//  QUOTATIONS — LIST AND DETAIL
//
//  ── Expiry is shown, loudly ────────────────────────────────────
//  The single most expensive mistake this screen can enable is
//  reading an expired quote to a customer as if it still stood. So
//  "Expired" is derived from validTill on every read rather than
//  trusted from a status field that would need a nightly job to stay
//  true, and it is on the row as well as the detail.
// ══════════════════════════════════════════════════════════════

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _day = DateFormat('dd MMM yyyy');

class QuoteListPage extends StatefulWidget {
  const QuoteListPage({super.key});

  @override
  State<QuoteListPage> createState() => _QuoteListPageState();
}

class _QuoteListPageState extends State<QuoteListPage> {
  late final QuoteListController c;

  @override
  void initState() {
    super.initState();
    Get.delete<QuoteListController>(force: true);
    c = Get.put(QuoteListController());
  }

  @override
  void dispose() {
    Get.delete<QuoteListController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Quotations'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onSubmitted: c.setSearch,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Customer or quote number…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: ErpColors.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ErpColors.borderLight),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value && c.quotes.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.errorMsg.value != null) {
                return _centered(c.errorMsg.value!, onRetry: c.fetch);
              }
              if (c.quotes.isEmpty) return _centered('No quotations found.');
              return RefreshIndicator(
                onRefresh: c.fetch,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: c.quotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _QuoteTile(quote: c.quotes[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _centered(String text, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ErpColors.textSecondary)),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.to(() => QuoteDetailPage(quoteId: quote.id)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(quote.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textPrimary)),
                ),
                if (quote.isExpired) const _ExpiredChip(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${quote.quoteNo}'
              '${quote.date == null ? '' : '  ·  ${_day.format(quote.date!)}'}',
              style: const TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary),
            ),
            if (quote.total > 0) ...[
              const SizedBox(height: 6),
              Text(_inr.format(quote.total),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpiredChip extends StatelessWidget {
  const _ExpiredChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ErpColors.statusPartialBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Expired',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ErpColors.accentBlue)),
      );
}

// ── Detail ────────────────────────────────────────────────────
class QuoteDetailPage extends StatefulWidget {
  const QuoteDetailPage({super.key, required this.quoteId});

  final String quoteId;

  @override
  State<QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends State<QuoteDetailPage> {
  late final QuoteDetailController c;
  final _tag = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    c = Get.put(QuoteDetailController(widget.quoteId), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<QuoteDetailController>(tag: _tag, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Quotation'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.quote.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ErpColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: c.fetch, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        final q = c.quote.value;
        if (q == null) return const SizedBox.shrink();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (q.isExpired)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ErpColors.statusPartialBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'This quotation expired on '
                  '${q.validTill == null ? 'an earlier date' : _day.format(q.validTill!)}. '
                  'Do not read these rates to a customer as current.',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ErpColors.accentBlue),
                ),
              ),
            _card('Quotation', [
              _row('Number', q.quoteNo),
              _row('Customer', q.customerName),
              if (q.date != null) _row('Date', _day.format(q.date!)),
              if (q.validTill != null) _row('Valid till', _day.format(q.validTill!)),
              _row('Status', q.status),
              _row('Total', _inr.format(q.total)),
            ]),
            const SizedBox(height: 10),
            _card('Lines', [
              if (q.lines.isEmpty)
                const Text('No lines on this quotation.',
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textSecondary))
              else
                for (final l in q.lines) _line(l),
            ]),
          ],
        );
      }),
    );
  }

  Widget _line(QuoteLine l) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.productName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ErpColors.textPrimary)),
            if (l.productSpec.isNotEmpty)
              Text(l.productSpec,
                  style: const TextStyle(
                      fontSize: 11, color: ErpColors.textMuted)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l.quantityMetres.toStringAsFixed(0)} m '
                    '@ ${_inr.format(l.rateInclTax)}',
                    style: const TextStyle(
                        fontSize: 12, color: ErpColors.textSecondary),
                  ),
                ),
                Text(_inr.format(l.valueInclTax),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ErpColors.textPrimary)),
              ],
            ),
          ],
        ),
      );

  Widget _card(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: ErpColors.textMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: ErpColors.textPrimary)),
            ),
          ],
        ),
      );
}
