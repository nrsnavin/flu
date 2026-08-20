import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/running_order_eta_controller.dart';

/// Live ETA card for an in-flight order on the order detail screen.
/// Mirrors OrderEtaCard's visual language so admins see the same
/// shape at order entry and during production.
class RunningOrderEtaCard extends StatelessWidget {
  final RunningOrderEtaController controller;
  const RunningOrderEtaCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Loading — first fetch, no prior result yet.
      if (controller.loading.value && controller.result.value == null) {
        return const _Loading();
      }
      // Backend explicitly said "not applicable" (NOTHING_REMAINING,
      // NO_ACTIVE_JOBS, NO_RATE, COMPUTE_ERROR, …). When the
      // controller captured a reason, use it — otherwise fall back
      // to the generic copy.
      if (controller.notApplicable.value) {
        final reason = controller.errorMsg.value;
        return _Placeholder(
          message: (reason != null && reason.isNotEmpty)
              ? reason
              : 'No estimate available for this order yet.',
          onRetry: controller.refreshEta,
        );
      }
      // Error path — backend or network failure. Visible state with
      // a retry instead of a blank screen.
      final r = controller.result.value;
      if (r == null) {
        return _Placeholder(
          message: controller.errorMsg.value?.isNotEmpty == true
              ? "Couldn't load estimate: ${controller.errorMsg.value}"
              : "Couldn't load estimated completion date.",
          tone: ErpColors.warningAmber,
          onRetry: controller.refreshEta,
        );
      }
      return _Card(r: r, controller: controller);
    });
  }
}

/// Visible empty / error state — replaces the prior silent SizedBox.shrink.
/// In-flight orders should always show *something* so the admin can tell
/// the card is alive (and click retry if it broke).
class _Placeholder extends StatelessWidget {
  final String message;
  final Color tone;
  final VoidCallback onRetry;
  _Placeholder({
    required this.message,
    required this.onRetry,
    Color? tone,
  }) : tone = tone ?? ErpColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_rounded, size: 16, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12, color: tone, fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Retry',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: ErpColors.accentBlue, letterSpacing: 0.4,
                )),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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

class _Card extends StatelessWidget {
  final RunningEtaResult r;
  final RunningOrderEtaController controller;
  const _Card({required this.r, required this.controller});

  @override
  Widget build(BuildContext context) {
    final late = r.late;
    final tone = late ? ErpColors.errorRed : ErpColors.successGreen;

    // Aggregate rate-source tally for the footer.
    final fromPosterior = r.rateSources['posterior'] ?? 0;
    final fromPlant     = r.rateSources['plant']     ?? 0;
    final fromCold      = r.rateSources['coldstart'] ?? 0;
    final fromMissing   = r.rateSources['missing']   ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                      Text('Predicted completion',
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
                IconButton(
                  tooltip: 'Recompute',
                  splashRadius: 16,
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  onPressed: controller.refreshEta,
                  icon: Icon(Icons.refresh_rounded, color: tone),
                ),
                const SizedBox(width: 2),
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

          // ── Why N days? (weaving + finishing split) ────────
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
                          label: 'Weaving (slowest job)',
                          sub: '${r.jobs.length} parallel '
                              'job${r.jobs.length == 1 ? '' : 's'}',
                          icon: Icons.precision_manufacturing_rounded,
                          tone: ErpColors.accentBlue,
                        ),
                      ),
                      const _Glyph('+'),
                      Expanded(
                        child: _SplitPart(
                          days: r.leadDays,
                          label: 'Finishing',
                          sub: 'Checking + packing',
                          icon: Icons.inventory_2_rounded,
                          tone: ErpColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Per-job breakdown ──────────────────────────────
          if (r.jobs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: ErpColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Text(
                'PER JOB',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: ErpColors.textSecondary, letterSpacing: 0.6,
                ),
              ),
            ),
            ...r.jobs.map((j) => _JobRow(job: j, weavingDays: r.weavingDays)),
            const SizedBox(height: 8),
          ],

          // ── Rate-source provenance footer ─────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                if (fromPosterior > 0)
                  _SourcePill(
                    label: '$fromPosterior learned',
                    tone: ErpColors.successGreen,
                    icon: Icons.psychology_rounded,
                  ),
                if (fromPlant > 0)
                  _SourcePill(
                    label: '$fromPlant plant avg',
                    tone: ErpColors.accentBlue,
                    icon: Icons.factory_rounded,
                  ),
                if (fromCold > 0)
                  _SourcePill(
                    label: '$fromCold cold-start',
                    tone: ErpColors.warningAmber,
                    icon: Icons.ac_unit_rounded,
                  ),
                if (fromMissing > 0)
                  _SourcePill(
                    label: '$fromMissing no rate',
                    tone: ErpColors.errorRed,
                    icon: Icons.help_outline_rounded,
                  ),
              ],
            ),
          ),

          // ── Assumptions footer ─────────────────────────────
          if (r.assumptions.isNotEmpty)
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
                              fontSize: 10, color: ErpColors.textMuted, height: 1.4,
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

/// One row in the per-job breakdown. Bar shows how this job's weaving
/// time compares to the slowest job — the slowest fills the bar.
class _JobRow extends StatelessWidget {
  final RunningEtaJob job;
  final int weavingDays;
  const _JobRow({required this.job, required this.weavingDays});
  @override
  Widget build(BuildContext context) {
    final fraction = weavingDays > 0
        ? (job.jobDays / weavingDays).clamp(0.0, 1.0)
        : 0.0;
    final isCritical = job.jobDays == weavingDays;
    final tone = isCritical ? ErpColors.accentBlue : ErpColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              job.machineLabel != null && job.machineLabel!.isNotEmpty
                  ? job.machineLabel!
                  : 'Job ${job.jobOrderNo ?? ''}',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: ErpColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: ErpColors.bgMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: tone.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              '${job.jobDays}d',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitPart extends StatelessWidget {
  final int days;
  final String label, sub;
  final IconData icon;
  final Color tone;
  const _SplitPart({
    required this.days, required this.label, required this.sub,
    required this.icon, required this.tone,
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

class _SourcePill extends StatelessWidget {
  final String label;
  final Color tone;
  final IconData icon;
  const _SourcePill({required this.label, required this.tone, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tone.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: tone),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 9, color: tone, fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              )),
        ],
      ),
    );
  }
}
