import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../report_pdf.dart';
import '../widgets/report_chart_card.dart';
import '../controllers/stock_purchases_report_controller.dart';

// ══════════════════════════════════════════════════════════════
//  STOCK & PURCHASES — mobile summary
//
//  Raw-material stock valuation (snapshot) + low-stock, plus windowed
//  PO purchases, grouped by material / category / supplier.
// ══════════════════════════════════════════════════════════════
class StockPurchasesReportScreen extends StatelessWidget {
  const StockPurchasesReportScreen({super.key});

  static final _nf = NumberFormat.decimalPattern('en_IN');
  static String _money(num v) => '₹${_nf.format(v.round())}';

  static const _presetLabels = {
    'today': 'Today', 'week': 'Week', 'month': 'Month', 'fy': 'FY',
  };
  static const _groupLabels = {
    'material': 'Material', 'category': 'Category', 'supplier': 'Supplier',
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.put(StockPurchasesReportController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: 'Stock & Purchases',
        subtitle: 'Valuation & PO purchases',
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () => downloadReportPdf(
              path: '/reports/stock-purchases',
              query: {'preset': c.preset.value, 'groupBy': c.groupBy.value, 'compare': true},
              filename: 'stock-purchases-report',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _PresetBar(c: c),
          Expanded(
            child: RefreshIndicator(
              onRefresh: c.fetch,
              child: Obx(() {
                if (c.loading.value && c.summary.value == null) {
                  return Center(
                    child: CircularProgressIndicator(color: ErpColors.accentBlue),
                  );
                }
                if (c.errorMsg.value != null && c.summary.value == null) {
                  return ListView(children: [
                    const SizedBox(height: 120),
                    Icon(Icons.cloud_off_outlined, size: 44, color: ErpColors.textMuted),
                    const SizedBox(height: 10),
                    Center(child: Text(c.errorMsg.value ?? 'Error',
                        style: TextStyle(color: ErpColors.textSecondary))),
                    const SizedBox(height: 12),
                    Center(child: OutlinedButton(onPressed: c.fetch, child: const Text('Retry'))),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    _tiles(c),
                    const SizedBox(height: 12),
                    ReportChartCard(
                      title: 'Purchase value ordered',
                      series: c.series,
                      metricKey: 'value',
                      color: ErpColors.warningAmber,
                      format: (v) => '\u20b9${_nf.format(v.round())}',
                      emptyLabel: 'Nothing purchased in this period.',
                    ),
                    const SizedBox(height: 16),
                    _groupBar(c),
                    const SizedBox(height: 10),
                    ..._rows(c),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiles(StockPurchasesReportController c) {
    final pct = c.purchaseDeltaPct;
    return Column(children: [
      Row(children: [
        Expanded(child: _Tile(label: 'Stock value', value: _money(c.stockValue), sub: 'as of now')),
        const SizedBox(width: 10),
        Expanded(child: _Tile(
          label: 'Low stock',
          value: _nf.format(c.lowStock),
          danger: c.lowStock > 0,
          sub: '${_nf.format(c.materials)} materials',
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Tile(
          label: 'Purchases',
          value: _money(c.purchaseValue),
          trailing: pct == null ? null : _DeltaChip(pct: pct),
        )),
        const SizedBox(width: 10),
        Expanded(child: _Tile(label: 'Pending on PO', value: _money(c.pendingValue), sub: '${_nf.format(c.pos)} POs')),
      ]),
    ]);
  }

  Widget _groupBar(StockPurchasesReportController c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(
              children: StockPurchasesReportController.groupBys.map((g) {
                final selected = c.groupBy.value == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_groupLabels[g] ?? g),
                    selected: selected,
                    selectedColor: ErpColors.accentBlue,
                    backgroundColor: ErpColors.bgSurface,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : ErpColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) => c.groupBy.value = g,
                  ),
                );
              }).toList(),
            )),
      ),
    );
  }

  List<Widget> _rows(StockPurchasesReportController c) {
    if (c.rows.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(top: 28),
          child: Center(
            child: Text('Nothing to show for this period',
                style: TextStyle(color: ErpColors.textMuted)),
          ),
        ),
      ];
    }
    final supplier = c.groupBy.value == 'supplier';
    return c.rows.map((r) {
      final label = r['label']?.toString() ?? '—';
      final low = r['low'] == true;
      // Supplier rows are a PO register (ordered/pending); stock rows carry value + stock.
      final primary = supplier
          ? _money((r['orderedValue'] as num?) ?? 0)
          : _money((r['value'] as num?) ?? 0);
      final secondary = supplier
          ? '${_money((r['pendingValue'] as num?) ?? 0)} pend'
          : '${_nf.format((r['stock'] as num?) ?? 0)} kg';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: ErpDecorations.card,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          if (low) ...[
            Icon(Icons.warning_amber_rounded, size: 14, color: ErpColors.warningAmber),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          Text(primary,
              style: TextStyle(
                  color: ErpColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 10),
          Text(secondary,
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        ]),
      );
    }).toList();
  }
}

class _PresetBar extends StatelessWidget {
  final StockPurchasesReportController c;
  const _PresetBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => Row(
            children: StockPurchasesReportController.presets.map((p) {
              final selected = c.preset.value == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(StockPurchasesReportScreen._presetLabels[p] ?? p),
                  selected: selected,
                  selectedColor: ErpColors.accentBlue,
                  backgroundColor: ErpColors.bgMuted,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  onSelected: (_) => c.preset.value = p,
                ),
              );
            }).toList(),
          )),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Widget? trailing;
  final bool danger;
  const _Tile({required this.label, required this.value, this.sub, this.trailing, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label,
                style: TextStyle(color: ErpColors.textMuted, fontSize: 11))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: danger ? ErpColors.errorRed : ErpColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
          if (sub != null)
            Text(sub!,
                style: TextStyle(color: ErpColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final num pct;
  const _DeltaChip({required this.pct});

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    final color = up ? ErpColors.successGreen : ErpColors.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: color),
        const SizedBox(width: 2),
        Text('${up ? '+' : ''}$pct%',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
