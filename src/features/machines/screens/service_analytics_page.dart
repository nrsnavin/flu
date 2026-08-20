import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/mini_bar_chart.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/service_analytics_controller.dart';
import '../models/service_analytics.dart';
import 'machine_trend_page.dart';

// ══════════════════════════════════════════════════════════════
//  WHAT THE FLOOR COSTS, AND WHAT IS WORTH A LOOK
//
//  ── The findings section is written with restraint on purpose ──
//  These point at named technicians' work. The section is called
//  "Patterns worth checking" and never "anomalies" or anything
//  stronger; every finding prints the ordinary explanation beside it;
//  and "not enough history" is said plainly rather than dressed up as
//  "nothing found", because from eleven service logs those are very
//  different statements and only one of them is honest.
//
//  The word fraud does not appear here and must not. A number that
//  makes somebody look at a technician sideways should have to earn
//  it in front of the evidence, not in a heading on a phone.
// ══════════════════════════════════════════════════════════════

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class ServiceAnalyticsPage extends StatefulWidget {
  const ServiceAnalyticsPage({super.key});

  @override
  State<ServiceAnalyticsPage> createState() => _ServiceAnalyticsPageState();
}

class _ServiceAnalyticsPageState extends State<ServiceAnalyticsPage> {
  late final ServiceAnalyticsController c;

  @override
  void initState() {
    super.initState();
    Get.delete<ServiceAnalyticsController>(force: true);
    c = Get.put(ServiceAnalyticsController());
  }

  @override
  void dispose() {
    Get.delete<ServiceAnalyticsController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Service Spend'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.data.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null) {
          return _Message(text: c.errorMsg.value!, onRetry: c.fetch);
        }
        final d = c.data.value;
        if (d == null) return const SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _windowPicker(),
              const SizedBox(height: 10),
              _spendCard(d.spend),
              const SizedBox(height: 10),
              _findingsCard(d.anomalies),
              const SizedBox(height: 10),
              _costliestCard(d.costliest),
            ],
          ),
        );
      }),
    );
  }

  Widget _windowPicker() => Obx(() => Row(
        children: [
          for (final w in const [90, 180, 365])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(w == 365 ? '1 year' : '$w days'),
                selected: c.days.value == w,
                onSelected: (_) => c.setWindow(w),
              ),
            ),
        ],
      ));

  Widget _spendCard(ServiceSpend s) => _Card(
        title: 'Spend',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_inr.format(s.total),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            Text('${s.services} services in this window',
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
            const SizedBox(height: 12),
            MiniBarChart(
              bars: [
                for (final p in s.series)
                  MiniBar(label: p.shortMonth, value: p.total),
              ],
              barColor: ErpColors.accentBlue,
              format: _inr.format,
              emptyLabel: 'No service spend in this window.',
            ),
            const SizedBox(height: 12),
            // Typical and mean side by side: where they diverge, one
            // big month is carrying the average, and seeing both is
            // the only way to notice.
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Typical month',
                    value: _inr.format(s.typicalMonth),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Mean month',
                    value: _inr.format(s.meanMonth),
                    muted: true,
                  ),
                ),
              ],
            ),
            if (s.byType.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('By type',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textSecondary)),
              const SizedBox(height: 4),
              for (final t in s.byType.take(5))
                _Row(left: t.name, right: _inr.format(t.amount)),
            ],
          ],
        ),
      );

  Widget _findingsCard(Anomalies a) => _Card(
        title: 'Patterns worth checking',
        subtitle: 'A list of places to look — not a list of findings against anyone.',
        child: Builder(builder: (_) {
          // Too little history and nothing unusual are different
          // statements, and only one of them is honest from a handful
          // of service logs.
          if (!a.ready) {
            return Text(
              a.reason ?? 'Not enough service history to say anything yet.',
              style: const TextStyle(
                  fontSize: 13, color: ErpColors.textSecondary),
            );
          }
          if (a.findings.isEmpty) {
            return Text(
              'Nothing stands out. ${a.services} services checked.',
              style: const TextStyle(
                  fontSize: 13, color: ErpColors.textSecondary),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in a.findings) _FindingTile(finding: f),
            ],
          );
        }),
      );

  Widget _costliestCard(List<CostlyMachine> rows) => _Card(
        title: 'Costliest machines',
        child: rows.isEmpty
            ? const Text('Nothing serviced in this window.',
                style:
                    TextStyle(fontSize: 13, color: ErpColors.textSecondary))
            : Column(
                children: [
                  for (final m in rows.take(8))
                    InkWell(
                      onTap: () => Get.to(() => MachineTrendPage(
                            machineId: m.machineId,
                            machineCode: m.machineID,
                          )),
                      child: _Row(
                        left: '${m.machineID}  ·  ${m.services} services',
                        right: _inr.format(m.total),
                      ),
                    ),
                ],
              ),
      );
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(finding.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Text(finding.detail,
              style: const TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary)),
          if (finding.innocent.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Never collapsed, never behind a tap. A statistic without
            // the ordinary explanation beside it reads as a charge.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: ErpColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    finding.innocent,
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: ErpColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Small shared pieces ───────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 11, color: ErpColors.textMuted)),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: ErpColors.textMuted)),
          Text(value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: muted ? ErpColors.textSecondary : ErpColors.textPrimary,
              )),
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(left,
                  style: const TextStyle(
                      fontSize: 13, color: ErpColors.textSecondary)),
            ),
            Text(right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ErpColors.textPrimary)),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ErpColors.textSecondary)),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}
