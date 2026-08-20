import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/quote_controller.dart';
import '../models/quote.dart';

// ══════════════════════════════════════════════════════════════
//  QUOTATIONS — LIST AND DETAIL
//
//  The first version of this screen was a thin stub: a name, a
//  number, a flat list of lines. Next to the web page — which shows
//  the frozen costing behind every rate, the margin, the tax and the
//  grand total — it did not answer the question somebody opens a
//  quote to ask. This is the same information, laid out for a thumb.
//
//  ── The shape is borrowed from Netflix, and here is why ────────
//  Not for the look. For four decisions that happen to fit a
//  quotation better than a form does:
//
//  1. A BILLBOARD, not a header. Netflix opens on one title at full
//     bleed rather than a grid of equals. The equivalent here is the
//     grand total: it is the one number a person is looking for, so
//     it is set at 32pt on the dark panel and everything else is
//     smaller. A DescriptionList of eight equal-weight rows — which
//     is what the web can afford on a wide screen — makes you read
//     all eight to find it.
//
//  2. BADGES SIT ON THE CONTENT. "Expired" is over the card, the way
//     a NEW badge sits on the artwork, not in a status column you
//     have to look up. The most expensive mistake this screen can
//     enable is reading a lapsed price to a customer as if it stood,
//     so that fact travels with the row and is repeated on the
//     detail. It is derived from validTill on every read, never
//     trusted from a status field that would need a nightly job.
//
//  3. PROGRESSIVE DISCLOSURE. A row expands to the full costing
//     instead of navigating away. Each product's materials, margin
//     and tax are three taps of detail that most readers never want
//     and the one reader who does wants immediately — the same
//     reason a title card expands rather than opening a page.
//
//  4. DARK CHROME, LIGHT CONTENT. The panel is navy so the figures
//     on it carry; the cards below stay on the app's light surface.
//     A full dark theme would look like a different application from
//     every other screen in it. Netflix's actual lesson is contrast
//     between chrome and content, not that everything must be black.
// ══════════════════════════════════════════════════════════════

final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _num0 = NumberFormat.decimalPattern('en_IN');
final _day = DateFormat('dd MMM yyyy');

String _money(double v, {int dp = 2}) =>
    '₹${NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: dp).format(v).trim()}';

/// One palette for the six statuses, used by the chip on the row and
/// the chip on the detail so they cannot drift apart.
({Color bg, Color fg}) _statusTone(String s) {
  switch (s) {
    case 'accepted':
      return (bg: ErpColors.statusCompletedBg, fg: ErpColors.statusCompletedText);
    case 'sent':
      return (bg: ErpColors.statusOpenBg, fg: ErpColors.statusOpenText);
    case 'declined':
    case 'cancelled':
      return (bg: ErpColors.statusCancelledBg, fg: ErpColors.statusCancelledText);
    case 'expired':
      return (bg: ErpColors.statusPartialBg, fg: ErpColors.statusPartialText);
    default: // draft
      return (bg: ErpColors.bgMuted, fg: ErpColors.textSecondary);
  }
}

// ══════════════════════ LIST ══════════════════════

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
        elevation: 0,
        title: const Text('Quotations'),
      ),
      body: Column(
        children: [
          _billboard(),
          _filters(),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value && c.quotes.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.errorMsg.value != null) {
                return _centred(c.errorMsg.value!, onRetry: c.fetch);
              }
              if (c.quotes.isEmpty) {
                return _centred(c.search.value.isNotEmpty ||
                        c.status.value != null
                    ? 'No quotations match this filter.'
                    : 'No quotations yet.');
              }
              return RefreshIndicator(
                onRefresh: c.fetch,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: c.quotes.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => i == c.quotes.length
                      ? _Pager(c: c)
                      : _QuoteCard(quote: c.quotes[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// The dark panel: search, and what is on screen at a glance.
  Widget _billboard() => Container(
        width: double.infinity,
        color: ErpColors.navyDark,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: c.setSearch,
              style: const TextStyle(color: ErpColors.textOnDark, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Customer or quote number…',
                hintStyle: const TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 19, color: ErpColors.textOnDarkSub),
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
              final shown = c.quotes;
              // The value of what is ON SCREEN, said plainly. It is not
              // a pipeline figure and must not be mistaken for one, so
              // the label names the page rather than the business.
              final value = shown.fold<double>(0, (s, q) => s + q.grandTotal);
              final expired = shown.where((q) => q.isExpired).length;
              return Row(
                children: [
                  _billboardStat('${c.total.value}', 'quotations'),
                  const SizedBox(width: 22),
                  _billboardStat(_inr0.format(value), 'on this page'),
                  if (expired > 0) ...[
                    const SizedBox(width: 22),
                    _billboardStat('$expired', 'lapsed',
                        tone: ErpColors.statusPartialText),
                  ],
                ],
              );
            }),
          ],
        ),
      );

  Widget _billboardStat(String value, String label, {Color? tone}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                color: tone ?? ErpColors.textOnDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              )),
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 11)),
        ],
      );

  Widget _filters() => SizedBox(
        height: 46,
        child: Obx(() {
          // Read here, not in itemBuilder: a lazy builder runs after the
          // Obx body has returned, so an observable touched only inside
          // it leaves GetX with nothing to subscribe to and it throws.
          final active = c.status.value;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            itemCount: QuoteListController.statusFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final s = QuoteListController.statusFilters[i];
              final selected = active == s;
              return ChoiceChip(
                label: Text(s == null ? 'All' : _titleCase(s),
                    style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => c.setStatus(s),
                visualDensity: VisualDensity.compact,
              );
            },
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
                    Text(text,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: ErpColors.textSecondary)),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: onRetry, child: const Text('Try again')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(quote.status);
    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Get.to(() => QuoteDetailPage(quoteId: quote.id)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              // A lapsed quote is edged, not just chipped — it has to
              // be visible while scrolling past at speed.
              color: quote.isExpired
                  ? ErpColors.statusPartialBorder
                  : ErpColors.borderLight,
              width: quote.isExpired ? 1.5 : 1,
            ),
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
                        // The customer is the title. The quote number
                        // is how you file it, not how you recognise it.
                        Text(quote.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${quote.quoteNo}'
                          '${quote.date == null ? '' : '  ·  ${_day.format(quote.date!)}'}',
                          style: const TextStyle(
                              fontSize: 11.5, color: ErpColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_inr0.format(quote.grandTotal),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.textPrimary,
                          )),
                      if (quote.totalQuantityMetres > 0)
                        Text('${_num0.format(quote.totalQuantityMetres)} m',
                            style: const TextStyle(
                                fontSize: 11, color: ErpColors.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  _pill(_titleCase(quote.status), tone.bg, tone.fg),
                  if (quote.isExpired) ...[
                    const SizedBox(width: 6),
                    _pill('Lapsed', ErpColors.statusPartialBg,
                        ErpColors.statusPartialText),
                  ],
                  const Spacer(),
                  Text(
                    '${quote.lines.length} product'
                    '${quote.lines.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11, color: ErpColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _pill(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );

class _Pager extends StatelessWidget {
  const _Pager({required this.c});

  final QuoteListController c;

  @override
  Widget build(BuildContext context) => Obx(() {
        if (c.pages.value <= 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: c.page.value > 1
                    ? () => c.goToPage(c.page.value - 1)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Text('Page ${c.page.value} of ${c.pages.value}',
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12)),
              IconButton(
                onPressed: c.page.value < c.pages.value
                    ? () => c.goToPage(c.page.value + 1)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        );
      });
}

// ══════════════════════ DETAIL ══════════════════════

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

  void _say(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ErpColors.errorRed : ErpColors.successGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        elevation: 0,
        title: const Text('Quotation'),
        actions: [
          Obx(() => IconButton(
                tooltip: 'Quotation PDF',
                onPressed: c.isDownloading.value || c.quote.value == null
                    ? null
                    : () async {
                        final err = await c.openPdf();
                        if (err != null) _say(err, error: true);
                      },
                icon: c.isDownloading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: ErpColors.textOnDark))
                    : const Icon(Icons.picture_as_pdf_outlined),
              )),
        ],
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
          padding: EdgeInsets.zero,
          children: [
            _hero(q),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (q.isExpired) ...[
                    _lapsedBanner(q),
                    const SizedBox(height: 10),
                  ],
                  _facts(q),
                  const SizedBox(height: 10),
                  for (var i = 0; i < q.lines.length; i++) ...[
                    _LineCard(index: i + 1, line: q.lines[i]),
                    const SizedBox(height: 10),
                  ],
                  if (q.lines.isEmpty) ...[
                    _card('Products', [
                      const Text('No products on this quotation.',
                          style: TextStyle(
                              fontSize: 13, color: ErpColors.textSecondary)),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  _totals(q),
                  if (q.remarks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _card('Remarks', [
                      Text(q.remarks,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: ErpColors.textPrimary)),
                    ]),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  /// The billboard: the number they are asking about, then the two or
  /// three taps that are worth having in a room with a customer.
  Widget _hero(Quote q) {
    final tone = _statusTone(q.status);
    return Container(
      width: double.infinity,
      color: ErpColors.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.customerName,
              style: const TextStyle(
                color: ErpColors.textOnDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 2),
          Text(
            '${q.quoteNo}'
            '${q.date == null ? '' : '  ·  ${_day.format(q.date!)}'}',
            style: const TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Text(_money(q.grandTotal),
              style: const TextStyle(
                color: ErpColors.textOnDark,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.05,
              )),
          Text(
            q.totalQuantityMetres > 0
                ? 'inc. GST · ${_num0.format(q.totalQuantityMetres)} m across '
                    '${q.lines.length} product${q.lines.length == 1 ? '' : 's'}'
                // Every line quoted as a rate only. Saying so stops the
                // grand total being read as an order value.
                : 'inc. GST · quoted as rates, no quantity given',
            style: const TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pill(_titleCase(q.status), tone.bg, tone.fg),
              if (q.isExpired) ...[
                const SizedBox(width: 6),
                _pill('Lapsed', ErpColors.statusPartialBg,
                    ErpColors.statusPartialText),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _actions(q),
        ],
      ),
    );
  }

  Widget _actions(Quote q) {
    // What can still be decided. A settled quote shows nothing rather
    // than disabled buttons — there is no action to explain.
    final available = <String>[
      if (q.status == 'draft') 'sent',
      if (!q.isSettled) ...['accepted', 'declined'],
    ];
    if (available.isEmpty) return const SizedBox.shrink();

    return Obx(() => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in available)
              _heroButton(
                label: kQuoteActions[s]!,
                filled: s == 'accepted',
                busy: c.isBusy.value,
                onTap: () => _confirmStatus(q, s),
              ),
          ],
        ));
  }

  Widget _heroButton({
    required String label,
    required bool filled,
    required bool busy,
    required VoidCallback onTap,
  }) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: filled ? Colors.white : ErpColors.textOnDark,
    );
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: Material(
        color: filled ? ErpColors.accentBlue : ErpColors.navyMid,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(label, style: style),
          ),
        ),
      ),
    );
  }

  /// Accepting or declining is what the customer said, and it is not
  /// undoable from this screen — so it is confirmed, with the total
  /// repeated in the question.
  Future<void> _confirmStatus(Quote q, String status) async {
    final label = kQuoteActions[status]!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(label),
        content: Text(
          status == 'sent'
              ? 'Mark ${q.quoteNo} as sent to ${q.customerName}?'
              : 'Record that ${q.customerName} '
                  '${status == 'accepted' ? 'ACCEPTED' : 'DECLINED'} '
                  '${q.quoteNo} at ${_money(q.grandTotal)}?'
                  '\n\nThis cannot be undone here.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(label)),
        ],
      ),
    );
    if (ok != true) return;
    final err = await c.setStatus(status);
    _say(err ?? '${q.quoteNo} — ${label.toLowerCase()}', error: err != null);
  }

  Widget _lapsedBanner(Quote q) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.statusPartialBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.statusPartialBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This price has lapsed',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ErpColors.statusPartialText)),
            const SizedBox(height: 3),
            Text(
              'It was valid until '
              '${q.validTill == null ? 'an earlier date' : _day.format(q.validTill!)}. '
              'Do not read these rates to a customer as current — the '
              'material costs behind them are from the day it was raised.',
              style: const TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _facts(Quote q) => _card('Quotation', [
        _kv('Quote date', q.date == null ? '—' : _day.format(q.date!)),
        _kv('Valid until',
            q.validTill == null ? '—' : _day.format(q.validTill!)),
        _kv('Their reference', q.customerRef.isEmpty ? '—' : q.customerRef),
        _kv('GSTIN', q.customerGstin.isEmpty ? '—' : q.customerGstin),
      ]);

  Widget _totals(Quote q) => _card('Quotation total', [
        for (final l in q.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: ErpColors.textPrimary)),
                      Text('${_money(l.rateBeforeTax)}/m',
                          style: const TextStyle(
                              fontSize: 11, color: ErpColors.textMuted)),
                    ],
                  ),
                ),
                Text(
                  l.isRateOnly ? 'rate only' : _money(l.valueBeforeTax),
                  style: TextStyle(
                    fontSize: 13,
                    color: l.isRateOnly
                        ? ErpColors.textMuted
                        : ErpColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 18),
        _kv('Sub-total (ex-GST)', _money(q.subTotal), bold: true),
        _kv('GST @ ${q.gstPercent.toStringAsFixed(q.gstPercent % 1 == 0 ? 0 : 2)}%',
            _money(q.gstAmount)),
        const Divider(height: 18, thickness: 1.4),
        Row(
          children: [
            const Expanded(
              child: Text('Grand total',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: ErpColors.textPrimary)),
            ),
            Text(_money(q.grandTotal),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ErpColors.textPrimary)),
          ],
        ),
      ]);
}

/// One product, collapsed to its price and expandable to the costing
/// that produced it.
class _LineCard extends StatefulWidget {
  const _LineCard({required this.index, required this.line});

  final int index;
  final QuoteLine line;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.index}. ${l.productName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: ErpColors.textPrimary)),
                        if (l.productSpec.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(l.productSpec,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: ErpColors.textMuted)),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          l.isRateOnly
                              ? '${_money(l.rateInclTax)}/m inc. GST'
                              : '${_num0.format(l.quantityMetres)} m × '
                                  '${_money(l.rateInclTax)}/m',
                          style: const TextStyle(
                              fontSize: 12, color: ErpColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l.isRateOnly ? '—' : _money(l.valueInclTax),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: ErpColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Icon(_open ? Icons.expand_less : Icons.expand_more,
                          size: 20, color: ErpColors.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_open) _costing(l),
        ],
      ),
    );
  }

  Widget _costing(QuoteLine l) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(11)),
        ),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frozen at the moment this quote was raised — it explains '
              'the price offered, not what the same product would cost '
              'today.',
              style: TextStyle(
                  fontSize: 11, color: ErpColors.textMuted, height: 1.35),
            ),
            const SizedBox(height: 10),
            if (l.materials.isNotEmpty) ...[
              Text('${l.totalWeightGrams.toStringAsFixed(2)} g of material '
                  'in a metre',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textSecondary)),
              const SizedBox(height: 6),
              // A four-column table will not fit a phone at any font
              // worth reading, so it scrolls inside itself rather than
              // shrinking to illegible or pushing the page sideways.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 30,
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 34,
                  horizontalMargin: 0,
                  columnSpacing: 18,
                  headingTextStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textMuted),
                  dataTextStyle: const TextStyle(
                      fontSize: 12, color: ErpColors.textPrimary),
                  columns: const [
                    DataColumn(label: Text('MATERIAL')),
                    DataColumn(label: Text('WEIGHT (g)'), numeric: true),
                    DataColumn(label: Text('RATE (₹/kg)'), numeric: true),
                    DataColumn(label: Text('COST / m'), numeric: true),
                  ],
                  rows: [
                    for (final m in l.materials)
                      DataRow(cells: [
                        DataCell(Text(m.label)),
                        DataCell(Text(m.weightGrams.toStringAsFixed(3))),
                        DataCell(Text(m.ratePerKg.toStringAsFixed(2))),
                        DataCell(Text(_money(m.cost, dp: 4))),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _kv('Materials', _money(l.materialCost, dp: 4)),
            _kv('Conversion', _money(l.conversionCost, dp: 4)),
            const Divider(height: 14),
            _kv('Cost per metre', _money(l.totalCost, dp: 4), bold: true),
            _kv('Margin @ ${l.marginPercent.toStringAsFixed(2)}%',
                _money(l.marginAmount)),
            const Divider(height: 14),
            _kv('Rate per metre (ex-GST)', _money(l.rateBeforeTax),
                bold: true),
            if (!l.isRateOnly) ...[
              const SizedBox(height: 8),
              _kv('Quantity', '${_num0.format(l.quantityMetres)} m'),
              _kv('Value (ex-GST)', _money(l.valueBeforeTax)),
              _kv('Rate inc. GST', _money(l.rateInclTax), bold: true),
              _kv('Value inc. GST', _money(l.valueInclTax)),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'No quantity given — this product is quoted as a rate only.',
                style:
                    TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
              ),
            ],
          ],
        ),
      );
}

// ── Shared bits ───────────────────────────────────────────────

Widget _kv(String k, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(k,
                style: TextStyle(
                  fontSize: 12.5,
                  color: bold
                      ? ErpColors.textPrimary
                      : ErpColors.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
          const SizedBox(width: 10),
          Text(v,
              style: TextStyle(
                fontSize: 13,
                color: ErpColors.textPrimary,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              )),
        ],
      ),
    );

Widget _card(String title, List<Widget> children) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
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
