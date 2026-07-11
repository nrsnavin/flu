import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/planner_controller.dart';

// Auto Planner — AI-proposed machine schedule over the Bayesian
// production rates. Review, then accept as the plan of record.
class AutoPlannerPage extends StatelessWidget {
  const AutoPlannerPage({super.key});

  static const _horizons = [7, 14, 30];
  static final _d = DateFormat('dd MMM');
  static final _dt = DateFormat('dd MMM yyyy, h:mm a');
  static final _n = NumberFormat.decimalPattern('en_IN');

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PlannerController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Auto Planner', style: ErpTextStyles.pageTitle),
            Text('AI-proposed machine schedule',
                style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        actions: [
          Obx(() => IconButton(
                icon: c.isLoading.value
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh),
                onPressed: c.isLoading.value ? null : c.suggest,
                tooltip: 'Regenerate',
              )),
        ],
      ),
      body: Obx(() {
        if (c.isLoading.value && c.objective.value == null) {
          return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.objective.value == null) {
          return _center(c.errorMsg.value!);
        }
        final obj = c.objective.value;
        if (obj == null) return const SizedBox.shrink();
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.suggest,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (c.acceptedAt.value != null) _planOfRecordBanner(c),
              _horizonSelector(c),
              const SizedBox(height: 12),
              _statsGrid(obj),
              const SizedBox(height: 12),
              _acceptBar(context, c, obj),
              if (c.aiRationale.value != null) ...[
                const SizedBox(height: 12),
                _aiCard(c.aiRationale.value!),
              ],
              const SizedBox(height: 12),
              if (c.machines.isEmpty)
                _emptyCard()
              else
                ...c.machines.map(_machineCard),
              if (c.unplaceable.isNotEmpty) ...[
                const SizedBox(height: 4),
                _unplaceableCard(c),
              ],
              const SizedBox(height: 12),
              _assumptions(c),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  Widget _center(String msg) => Center(
      child: Text(msg, style: const TextStyle(color: ErpColors.textSecondary)));

  Widget _planOfRecordBanner(PlannerController c) {
    String when = c.acceptedAt.value ?? '';
    final parsed = DateTime.tryParse(when);
    if (parsed != null) when = _dt.format(parsed.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.statusCompletedBg,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: ErpColors.successGreen, width: 4)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, size: 16, color: ErpColors.successGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Plan of record accepted $when by ${c.acceptedBy.value ?? 'admin'} · ${c.acceptedCount.value} assignments',
            style: const TextStyle(fontSize: 12, color: ErpColors.textPrimary),
          ),
        ),
      ]),
    );
  }

  Widget _horizonSelector(PlannerController c) => Obx(() => Row(
        children: _horizons.map((d) {
          final sel = c.horizon.value == d;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${d}-day'),
              selected: sel,
              onSelected: (_) => c.setHorizon(d),
              selectedColor: ErpColors.accentBlue,
              labelStyle: TextStyle(
                  color: sel ? Colors.white : ErpColors.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w700),
              backgroundColor: ErpColors.bgSurface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: ErpColors.borderLight)),
            ),
          );
        }).toList(),
      ));

  Widget _statsGrid(PlanObjective o) => Row(children: [
        _tile('Placed', '${o.placed}/${o.lines}', ErpColors.textPrimary),
        const SizedBox(width: 10),
        _tile('On time', '${o.onTime}',
            o.onTime == o.placed ? ErpColors.successGreen : ErpColors.textPrimary),
        const SizedBox(width: 10),
        _tile('Late', '${o.late}', o.late > 0 ? ErpColors.errorRed : ErpColors.successGreen),
        const SizedBox(width: 10),
        _tile('Changeovers', '${o.changeovers}', ErpColors.textPrimary),
      ]);

  Widget _tile(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: ErpColors.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  Widget _acceptBar(BuildContext context, PlannerController c, PlanObjective o) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(children: [
          const Icon(Icons.auto_fix_high, size: 18, color: ErpColors.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(text: TextSpan(
              style: const TextStyle(fontSize: 12, color: ErpColors.textSecondary),
              children: [
                TextSpan(text: '${o.machinesUsed} machines',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
                const TextSpan(text: ' scheduled · '),
                o.late > 0
                    ? TextSpan(text: '${o.totalLateDays} late-days total',
                        style: const TextStyle(color: ErpColors.errorRed, fontWeight: FontWeight.w700))
                    : const TextSpan(text: 'all orders hit their supply date',
                        style: TextStyle(color: ErpColors.successGreen, fontWeight: FontWeight.w700)),
              ],
            )),
          ),
          const SizedBox(width: 8),
          Obx(() => ElevatedButton.icon(
                onPressed: (o.placed == 0 || c.isAccepting.value)
                    ? null
                    : () => _onAccept(context, c),
                icon: c.isAccepting.value
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              )),
        ]),
      );

  Future<void> _onAccept(BuildContext context, PlannerController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept plan?'),
        content: const Text(
            'This records the plan as the day\'s plan of record. It does not create jobs '
            'or move machines — execution still goes through the normal job flow.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue, foregroundColor: Colors.white),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await c.accept();
    Get.snackbar(
      success ? 'Accepted' : 'Failed',
      success ? 'Plan recorded as the plan of record' : 'Could not accept the plan',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: success ? ErpColors.successGreen : ErpColors.errorRed,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );
  }

  Widget _aiCard(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            Text('AI PLAN RATIONALE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ErpColors.accentBlue)),
          ]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary, height: 1.4)),
        ]),
      );

  Widget _machineCard(MachinePlan mp) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(children: [
              Expanded(
                child: Text('Machine ${mp.machineID}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
              ),
              Text('${mp.heads} heads', style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
              if (mp.changeovers > 0) ...[
                const SizedBox(width: 8),
                Row(children: [
                  const Icon(Icons.sync, size: 12, color: ErpColors.warningAmber),
                  const SizedBox(width: 2),
                  Text('${mp.changeovers}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ErpColors.warningAmber)),
                ]),
              ],
            ]),
          ),
          for (final r in mp.rows) _sequenceRow(r),
        ]),
      );

  Widget _sequenceRow(PlanRow r) {
    final rate = _rateChip(r.rateSource);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ErpColors.bgMuted, shape: BoxShape.circle),
          child: Text('${r.sequence + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ErpColors.textSecondary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(r.elasticName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
              ),
              if (r.changeover) ...[
                const SizedBox(width: 6),
                const Icon(Icons.sync, size: 11, color: ErpColors.warningAmber),
                const Text(' changeover', style: TextStyle(fontSize: 10, color: ErpColors.warningAmber)),
              ],
            ]),
            const SizedBox(height: 2),
            Text('#${r.orderNo} · ${r.customer} · ${_n.format(r.qtyMeters)} m · ${r.heads} heads',
                style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: rate.$1, borderRadius: BorderRadius.circular(4)),
                child: Text(rate.$3, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: rate.$2)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.schedule, size: 12, color: ErpColors.textMuted),
              const SizedBox(width: 3),
              Text('${r.weavingDays}d → ${r.projectedFinish == null ? '—' : _d.format(DateTime.parse(r.projectedFinish!))}',
                  style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
            ]),
            const SizedBox(height: 3),
            r.late
                ? Text('Late ${r.lateWorkingDays}d',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ErpColors.errorRed))
                : Text('On time (due ${r.dueDate == null ? '—' : _d.format(DateTime.parse(r.dueDate!))})',
                    style: const TextStyle(fontSize: 11, color: ErpColors.successGreen)),
          ]),
        ),
      ]),
    );
  }

  // (bg, fg, label)
  (Color, Color, String) _rateChip(String source) {
    switch (source) {
      case 'posterior':
        return (ErpColors.statusCompletedBg, ErpColors.successGreen, 'learned rate');
      case 'plant':
        return (ErpColors.statusOpenBg, ErpColors.accentBlue, 'plant avg');
      default:
        return (ErpColors.bgMuted, ErpColors.textMuted, 'cold-start');
    }
  }

  Widget _unplaceableCard(PlannerController c) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: ErpColors.warningAmber, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: ErpColors.warningAmber),
            const SizedBox(width: 6),
            Text('Couldn\'t place (${c.unplaceable.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, color: ErpColors.warningAmber)),
          ]),
          const SizedBox(height: 8),
          ...c.unplaceable.map((u) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${u.elasticName} · #${u.orderNo} ${u.customer} · ${_n.format(u.qtyMeters)} m',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ErpColors.textPrimary)),
                  Text(u.reason, style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
                ]),
              )),
        ]),
      );

  Widget _emptyCard() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_outlined, size: 40, color: ErpColors.textMuted),
            SizedBox(height: 10),
            Text('Nothing to schedule',
                style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            SizedBox(height: 4),
            Text('No pending order lines could be placed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
          ]),
        ),
      );

  Widget _assumptions(PlannerController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: c.assumptions
            .map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.arrow_right, size: 14, color: ErpColors.textMuted),
                    Expanded(
                      child: Text(a, style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
                    ),
                  ]),
                ))
            .toList(),
      );
}
