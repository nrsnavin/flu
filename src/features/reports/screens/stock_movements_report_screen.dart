import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../report_pdf.dart';
import '../controllers/stock_movements_report_controller.dart';

// ══════════════════════════════════════════════════════════════
//  STOCK MOVEMENT LEDGER — mobile summary
//
//  Raw-material inward / outward / net over a preset period, grouped
//  by material or day.
// ══════════════════════════════════════════════════════════════
class StockMovementsReportScreen extends StatelessWidget {
  const StockMovementsReportScreen({super.key});

  static final _nf = NumberFormat.decimalPattern('en_IN');
  static String _signed(num v) => '${v >= 0 ? '+' : ''}${_nf.format(v)}';

  static const _presetLabels = {
    'today': 'Today', 'week': 'Week', 'month': 'Month', 'fy': 'FY',
  };
  static const _groupLabels = {'material': 'Material', 'day': 'Day'};

  @override
  Widget build(BuildContext context) {
    final c = Get.put(StockMovementsReportController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: 'Movement Ledger',
        subtitle: 'Raw-material in / out',
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () => downloadReportPdf(
              path: '/reports/stock-movements',
              query: {'preset': c.preset.value, 'groupBy': c.groupBy.value, 'compare': true},
              filename: 'stock-movements-report',
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
                  return ListView(children: [
                    const SizedBox(height: 120),
                    const Icon(Icons.cloud_off_outlined, size: 44, color: ErpColors.textMuted),
                    const SizedBox(height: 10),
                    Center(child: Text(c.errorMsg.value ?? 'Error',
                        style: const TextStyle(color: ErpColors.textSecondary))),
                    const SizedBox(height: 12),
                    Center(child: OutlinedButton(onPressed: c.fetch, child: const Text('Retry'))),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    _tiles(c),
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

  Widget _tiles(StockMovementsReportController c) {
    final netUp = c.net >= 0;
    return Row(children: [
      Expanded(child: _Tile(label: 'Inward', value: '${_nf.format(c.inQty)} kg', color: ErpColors.successGreen)),
      const SizedBox(width: 10),
      Expanded(child: _Tile(label: 'Outward', value: '${_nf.format(c.outQty)} kg', color: ErpColors.errorRed)),
      const SizedBox(width: 10),
      Expanded(child: _Tile(
        label: 'Net',
        value: '${_signed(c.net)} kg',
        color: netUp ? ErpColors.successGreen : ErpColors.errorRed,
      )),
    ]);
  }

  Widget _groupBar(StockMovementsReportController c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(
              children: StockMovementsReportController.groupBys.map((g) {
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

  List<Widget> _rows(StockMovementsReportController c) {
    if (c.rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 28),
          child: Center(
            child: Text('No movements in this period',
                style: TextStyle(color: ErpColors.textMuted)),
          ),
        ),
      ];
    }
    return c.rows.map((r) {
      final label = r['label']?.toString() ?? '—';
      final inQty = (r['inQty'] as num?) ?? 0;
      final outQty = (r['outQty'] as num?) ?? 0;
      final net = (r['net'] as num?) ?? 0;
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
          Text('▲${_nf.format(inQty)}',
              style: const TextStyle(color: ErpColors.successGreen, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('▼${_nf.format(outQty)}',
              style: const TextStyle(color: ErpColors.errorRed, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('${_signed(net)}',
              style: TextStyle(
                  color: net >= 0 ? ErpColors.textPrimary : ErpColors.errorRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ]),
      );
    }).toList();
  }
}

class _PresetBar extends StatelessWidget {
  final StockMovementsReportController c;
  const _PresetBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => Row(
            children: StockMovementsReportController.presets.map((p) {
              final selected = c.preset.value == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(StockMovementsReportScreen._presetLabels[p] ?? p),
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
  final Color color;
  const _Tile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ErpColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
