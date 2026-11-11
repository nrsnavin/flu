import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/bonus_controller.dart';

class BonusPage extends StatelessWidget {
  const BonusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmpBonusController(), tag: 'bonus');
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('Yearly Bonus', style: ErpTextStyles.pageTitle),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _Error(msg: c.errorMsg.value!, onRetry: c.fetch);
        }
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _YearSelector(c: c),
              const SizedBox(height: 12),
              if (c.record.value == null)
                const _NoBonusCard()
              else ...[
                _BonusHeroCard(c: c),
                const SizedBox(height: 14),
                _TierCard(record: c.record.value!),
                const SizedBox(height: 14),
                _BreakdownCard(record: c.record.value!),
                const SizedBox(height: 14),
                _DownloadButton(c: c),
              ],
            ],
          ),
        );
      }),
    );
  }
}

// ── Year selector ──────────────────────────────────────────────
class _YearSelector extends StatelessWidget {
  final EmpBonusController c;
  const _YearSelector({required this.c});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(children: [
        const Icon(Icons.event_outlined,
            color: ErpColors.accentBlue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Year ${c.selectedYear.value}',
              style: ErpTextStyles.cardTitle),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => c.changeYear(c.selectedYear.value - 1),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => c.changeYear(c.selectedYear.value + 1),
        ),
      ]),
    );
  }
}

// ── Hero amount card ───────────────────────────────────────────
class _BonusHeroCard extends StatelessWidget {
  final EmpBonusController c;
  const _BonusHeroCard({required this.c});
  @override
  Widget build(BuildContext context) {
    final r      = c.record.value!;
    final cfg    = c.config.value;
    final status = SafeJson.asString(r['status'], 'pending').toLowerCase();
    final amount = SafeJson.asDouble(r['bonusAmount']);
    final label  = SafeJson.asStringOrNull(cfg?['bonusLabel']);
    final dt     = SafeJson.asLocalDateTime(cfg?['bonusDate']);
    final payoutWhen =
        dt == null ? null : DateFormat('dd MMM yyyy').format(dt);

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.workspace_premium_outlined,
                color: ErpColors.accentLight, size: 18),
            const SizedBox(width: 6),
            Text((label?.isNotEmpty ?? false)
                    ? label!.toUpperCase()
                    : 'YEARLY BONUS',
                style: const TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
            const Spacer(),
            _StatusChip(status),
          ]),
          const SizedBox(height: 14),
          Text('₹ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const Text('Final Bonus Payable',
              style:
                  TextStyle(color: ErpColors.textOnDarkSub, fontSize: 12)),
          if (payoutWhen != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: ErpColors.textOnDarkSub, size: 12),
              const SizedBox(width: 4),
              Text('Payout date: $payoutWhen',
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 11)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Tier card ──────────────────────────────────────────────────
class _TierCard extends StatelessWidget {
  final Map<String, dynamic> record;
  const _TierCard({required this.record});
  @override
  Widget build(BuildContext context) {
    final tier  = SafeJson.asString(record['attendanceTier'], 'C');
    final mult  = SafeJson.asDouble(record['multiplier']);
    final rate  = SafeJson.asDouble(record['attendanceRate']);
    final days  = SafeJson.asInt(record['attendanceDays']);
    final total = SafeJson.asInt(record['totalWorkingDays']);

    Color tierColor;
    String tierLabel;
    switch (tier) {
      case 'S': tierColor = ErpColors.successGreen; tierLabel = 'Excellent'; break;
      case 'A': tierColor = ErpColors.accentBlue;   tierLabel = 'Good';      break;
      case 'B': tierColor = ErpColors.warningAmber; tierLabel = 'Average';   break;
      default:  tierColor = ErpColors.errorRed;     tierLabel = 'Below Avg.';
    }

    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.12),
            border: Border.all(color: tierColor.withValues(alpha: 0.45), width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(tier,
                style: TextStyle(
                    color: tierColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tier $tier · $tierLabel',
                  style: ErpTextStyles.cardTitle),
              const SizedBox(height: 2),
              Text('Multiplier: ×${mult.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: tierColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Attendance ${rate.toStringAsFixed(1)}%  ($days / $total days)',
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Breakdown card ─────────────────────────────────────────────
class _BreakdownCard extends StatelessWidget {
  final Map<String, dynamic> record;
  const _BreakdownCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final hourly = SafeJson.asDouble(record['hourlyRate']);
    final hours  = SafeJson.asDouble(record['hoursWorked']);
    final earn   = SafeJson.asDouble(record['annualEarnings']);
    final pct    = SafeJson.asDouble(record['bonusPercent']);
    final raw    = SafeJson.asDouble(record['rawBonusAmount']);

    return ErpSectionCard(
      title: 'BREAKDOWN',
      icon: Icons.calculate_outlined,
      child: Column(children: [
        _kv('Hourly Rate',     '₹ ${hourly.toStringAsFixed(2)}'),
        _kv('Hours Worked',    '${hours.toStringAsFixed(0)} hrs'),
        _kv('Annual Earnings', '₹ ${earn.toStringAsFixed(0)}'),
        _kv('Bonus %',         '${pct.toStringAsFixed(0)}%'),
        _kv('Raw Bonus',       '₹ ${raw.toStringAsFixed(0)}'),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(k,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          ),
          Text(v,
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

// ── Download button ────────────────────────────────────────────
class _DownloadButton extends StatelessWidget {
  final EmpBonusController c;
  const _DownloadButton({required this.c});
  @override
  Widget build(BuildContext context) {
    return Obx(() => SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.successGreen,
              disabledBackgroundColor:
                  ErpColors.successGreen.withValues(alpha: 0.55),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: c.isDownloading.value ? null : c.downloadPdf,
            icon: c.isDownloading.value
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.white, size: 20),
            label: Text(
              c.isDownloading.value
                  ? 'Generating PDF…'
                  : 'Download Certificate (PDF)',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14),
            ),
          ),
        ));
  }
}

// ── Status chip ────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'paid':
        bg = ErpColors.successGreen.withValues(alpha: 0.18);
        fg = ErpColors.successGreen;
        break;
      default:
        bg = ErpColors.warningAmber.withValues(alpha: 0.22);
        fg = ErpColors.warningAmber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
    );
  }
}

// ── Empty / Error ──────────────────────────────────────────────
class _NoBonusCard extends StatelessWidget {
  const _NoBonusCard();
  @override
  Widget build(BuildContext context) => Container(
        decoration: ErpDecorations.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Column(
          children: const [
            Icon(Icons.workspace_premium_outlined,
                size: 36, color: ErpColors.textMuted),
            SizedBox(height: 8),
            Text('No bonus for this year yet',
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text(
              'Yearly bonus is generated by your supervisor. Check back closer to the payout date.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
}

class _Error extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _Error({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: ErpColors.textMuted, size: 36),
              const SizedBox(height: 10),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
