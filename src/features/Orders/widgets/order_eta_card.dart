import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/order_eta_controller.dart';

/// Live ETA card rendered above the submit button on Add Order.
/// Reactive to the OrderEtaController — silently absent while the
/// admin hasn't entered any elastic lines, shows a spinner during
/// the call, then snaps into either an estimate or a quiet hide
/// when the backend is unreachable. Never blocks order submission.
class OrderEtaCard extends StatelessWidget {
  final OrderEtaController controller;
  const OrderEtaCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loading.value && controller.result.value == null) {
        return const _Loading();
      }
      final r = controller.result.value;
      if (r == null) return const SizedBox.shrink();
      return _Card(r: r, controller: controller);
    });
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: ErpColors.accentBlue),
        ),
        SizedBox(width: 10),
        Text('Estimating completion date…',
            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
      ]),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _Card extends StatelessWidget {
  final OrderEtaResult r;
  final OrderEtaController controller;
  const _Card({required this.r, required this.controller});

  @override
  Widget build(BuildContext context) {
    final late = r.late;
    final tone = late ? ErpColors.errorRed : ErpColors.successGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header band ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: tone.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: tone.withOpacity(0.18))),
            ),
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: tone.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    late ? Icons.warning_amber_rounded : Icons.event_available_rounded,
                    color: tone, size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Estimated completion',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: ErpColors.textSecondary, letterSpacing: 0.6,
                          )),
                      const SizedBox(height: 2),
                      Text(_fmtDate(r.expectedDate),
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900,
                            color: tone,
                          )),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tone.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    late
                        ? '${r.lateWorkingDays}d late vs supply'
                        : '${r.workingDays} working days',
                    style: TextStyle(
                      color: tone, fontSize: 10, fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Why N days? (machine vs order processing split) ─
          if (r.weavingDays + r.leadDays > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHY ${r.workingDays} WORKING DAYS',
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: ErpColors.textSecondary, letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _SplitPart(
                          days: r.weavingDays,
                          label: 'Machine planned',
                          sub: '${r.machines} machine${r.machines == 1 ? '' : 's'} weaving'
                              '${r.machineDays > 0 ? ' · ${r.machineDays} machine-days' : ''}',
                          icon: Icons.precision_manufacturing_rounded,
                          tone: ErpColors.accentBlue,
                        ),
                      ),
                      const _Glyph('+'),
                      Expanded(
                        child: _SplitPart(
                          days: r.leadDays,
                          label: 'Order processing',
                          sub: 'Prep + finishing',
                          icon: Icons.inventory_2_rounded,
                          tone: ErpColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Range row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                _ChipStat(label: 'Best case', value: _fmtDate(r.optimistic), tone: ErpColors.successGreen),
                const SizedBox(width: 8),
                _ChipStat(label: 'Worst case', value: _fmtDate(r.pessimistic), tone: ErpColors.warningAmber),
              ],
            ),
          ),

          // ── Numbers strip ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(
              children: [
                _Stat(label: 'Total m', value: '${r.totalMeters}'),
                _Stat(label: 'Machines', value: '${r.machines}'),
                _Stat(label: 'Rate', value: '${r.effRate}/d'),
                _Stat(label: 'Conf', value: '${(r.confidence * 100).round()}%'),
              ],
            ),
          ),

          // ── What-if curve ─────────────────────────────────
          if (r.whatIf.length > 1) ...[
            Divider(height: 1, color: ErpColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                'WHAT IF I DEDICATE MORE MACHINES',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: ErpColors.textSecondary, letterSpacing: 0.6,
                ),
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                itemCount: r.whatIf.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final w = r.whatIf[i];
                  final isCurrent = w.machines == r.machines;
                  return GestureDetector(
                    onTap: () {
                      controller.machinesOverride.value = w.machines;
                    },
                    child: Container(
                      width: 110,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? ErpColors.accentBlue.withOpacity(0.08)
                            : ErpColors.bgMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrent
                              ? ErpColors.accentBlue
                              : ErpColors.borderLight,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${w.machines} machine${w.machines == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 10, color: ErpColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 2),
                          Text(_fmtDate(w.expectedDate),
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800,
                                color: ErpColors.textPrimary,
                              )),
                          const Spacer(),
                          Text('${w.workingDays}d',
                              style: TextStyle(
                                fontSize: 10, color: ErpColors.textMuted,
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // ── Assumptions (collapsible footer) ──────────────
          if (r.assumptions.isNotEmpty || r.usedColdStart)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: r.assumptions.map((a) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 4, right: 6),
                        child: Icon(Icons.circle, size: 4, color: ErpColors.textMuted),
                      ),
                      Expanded(
                        child: Text(a,
                            style: TextStyle(
                              fontSize: 10, color: ErpColors.textMuted,
                              height: 1.4,
                            )),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: ErpColors.textPrimary,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 9, color: ErpColors.textSecondary,
                letterSpacing: 0.4,
              )),
        ],
      ),
    );
  }
}

/// One side of the "why N days" breakdown — a labelled day count for
/// either the machine-weaving portion or the order-processing buffer.
class _SplitPart extends StatelessWidget {
  final int days;
  final String label, sub;
  final IconData icon;
  final Color tone;
  const _SplitPart({
    required this.days,
    required this.label,
    required this.sub,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tone.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: tone),
              const SizedBox(width: 5),
              Text('${days}d',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: tone,
                  )),
            ],
          ),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: ErpColors.textPrimary,
              )),
          const SizedBox(height: 1),
          Text(sub,
              style: TextStyle(
                fontSize: 9, color: ErpColors.textMuted, height: 1.3,
              )),
        ],
      ),
    );
  }
}

/// Tiny "+" separator between the two split parts.
class _Glyph extends StatelessWidget {
  final String symbol;
  const _Glyph(this.symbol);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(symbol,
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900,
            color: ErpColors.textMuted,
          )),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final String label, value;
  final Color tone;
  const _ChipStat({required this.label, required this.value, required this.tone});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tone.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tone.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.chevron_right_rounded, size: 12, color: tone),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 9, color: tone, fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      )),
                  Text(value,
                      style: TextStyle(
                        fontSize: 11, color: ErpColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
