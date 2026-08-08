import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/pnl_controllers.dart';
import '../models/order_pnl.dart';
import 'pnl_shared.dart';

// ══════════════════════════════════════════════════════════════
//  ONE ORDER'S P&L
//
//  Read-only. The three inputs this calculation needs that no other
//  screen owns — the selling rate per line, a job's actual conversion
//  cost, and the rate card — are all entered on the web, from a paper
//  the accountant is holding. A fat-fingered rate card re-costs every
//  order in the factory, which is not a thing to risk one-handed next
//  to a running loom.
//
//  What a phone IS good for is the question this page answers: is the
//  order in front of me making money, and if not, which line is
//  wrong. So the warnings are shown in full and first — each one names
//  a specific thing making a specific figure wrong.
// ══════════════════════════════════════════════════════════════

const _purple = Color(0xFF7C3AED);

class PnlDetailPageView extends StatefulWidget {
  final String orderId;
  const PnlDetailPageView({super.key, required this.orderId});

  @override
  State<PnlDetailPageView> createState() => _PnlDetailPageViewState();
}

class _PnlDetailPageViewState extends State<PnlDetailPageView> {
  late final PnlDetailController c;

  @override
  void initState() {
    super.initState();
    Get.delete<PnlDetailController>(force: true);
    c = Get.put(PnlDetailController(widget.orderId));
  }

  @override
  void dispose() {
    Get.delete<PnlDetailController>(force: true);
    super.dispose();
  }

  Future<void> _exportPdf(OrderPnl p) async {
    if (c.exporting.value) return;
    c.exporting.value = true;
    try {
      final bytes = await PnlApi.pdf(widget.orderId);
      final dir = await getTemporaryDirectory();
      final name = p.order.orderNo?.toString() ?? widget.orderId;
      final file = File('${dir.path}/order-pnl-$name.pdf');
      await file.writeAsBytes(bytes);
      final res = await OpenFile.open(file.path);
      if (res.type != ResultType.done) {
        _snack(
          res.message.isNotEmpty
              ? res.message
              : 'No app on this phone can open a PDF',
          isError: true,
        );
      }
    } catch (e) {
      _snack(pnlMessage(e, 'Could not build the P&L PDF'), isError: true);
    } finally {
      c.exporting.value = false;
    }
  }

  void _snack(String msg, {required bool isError}) => Get.snackbar(
        isError ? 'Error' : 'Done',
        msg,
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: AppBar(
          backgroundColor: ErpColors.navyDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 4,
          title: Obx(() {
            final p = c.pnl.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p?.order.label ?? 'Order P&L',
                    style: ErpTextStyles.pageTitle),
                Text(
                  p == null || p.order.customerName.isEmpty
                      ? 'Profit and loss'
                      : p.order.customerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10),
                ),
              ],
            );
          }),
          actions: [
            Obx(() {
              final p = c.pnl.value;
              if (p == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Export PDF',
                icon: c.exporting.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined,
                        color: Colors.white, size: 20),
                onPressed: c.exporting.value ? null : () => _exportPdf(p),
              );
            }),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFF1E3A5F)),
          ),
        ),
        body: Obx(() {
          if (c.forbidden.value) return const PnlForbidden();
          if (c.loading.value && c.pnl.value == null) {
            return const Center(
                child: CircularProgressIndicator(color: ErpColors.accentBlue));
          }
          if (c.errorMsg.value != null && c.pnl.value == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: PnlNote(
                    c.errorMsg.value!, ErpColors.errorRed, Icons.error_outline),
              ),
            );
          }
          final p = c.pnl.value;
          if (p == null) return const SizedBox.shrink();

          return RefreshIndicator(
            color: ErpColors.accentBlue,
            onRefresh: c.fetch,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              children: [
                _Headline(p: p),
                const SizedBox(height: 12),

                // First, because every one of them names a specific
                // thing making a specific figure above it wrong.
                if (p.warnings.isNotEmpty) ...[
                  _Warnings(warnings: p.warnings),
                  const SizedBox(height: 12),
                ],

                _Revenue(p: p),
                const SizedBox(height: 12),
                _CostSplit(p: p),
                const SizedBox(height: 12),
                _Materials(p: p),
                const SizedBox(height: 12),
                _Jobs(p: p),
                const SizedBox(height: 12),
                _RateCard(p: p),
                const SizedBox(height: 12),
                const _ReadOnlyNote(),
              ],
            ),
          );
        }),
      );
}

// ── The answer, up top ────────────────────────────────────────
class _Headline extends StatelessWidget {
  final OrderPnl p;
  const _Headline({required this.p});

  @override
  Widget build(BuildContext context) {
    final t = p.totals;
    final f = p.invoicedFraction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PROFIT',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textOnDarkSub)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(t.profit),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: t.profit < 0
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PnlMarginBadge(
              marginPct: t.marginPct, profit: t.profit, large: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _DarkStat('Order value', money(p.orderValue), Colors.white),
          ),
          Expanded(
            child: _DarkStat(
                'Total cost', money(p.costs.total), ErpColors.accentLight),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _DarkStat(
                'Made', '${qty(t.producedMeters)} m', Colors.white70),
          ),
          Expanded(
            child: _DarkStat(
                'Cost / m', money(t.costPerMeter), Colors.white70),
          ),
          Expanded(
            child: _DarkStat(
                'Revenue / m', money(t.revenuePerMeter), Colors.white70),
          ),
        ]),
        // Invoiced sits beside the order value, never instead of it:
        // one is what was agreed, the other is what has gone out.
        if (p.invoiced.challans > 0) ...[
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.local_shipping_outlined,
                size: 13, color: ErpColors.textOnDarkSub),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Invoiced ${money(p.invoiced.amount)} on '
                '${p.invoiced.challans} challan'
                '${p.invoiced.challans == 1 ? '' : 's'}'
                '${f == null ? '' : ' · ${(f * 100).toStringAsFixed(0)}% of order value'}',
                style: const TextStyle(
                    fontSize: 10.5, color: ErpColors.textOnDarkSub),
              ),
            ),
          ]),
        ],
        if (p.order.status.isNotEmpty || p.order.supplyDate != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            PnlStatusPill(p.order.status),
            const SizedBox(width: 8),
            if (p.order.supplyDate != null)
              Text(
                'Supply by ${DateFormat('dd MMM yyyy').format(p.order.supplyDate!)}',
                style: const TextStyle(
                    fontSize: 10.5, color: ErpColors.textOnDarkSub),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DarkStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: ErpColors.textOnDarkSub)),
        ],
      );
}

// ── What the server thinks is wrong ───────────────────────────
class _Warnings extends StatelessWidget {
  final List<String> warnings;
  const _Warnings({required this.warnings});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
        title: 'WHY THESE FIGURES MAY BE WRONG',
        icon: Icons.warning_amber_rounded,
        accentColor: ErpColors.warningAmber,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: warnings
              .map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            decoration: const BoxDecoration(
                                color: ErpColors.warningAmber,
                                shape: BoxShape.circle),
                          ),
                          Expanded(
                            child: Text(w,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.45,
                                    color: ErpColors.textSecondary)),
                          ),
                        ]),
                  ))
              .toList(),
        ),
      );
}

// ── Revenue ───────────────────────────────────────────────────
class _Revenue extends StatelessWidget {
  final OrderPnl p;
  const _Revenue({required this.p});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
        title: 'WHAT IT SOLD FOR',
        icon: Icons.sell_outlined,
        accentColor: ErpColors.successGreen,
        child: Column(children: [
          if (p.lines.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No lines on this order',
                  style:
                      TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
            )
          else
            ...p.lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textPrimary)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Text('${qty(l.quantity)} m',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: ErpColors.textSecondary)),
                            const Text('  ×  ',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: ErpColors.textMuted)),
                            // "No rate" rather than "₹0" — one is a
                            // missing input, the other is a free product,
                            // and only the first is fixable.
                            Text(l.unpriced ? 'no rate' : money(l.rate),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: l.unpriced
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                  color: l.unpriced
                                      ? ErpColors.warningAmber
                                      : ErpColors.textSecondary,
                                )),
                          ]),
                        ],
                      ),
                    ),
                    Text(money(l.amount),
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.textPrimary)),
                  ]),
                )),
          const Divider(height: 18, color: ErpColors.borderLight),
          Row(children: [
            const Expanded(
              child: Text('Order value',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary)),
            ),
            Text(money(p.orderValue),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ErpColors.successGreen)),
          ]),
        ]),
      );
}

// ── Cost ──────────────────────────────────────────────────────
class _CostSplit extends StatelessWidget {
  final OrderPnl p;
  const _CostSplit({required this.p});

  @override
  Widget build(BuildContext context) {
    final rows = p.costs.breakdown;
    final total = p.costs.total;

    return ErpSectionCard(
      title: 'WHAT IT COST',
      icon: Icons.payments_outlined,
      accentColor: ErpColors.errorRed,
      child: Column(children: [
        ...rows.map((e) {
          // Share of total, so the eye lands on the bucket that matters
          // rather than reading seven numbers in sequence.
          final share = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Text(e.key,
                      style: const TextStyle(
                          fontSize: 12, color: ErpColors.textPrimary)),
                ),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text('${(share * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 10, color: ErpColors.textMuted)),
                  ),
                Text(money(e.value),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary)),
              ]),
              if (total > 0) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 3,
                    backgroundColor: ErpColors.bgMuted,
                    valueColor:
                        const AlwaysStoppedAnimation(ErpColors.accentBlue),
                  ),
                ),
              ],
            ]),
          );
        }),
        const Divider(height: 18, color: ErpColors.borderLight),
        Row(children: [
          const Expanded(
            child: Text('Total cost',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary)),
          ),
          Text(money(total),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: ErpColors.errorRed)),
        ]),
      ]),
    );
  }
}

// ── Material issues ───────────────────────────────────────────
class _Materials extends StatelessWidget {
  final OrderPnl p;
  const _Materials({required this.p});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
        title: 'YARN ISSUED',
        icon: Icons.inventory_2_outlined,
        child: p.materialLines.isEmpty
            ? const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nothing issued against this order, so yarn cost is ₹0.',
                  style:
                      TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
                ),
              )
            : Column(
                children: p.materialLines
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: ErpColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${qty(m.quantity)} × '
                                    '${m.unpriced ? 'no price' : money(m.unitPrice)}'
                                    '${m.type.isEmpty ? '' : '  ·  ${m.type}'}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      // Yarn issued at zero price is the
                                      // single biggest way this P&L can
                                      // flatter an order.
                                      color: m.unpriced
                                          ? ErpColors.warningAmber
                                          : ErpColors.textSecondary,
                                      fontWeight: m.unpriced
                                          ? FontWeight.w800
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(money(m.amount),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: ErpColors.textPrimary)),
                          ]),
                        ))
                    .toList(),
              ),
      );
}

// ── Per job ───────────────────────────────────────────────────
class _Jobs extends StatelessWidget {
  final OrderPnl p;
  const _Jobs({required this.p});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
        title: 'COST PER JOB',
        icon: Icons.precision_manufacturing_outlined,
        accentColor: _purple,
        child: p.jobs.isEmpty
            ? const Align(
                alignment: Alignment.centerLeft,
                child: Text('No jobs on this order yet.',
                    style: TextStyle(
                        fontSize: 11.5, color: ErpColors.textMuted)),
              )
            : Column(children: [
                ...p.jobs.map((j) => _JobCard(j: j)),
                const SizedBox(height: 2),
                // Said once, here, rather than left as a hole in every
                // job card for somebody to notice and mistrust.
                const Text(
                  'Yarn is drawn against the order at approval, not the '
                  'job, so there is no honest per-job split of it — see '
                  'the order total above.',
                  style: TextStyle(
                      fontSize: 10, height: 1.4, color: ErpColors.textMuted),
                ),
              ]),
      );
}

class _JobCard extends StatelessWidget {
  final PnlJobRow j;
  const _JobCard({required this.j});

  @override
  Widget build(BuildContext context) {
    final conversions = <MapEntry<String, PnlConversion>>[
      MapEntry('Finishing', j.finishing),
      MapEntry('Checking', j.checking),
      MapEntry('Packing', j.packing),
      MapEntry('Overhead', j.overhead),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(j.jobNo,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: ErpColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (j.status.isNotEmpty) titleCase(j.status),
                    '${qty(j.producedMeters)} m',
                    if (j.costPerMeter != null)
                      '${money(j.costPerMeter)}/m',
                  ].join('  ·  '),
                  style: const TextStyle(
                      fontSize: 10.5, color: ErpColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(money(j.total),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: ErpColors.textPrimary)),
        ]),

        if (j.isOutsourced) ...[
          const SizedBox(height: 7),
          Row(children: [
            const Icon(Icons.factory_outlined, size: 12, color: _purple),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Outsourced${j.outsourceVendor.isEmpty ? '' : ' to ${j.outsourceVendor}'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _purple),
              ),
            ),
            Text(money(j.jobWork),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _purple)),
          ]),
        ],

        const SizedBox(height: 8),
        _line(
          'Labour',
          money(j.labourAmount),
          sub: [
            '${j.labourShifts} shift${j.labourShifts == 1 ? '' : 's'}',
            '${qty(j.labourHours)} h',
            // Planned but never worked. They cost nothing, and saying so
            // is better than a reader wondering why the hours look short.
            if (j.openShifts > 0) '${j.openShifts} not worked',
          ].join('  ·  '),
        ),
        ...conversions.map((e) => _line(
              e.key,
              money(e.value.amount),
              // An override is a measurement somebody entered for this
              // job; a rate is an estimate applied to everything. Worth
              // telling apart when a number looks wrong.
              badge: e.value.isOverride ? 'entered' : null,
            )),
      ]),
    );
  }

  Widget _line(String label, String value, {String? sub, String? badge}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11.5, color: ErpColors.textSecondary)),
                  if (badge != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(badge,
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: _purple)),
                    ),
                  ],
                ]),
                if (sub != null)
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 9.5, color: ErpColors.textMuted)),
              ],
            ),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ErpColors.textPrimary)),
        ]),
      );
}

// ── The rate card behind the conversions ──────────────────────
class _RateCard extends StatelessWidget {
  final OrderPnl p;
  const _RateCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final rc = p.rateCard;
    return ErpSectionCard(
      title: 'CONVERSION RATE CARD',
      icon: Icons.tune_rounded,
      child: Column(children: [
        if (!rc.configured)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: PnlNote(
              'Never set, so finishing, checking, packing and overhead are '
              'all ₹0 — which flatters every order in the factory. Set it '
              'on the Order P&L page on the web.',
              ErpColors.warningAmber,
              Icons.warning_amber_rounded,
            ),
          ),
        ...rc.rows.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                  child: Text(e.key,
                      style: const TextStyle(
                          fontSize: 12, color: ErpColors.textPrimary)),
                ),
                Text('${money(e.value)} / m',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textSecondary)),
              ]),
            )),
      ]),
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) => const PnlNote(
        'Selling rates, per-job cost overrides and the rate card are '
        'entered on the web. A mistyped rate card re-costs every order in '
        'the factory, so it is not editable from a phone.',
        ErpColors.textMuted,
        Icons.lock_outline_rounded,
      );
}
