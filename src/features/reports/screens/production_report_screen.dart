import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../report_pdf.dart';
import '../widgets/report_chart_card.dart';
import '../controllers/production_report_controller.dart';

// ══════════════════════════════════════════════════════════════
//  PRODUCTION REPORT — mobile summary
//
//  Preset period + group-by, summary tiles with a period-over-period
//  delta, and a compact breakdown list. Read-only companion to the
//  full web report.
// ══════════════════════════════════════════════════════════════
class ProductionReportScreen extends StatelessWidget {
  const ProductionReportScreen({super.key});

  static final _nf = NumberFormat.decimalPattern('en_IN');

  static const _presetLabels = {
    'today': 'Today', 'week': 'Week', 'month': 'Month', 'fy': 'FY',
  };
  static const _groupLabels = {
    'machine': 'Machine', 'shift': 'Shift', 'elastic': 'Elastic',
    'operator': 'Operator', 'day': 'Day',
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ProductionReportController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: 'Production Report',
        subtitle: 'Meters produced by period',
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () => downloadReportPdf(
              path: '/reports/production',
              query: {'preset': c.preset.value, 'groupBy': c.groupBy.value, 'compare': true},
              filename: 'production-report',
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
                  return const Center(
                    child: CircularProgressIndicator(color: ErpColors.accentBlue),
                  );
                }
                if (c.errorMsg.value != null && c.summary.value == null) {
                  return _error(c);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    _tiles(c),
                    const SizedBox(height: 12),
                    ReportChartCard(
                      title: 'Meters produced',
                      series: c.series,
                      metricKey: 'meters',
                      color: ErpColors.accentBlue,
                      format: (v) => '${_nf.format(v.round())} m',
                      emptyLabel: 'No production in this period.',
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

  Widget _error(ProductionReportController c) => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off_outlined, size: 44, color: ErpColors.textMuted),
          const SizedBox(height: 10),
          Center(
            child: Text(c.errorMsg.value ?? 'Error',
                style: const TextStyle(color: ErpColors.textSecondary)),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: c.fetch, child: const Text('Retry')),
          ),
        ],
      );

  Widget _tiles(ProductionReportController c) {
    final pct = c.metersDeltaPct;
    return Column(
      children: [
        Row(children: [
          Expanded(child: _Tile(
            label: 'Meters produced',
            value: _nf.format(c.meters),
            trailing: pct == null ? null : _DeltaChip(pct: pct),
          )),
          const SizedBox(width: 10),
          Expanded(child: _Tile(label: 'Shifts', value: _nf.format(c.shifts))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Tile(label: 'Avg / shift', value: _nf.format(c.avgPerShift))),
          const SizedBox(width: 10),
          Expanded(child: _Tile(
            label: 'Wastage',
            value: '${_nf.format(c.wastageMeters)} m',
            sub: '${c.wastagePct} %',
          )),
        ]),
      ],
    );
  }

  Widget _groupBar(ProductionReportController c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(
              children: ProductionReportController.groupBys.map((g) {
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

  List<Widget> _rows(ProductionReportController c) {
    if (c.rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 28),
          child: Center(
            child: Text('No production in this period',
                style: TextStyle(color: ErpColors.textMuted)),
          ),
        ),
      ];
    }
    return c.rows.map((r) {
      final label = r['label']?.toString() ?? '—';
      final meters = (r['meters'] as num?) ?? 0;
      final shifts = (r['shifts'] as num?) ?? 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: ErpDecorations.card,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          Text('${_nf.format(meters)} m',
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 10),
          Text('${_nf.format(shifts)} sh',
              style: const TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        ]),
      );
    }).toList();
  }
}

class _PresetBar extends StatelessWidget {
  final ProductionReportController c;
  const _PresetBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => Row(
            children: ProductionReportController.presets.map((p) {
              final selected = c.preset.value == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(ProductionReportScreen._presetLabels[p] ?? p),
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
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: ErpColors.textMuted, fontSize: 11)),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(color: ErpColors.textSecondary, fontSize: 11)),
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
