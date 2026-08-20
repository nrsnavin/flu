import 'package:flutter/material.dart';

import '../../../core/widgets/mini_bar_chart.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../report_series.dart';

// ══════════════════════════════════════════════════════════════
//  THE CHART THE FIVE REPORT SCREENS WERE MISSING
//
//  Each of the five web report pages leads with a bar chart over the
//  period; the mobile companions shipped with the tiles and the
//  breakdown list and no chart at all. The tiles answer "how much" —
//  the chart answers "was it steady, or was it one good Tuesday?",
//  and that second question is the one somebody on the floor is
//  actually holding when they open a report on a phone.
//
//  ── The subtitle is not decoration ─────────────────────────────
//  It says whether a bar is a day or a month, because the screen
//  switches between them on its own once a period is longer than a
//  month, and a bar whose width you have misread is worse than no
//  bar. See report_series.dart for why it switches.
// ══════════════════════════════════════════════════════════════

class ReportChartCard extends StatelessWidget {
  const ReportChartCard({
    super.key,
    required this.title,
    required this.series,
    required this.metricKey,
    required this.color,
    required this.format,
    this.signed = false,
    this.emptyLabel = 'Nothing in this period.',
  });

  final String title;
  final List<Map<String, dynamic>> series;
  final String metricKey;
  final Color color;

  /// How a value reads to a person — rupees, metres, kilos.
  final String Function(double) format;

  /// For a net figure that can go below zero.
  final bool signed;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final bars = buildReportBars(series, metricKey);

    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (bars.isNotEmpty)
                Text(
                  _looksMonthly(bars) ? 'by month' : 'by day',
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          MiniBarChart(
            bars: bars,
            barColor: color,
            height: 130,
            format: format,
            signed: signed,
            negativeColor: signed ? ErpColors.errorRed : null,
            emptyLabel: emptyLabel,
          ),
        ],
      ),
    );
  }

  /// Month buckets are labelled with a month name; day buckets with a
  /// day number. Reading the label back is more honest than
  /// recomputing the threshold here and letting the two drift.
  bool _looksMonthly(List<MiniBar> bars) =>
      bars.any((b) => b.label.isNotEmpty && int.tryParse(b.label) == null);
}
