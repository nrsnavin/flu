import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/pnl_controllers.dart';
import '../models/order_pnl.dart';
import 'pnl_detail_page.dart';
import 'pnl_shared.dart';

// ══════════════════════════════════════════════════════════════
//  ORDER P&L — THE LIST
//
//  One row per order: what it sold for, what it cost, what is left.
//
//  The sort needs care. Ranking by margin cannot be pushed down to the
//  database — margin does not exist until the P&L is built for each
//  order — so anything except "newest" ranks only the rows on THIS
//  page. The server says as much in `sortScope`, and this screen
//  repeats it, because a "worst margin" heading that quietly meant "of
//  these 25" would send somebody chasing the wrong order.
// ══════════════════════════════════════════════════════════════

class PnlListPageView extends StatefulWidget {
  const PnlListPageView({super.key});

  @override
  State<PnlListPageView> createState() => _PnlListPageViewState();
}

class _PnlListPageViewState extends State<PnlListPageView> {
  late final PnlListController c;

  @override
  void initState() {
    super.initState();
    Get.delete<PnlListController>(force: true);
    c = Get.put(PnlListController());
  }

  @override
  void dispose() {
    Get.delete<PnlListController>(force: true);
    super.dispose();
  }

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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Order P&L', style: ErpTextStyles.pageTitle),
              Text('What each order made, after what it cost',
                  style: TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10)),
            ],
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFF1E3A5F)),
          ),
        ),
        body: Obx(() {
          if (c.forbidden.value) return const PnlForbidden();
          if (c.loading.value && c.page.value.rows.isEmpty) {
            return Center(
                child: CircularProgressIndicator(color: ErpColors.accentBlue));
          }

          final p = c.page.value;
          return RefreshIndicator(
            color: ErpColors.accentBlue,
            onRefresh: c.fetch,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
              children: [
                if (c.errorMsg.value != null) ...[
                  PnlNote(c.errorMsg.value!, ErpColors.errorRed,
                      Icons.error_outline),
                  const SizedBox(height: 10),
                ],

                _PageTotals(p: p),
                const SizedBox(height: 12),
                _SortBar(c: c),
                const SizedBox(height: 8),

                if (c.sortedWithinPageOnly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PnlNote(
                      'Ranked within this page of ${p.rows.length}, not across '
                      'all ${p.total} orders — margin is only known once each '
                      'order is costed, so it cannot be sorted at the database.',
                      ErpColors.warningAmber,
                      Icons.info_outline,
                    ),
                  ),

                if (p.rows.isEmpty)
                  const _Empty()
                else
                  ...p.rows.map((r) => _Row(row: r)),

                if (p.pages > 1) ...[
                  const SizedBox(height: 6),
                  _Pager(c: c, p: p),
                ],
              ],
            ),
          );
        }),
      );
}

// ── Totals for the page ───────────────────────────────────────
class _PageTotals extends StatelessWidget {
  final PnlListPage p;
  const _PageTotals({required this.p});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.navyDark,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: _DarkFigure(
                  'Order value', moneyShort(p.totalOrderValue), Colors.white),
            ),
            Expanded(
              child: _DarkFigure(
                  'Cost', moneyShort(p.totalCost), ErpColors.accentLight),
            ),
            Expanded(
              child: _DarkFigure(
                'Profit',
                moneyShort(p.totalProfit),
                p.totalProfit < 0
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFF86EFAC),
              ),
            ),
            Expanded(
              child: _DarkFigure(
                'Margin',
                pct(p.marginPct),
                p.totalProfit < 0
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFF86EFAC),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Never "the totals" without saying whose. These are the sums
          // of the page in hand, not of the factory.
          Text(
            p.pages > 1
                ? 'Across the ${p.rows.length} orders on this page · '
                    '${p.total} in total'
                : 'Across all ${p.total} orders',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ErpColors.textOnDarkSub),
          ),
        ]),
      );
}

class _DarkFigure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DarkFigure(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: ErpColors.textOnDarkSub)),
      ]);
}

// ── Sort ──────────────────────────────────────────────────────
class _SortBar extends StatelessWidget {
  final PnlListController c;
  const _SortBar({required this.c});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: PnlListController.sorts.map((s) {
            final on = c.sort.value == s;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  PnlListController.sortLabel(s),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: on ? ErpColors.accentBlue : ErpColors.textSecondary,
                  ),
                ),
                selected: on,
                onSelected: (_) => c.sort.value = s,
                backgroundColor: ErpColors.bgMuted,
                selectedColor: ErpColors.accentBlue.withValues(alpha: 0.12),
                side: BorderSide(
                    color: on ? ErpColors.accentBlue : ErpColors.borderLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      );
}

// ── One order ─────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final PnlListRow row;
  const _Row({required this.row});

  @override
  Widget build(BuildContext context) {
    final o = row.order;
    return InkWell(
      onTap: () => Get.to(() => PnlDetailPageView(orderId: o.id)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            // A loss earns a red edge. Nothing else does — a thin margin
            // would need a threshold nobody has agreed on.
            color: row.losing
                ? ErpColors.errorRed.withValues(alpha: 0.4)
                : ErpColors.borderLight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: ErpColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (o.customerName.isNotEmpty) o.customerName,
                      if (o.po.isNotEmpty) 'PO ${o.po}',
                      if (o.date != null)
                        DateFormat('dd MMM yyyy').format(o.date!),
                    ].join('  ·  '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: ErpColors.textSecondary),
                  ),
                ],
              ),
            ),
            PnlMarginBadge(marginPct: row.marginPct, profit: row.profit),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: PnlFigure(
                  label: 'Value',
                  value: moneyShort(row.orderValue),
                  align: CrossAxisAlignment.start),
            ),
            Expanded(
              child: PnlFigure(
                  label: 'Cost',
                  value: moneyShort(row.cost),
                  align: CrossAxisAlignment.start),
            ),
            Expanded(
              child: PnlFigure(
                label: 'Profit',
                value: moneyShort(row.profit),
                color: profitColor(row.priced ? row.profit : null),
                align: CrossAxisAlignment.start,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            PnlStatusPill(o.status),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  '${row.jobs} job${row.jobs == 1 ? '' : 's'}',
                  '${qty(row.producedMeters)} m made',
                ].join('  ·  '),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5, color: ErpColors.textMuted),
              ),
            ),
            // The count only. What each warning says is on the detail
            // page; a truncated one here would be worse than a number.
            if (row.warnings > 0) ...[
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: ErpColors.warningAmber),
              const SizedBox(width: 3),
              Text('${row.warnings}',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.warningAmber)),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: ErpColors.textMuted),
          ]),
        ]),
      ),
    );
  }
}

// ── Paging ────────────────────────────────────────────────────
class _Pager extends StatelessWidget {
  final PnlListController c;
  final PnlListPage p;
  const _Pager({required this.c, required this.p});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageButton(
            icon: Icons.chevron_left_rounded,
            enabled: c.pageNo.value > 1 && !c.loading.value,
            onTap: () => c.goToPage(c.pageNo.value - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Page ${p.page} of ${p.pages}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textSecondary)),
          ),
          _PageButton(
            icon: Icons.chevron_right_rounded,
            enabled: c.pageNo.value < p.pages && !c.loading.value,
            onTap: () => c.goToPage(c.pageNo.value + 1),
          ),
        ],
      );
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 40,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? ErpColors.bgSurface : ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Icon(icon,
              size: 18,
              color: enabled ? ErpColors.accentBlue : ErpColors.textMuted),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: 40),
        child: Column(children: [
          Icon(Icons.query_stats_rounded, size: 40, color: ErpColors.textMuted),
          SizedBox(height: 12),
          Text('Nothing to cost yet',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Orders appear here once they exist. Deleted ones are left out.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
            ),
          ),
        ]),
      );
}
