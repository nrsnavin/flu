import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../report_pdf.dart';
import '../widgets/report_chart_card.dart';
import '../controllers/dispatch_report_controller.dart';

// ══════════════════════════════════════════════════════════════
//  DISPATCH & CUSTOMER SALES — mobile summary
//
//  Delivery-challan value/quantity over a preset period, grouped by
//  customer / elastic / day. Read-only companion to the web report.
// ══════════════════════════════════════════════════════════════
class DispatchReportScreen extends StatelessWidget {
  const DispatchReportScreen({super.key});

  static final _nf = NumberFormat.decimalPattern('en_IN');
  static String _money(num v) => '₹${_nf.format(v.round())}';

  static const _presetLabels = {
    'today': 'Today', 'week': 'Week', 'month': 'Month', 'fy': 'FY',
  };
  static const _groupLabels = {
    'customer': 'Customer', 'elastic': 'Elastic', 'day': 'Day',
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DispatchReportController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: 'Sales Report',
        subtitle: 'Dispatch value by period',
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () => downloadReportPdf(
              path: '/reports/dispatch',
              query: {'preset': c.preset.value, 'groupBy': c.groupBy.value, 'compare': true},
              filename: 'dispatch-sales-report',
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
                      title: 'Dispatched value',
                      series: c.series,
                      metricKey: 'amount',
                      color: ErpColors.successGreen,
                      format: (v) => '\u20b9${_nf.format(v.round())}',
                      emptyLabel: 'Nothing dispatched in this period.',
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

  Widget _tiles(DispatchReportController c) {
    final pct = c.amountDeltaPct;
    return Column(children: [
      Row(children: [
        Expanded(child: _Tile(
          label: 'Dispatch value',
          value: _money(c.amount),
          trailing: pct == null ? null : _DeltaChip(pct: pct),
        )),
        const SizedBox(width: 10),
        Expanded(child: _Tile(label: 'Quantity', value: _nf.format(c.quantity))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Tile(label: 'Challans', value: _nf.format(c.dcs), sub: '${c.customers} customers')),
        const SizedBox(width: 10),
        Expanded(child: _Tile(label: 'Avg rate', value: _money(c.avgRate))),
      ]),
    ]);
  }

  Widget _groupBar(DispatchReportController c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(
              children: DispatchReportController.groupBys.map((g) {
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

  List<Widget> _rows(DispatchReportController c) {
    if (c.rows.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(top: 28),
          child: Center(
            child: Text('No dispatches in this period',
                style: TextStyle(color: ErpColors.textMuted)),
          ),
        ),
      ];
    }
    return c.rows.map((r) {
      final label = r['label']?.toString() ?? '—';
      final amount = (r['amount'] as num?) ?? 0;
      final qty = (r['quantity'] as num?) ?? 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: ErpDecorations.card,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          Text(_money(amount),
              style: TextStyle(
                  color: ErpColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 10),
          Text('${_nf.format(qty)} m',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        ]),
      );
    }).toList();
  }
}

class _PresetBar extends StatelessWidget {
  final DispatchReportController c;
  const _PresetBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => Row(
            children: DispatchReportController.presets.map((p) {
              final selected = c.preset.value == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(DispatchReportScreen._presetLabels[p] ?? p),
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
  const _Tile({required this.label, required this.value, this.sub, this.trailing});

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
                  color: ErpColors.textPrimary,
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
