import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/root_cause_controller.dart';

class WastageRootCausePage extends StatelessWidget {
  const WastageRootCausePage({super.key});

  static final _n = NumberFormat.decimalPattern('en_IN');

  @override
  Widget build(BuildContext context) {
    final c = Get.put(WastageRootCauseController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Wastage root cause'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.data.value == null) {
          return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.data.value == null) {
          return Center(child: Text(c.errorMsg.value!, style: const TextStyle(color: ErpColors.textSecondary)));
        }
        final d = c.data.value;
        if (d == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _daySelector(c),
            const SizedBox(height: 12),
            Row(children: [
              _tile('Total wastage', '${_n.format(d.totals.qty)} m', ErpColors.errorRed),
              const SizedBox(width: 10),
              _tile('Entries', _n.format(d.totals.count), ErpColors.textPrimary),
              const SizedBox(width: 10),
              _tile('Penalty', '₹${_n.format(d.totals.penalty)}', ErpColors.textPrimary),
            ]),
            if (d.aiSummary != null && d.aiSummary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _aiCard(d.aiSummary!),
            ],
            if (d.insights.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...d.insights.map(_insightCard),
            ],
            const SizedBox(height: 12),
            _listCard('Top reasons', d.byReason),
            const SizedBox(height: 12),
            _listCard('Reason × machine hotspots', d.reasonMachine, showSub: true),
            const SizedBox(height: 12),
            _listCard('By operator', d.byOperator, showSub: true),
            const SizedBox(height: 12),
            _listCard('By machine', d.byMachine),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  Widget _daySelector(WastageRootCauseController c) {
    return Obx(() => Row(
          children: [7, 30, 90].map((v) {
            final sel = c.days.value == v;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${v}D'),
                selected: sel,
                onSelected: (_) => c.setDays(v),
                selectedColor: ErpColors.accentBlue,
                labelStyle: TextStyle(color: sel ? Colors.white : ErpColors.textSecondary, fontSize: 12),
                backgroundColor: ErpColors.bgSurface,
              ),
            );
          }).toList(),
        ));
  }

  Widget _tile(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  Widget _aiCard(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: ErpColors.accentBlue, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome, size: 14, color: ErpColors.accentBlue),
            SizedBox(width: 6),
            Text('AI ROOT-CAUSE ANALYSIS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ErpColors.accentBlue)),
          ]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary, height: 1.4)),
        ]),
      );

  Widget _insightCard(RcInsight ins) {
    final warn = ins.severity == 'warn';
    final color = warn ? ErpColors.warningAmber : ErpColors.accentBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warn ? Icons.warning_amber_rounded : Icons.info_outline, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ins.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ErpColors.textPrimary)),
            const SizedBox(height: 2),
            Text(ins.detail, style: const TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  Widget _listCard(String title, List<RcRow> rows, {bool showSub = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text('No data', style: TextStyle(color: ErpColors.textMuted, fontSize: 12))
          else
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        showSub && r.sub.isNotEmpty ? '${r.label} · ${r.sub}' : r.label,
                        style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${_n.format(r.qty)} m',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                    Text(' (${r.count})', style: const TextStyle(fontSize: 12, color: ErpColors.textMuted)),
                  ]),
                )),
        ]),
      );
}
