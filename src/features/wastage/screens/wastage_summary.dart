import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/add_wastage_controller.dart';
import '../models/checkingJobModel.dart';

// ══════════════════════════════════════════════════════════════
//  WASTAGE SUMMARY / ANALYTICS PAGE
//  - KPI strip (total, entries, avg per job, total penalty)
//  - Day range selector: 7 / 30 / 90 days
//  - Daily trend bar chart (custom painted)
//  - Employee leaderboard with ranked waste bars
//  - Elastic type breakdown donut-style bar chart
//  - Wastage by job status horizontal bar chart
// ══════════════════════════════════════════════════════════════

class WastageSummaryPage extends StatefulWidget {
  const WastageSummaryPage({super.key});

  @override
  State<WastageSummaryPage> createState() => _WastageSummaryPageState();
}

class _WastageSummaryPageState extends State<WastageSummaryPage> {
  late final WastageAnalyticsController c;

  @override
  void initState() {
    super.initState();
    Get.delete<WastageAnalyticsController>(force: true);
    c = Get.put(WastageAnalyticsController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Obx(() {
        if (c.isLoading.value && c.analytics.value == null) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.analytics.value == null) {
          return _ErrorState(msg: c.errorMsg.value!, retry: c.fetch);
        }
        final a = c.analytics.value;
        if (a == null) return const SizedBox.shrink();

        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
            children: [
              // Day selector
              _DaySelector(c: c),
              const SizedBox(height: 14),
              // KPIs
              _KPIStrip(a: a),
              const SizedBox(height: 14),
              // Trend chart
              _TrendCard(trend: a.trend, days: c.days.value),
              const SizedBox(height: 14),
              // Employee leaderboard
              _EmployeeLeaderboard(employees: a.topEmployees),
              const SizedBox(height: 14),
              // Elastic breakdown
              _ElasticBreakdown(elastics: a.byElastic),
              const SizedBox(height: 14),
              // By status
              _ByStatusCard(statuses: a.byStatus),
            ],
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new,
          size: 16, color: Colors.white),
      onPressed: () => Get.back(),
    ),
    titleSpacing: 4,
    title: Obx(() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Wastage Analytics',
            style: ErpTextStyles.pageTitle),
        Text(
          'Last ${c.days.value} days',
          style: const TextStyle(
              color: ErpColors.textOnDarkSub, fontSize: 10),
        ),
      ],
    )),
    actions: [
      Obx(() => IconButton(
        icon: c.isLoading.value
            ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.refresh_rounded,
            color: Colors.white, size: 20),
        onPressed: c.isLoading.value ? null : c.fetch,
      )),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  DAY SELECTOR
// ══════════════════════════════════════════════════════════════

class _DaySelector extends StatelessWidget {
  final WastageAnalyticsController c;
  const _DaySelector({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() => Row(children: [
    const Text('Period:',
        style: TextStyle(
            color: ErpColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700)),
    const SizedBox(width: 10),
    ...[7, 30, 90].map((d) {
      final active = c.days.value == d;
      return GestureDetector(
        onTap: () => c.days.value = d,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? ErpColors.accentBlue : ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active
                    ? ErpColors.accentBlue
                    : ErpColors.borderLight),
          ),
          child: Text('${d}d',
              style: TextStyle(
                  color: active ? Colors.white : ErpColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
      );
    }).toList(),
  ]));
}

// ══════════════════════════════════════════════════════════════
//  KPI STRIP
// ══════════════════════════════════════════════════════════════

class _KPIStrip extends StatelessWidget {
  final WastageAnalytics a;
  const _KPIStrip({required this.a});

  @override
  Widget build(BuildContext context) => Row(children: [
    _KPI('TOTAL WASTAGE', '${a.totalWastage.toStringAsFixed(1)} m',
        ErpColors.errorRed, Icons.warning_amber_rounded),
    const SizedBox(width: 10),
    _KPI('ENTRIES', '${a.totalCount}',
        ErpColors.accentBlue, Icons.list_alt_rounded),
    const SizedBox(width: 10),
    _KPI('PENALTY', '₹${a.totalPenalty.toStringAsFixed(0)}',
        ErpColors.warningAmber, Icons.monetization_on_outlined),
  ]);
}

class _KPI extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _KPI(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: ErpColors.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  TREND CHART  (custom painted bar chart)
// ══════════════════════════════════════════════════════════════

class _TrendCard extends StatelessWidget {
  final List<DailyWastageStat> trend;
  final int days;
  const _TrendCard({required this.trend, required this.days});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return _EmptyCard('No trend data for this period');

    // Only show last 30 bars max to keep it readable
    final data = trend.length > 30 ? trend.sublist(trend.length - 30) : trend;

    return ErpSectionCard(
      title: 'DAILY WASTAGE TREND',
      icon: Icons.show_chart_rounded,
      child: Column(children: [
        SizedBox(
          height: 130,
          child: _BarChart(data: data),
        ),
        const SizedBox(height: 8),
        // X axis labels (first, mid, last)
        if (data.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtDate(data.first.dateTime),
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 9)),
              if (data.length > 2)
                Text(_fmtDate(data[data.length ~/ 2].dateTime),
                    style: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 9)),
              Text(_fmtDate(data.last.dateTime),
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 9)),
            ],
          ),
      ]),
    );
  }

  String _fmtDate(DateTime d) => DateFormat('dd MMM').format(d);
}

class _BarChart extends StatelessWidget {
  final List<DailyWastageStat> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold(0.0, (m, d) => math.max(m, d.total));
    if (maxVal == 0) return const SizedBox.shrink();

    return LayoutBuilder(builder: (ctx, constraints) {
      final barW = (constraints.maxWidth - (data.length - 1) * 3) / data.length;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final stat   = entry.value;
          final height = (stat.total / maxVal) * constraints.maxHeight;
          final isToday = stat.date ==
              DateTime.now().toIso8601String().substring(0, 10);
          return Padding(
            padding: EdgeInsets.only(
                right: entry.key < data.length - 1 ? 3.0 : 0.0),
            child: Tooltip(
              message:
              '${_fmt(stat.dateTime)}: ${stat.total.toStringAsFixed(1)} m',
              child: GestureDetector(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (height > 20)
                        Text(
                          stat.total > 9
                              ? stat.total.toStringAsFixed(0)
                              : stat.total.toStringAsFixed(1),
                          style: TextStyle(
                              color: isToday
                                  ? ErpColors.errorRed
                                  : ErpColors.accentBlue,
                              fontSize: 7,
                              fontWeight: FontWeight.w800),
                        ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        width: barW.clamp(4.0, 32.0),
                        height: height.clamp(3.0, constraints.maxHeight - 12),
                        decoration: BoxDecoration(
                          color: isToday
                              ? ErpColors.errorRed
                              : ErpColors.accentBlue.withOpacity(0.75),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ),
                    ]),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  String _fmt(DateTime d) => DateFormat('dd MMM').format(d);
}

// ══════════════════════════════════════════════════════════════
//  EMPLOYEE LEADERBOARD
// ══════════════════════════════════════════════════════════════

class _EmployeeLeaderboard extends StatelessWidget {
  final List<EmployeeWastageStat> employees;
  const _EmployeeLeaderboard({required this.employees});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) return _EmptyCard('No employee data');

    final maxTotal = employees.fold(0.0, (m, e) => math.max(m, e.total));

    return ErpSectionCard(
      title: 'EMPLOYEE WASTAGE LEADERBOARD',
      icon: Icons.leaderboard_rounded,
      child: Column(
        children: employees.asMap().entries.map((entry) {
          final i = entry.key;
          final emp = entry.value;
          final pct = maxTotal > 0 ? emp.total / maxTotal : 0.0;
          final color = i == 0
              ? ErpColors.errorRed
              : i == 1
              ? ErpColors.warningAmber
              : i < 5
              ? const Color(0xFF7C3AED)
              : ErpColors.accentBlue;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        i < 3 ? _medals[i] : '${i + 1}.',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(emp.name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: i == 0
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                        color: ErpColors.textPrimary),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const Spacer(),
                              Text('${emp.total.toStringAsFixed(1)} m',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: color)),
                            ]),
                            if (emp.department?.isNotEmpty ?? false)
                              Text(emp.department!,
                                  style: const TextStyle(
                                      color: ErpColors.textMuted, fontSize: 10)),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  // Wastage bar
                  Row(children: [
                    const SizedBox(width: 30),
                    Expanded(
                      child: Stack(children: [
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: ErpColors.borderLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          widthFactor: pct.clamp(0.0, 1.0),
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${emp.count}×',
                        style: const TextStyle(
                            color: ErpColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ]),
                ]),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ELASTIC BREAKDOWN
// ══════════════════════════════════════════════════════════════

class _ElasticBreakdown extends StatelessWidget {
  final List<ElasticWastageStat> elastics;
  const _ElasticBreakdown({required this.elastics});

  static const _colors = [
    Color(0xFF1D6FEB),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFF0D9488),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    if (elastics.isEmpty) return _EmptyCard('No elastic data');

    final total = elastics.fold(0.0, (s, e) => s + e.total);

    return ErpSectionCard(
      title: 'WASTAGE BY ELASTIC TYPE',
      icon: Icons.grid_on_rounded,
      child: Column(children: [
        // Segmented bar
        _SegmentedBar(elastics: elastics, colors: _colors, total: total),
        const SizedBox(height: 14),
        // Legend
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: elastics.asMap().entries.map((e) {
            final color = _colors[e.key % _colors.length];
            final pct = total > 0
                ? (e.value.total / total * 100).toStringAsFixed(1)
                : '0';
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 5),
              Text(e.value.name,
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Text('$pct%',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ]);
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Horizontal bars
        ...elastics.asMap().entries.map((e) {
          final color = _colors[e.key % _colors.length];
          final pct = total > 0 ? e.value.total / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(
                width: 90,
                child: Text(e.value.name,
                    style: const TextStyle(
                        color: ErpColors.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Stack(children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${e.value.total.toStringAsFixed(1)}m',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.right,
                ),
              ),
            ]),
          );
        }).toList(),
      ]),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  final List<ElasticWastageStat> elastics;
  final List<Color> colors;
  final double total;
  const _SegmentedBar({
    required this.elastics,
    required this.colors,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 18,
        child: Row(
          children: elastics.asMap().entries.map((e) {
            final pct = total > 0 ? e.value.total / total : 0.0;
            final color = colors[e.key % colors.length];
            return Flexible(
              flex: (pct * 1000).round(),
              child: Container(color: color),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  BY JOB STATUS
// ══════════════════════════════════════════════════════════════

class _ByStatusCard extends StatelessWidget {
  final List<StatusWastageStat> statuses;
  const _ByStatusCard({required this.statuses});

  Color _statusColor(String s) {
    switch (s) {
      case 'weaving':   return const Color(0xFF7C3AED);
      case 'finishing': return const Color(0xFF0891B2);
      case 'checking':  return ErpColors.warningAmber;
      case 'packing':   return ErpColors.successGreen;
      case 'completed': return ErpColors.textSecondary;
      default:          return ErpColors.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) return _EmptyCard('No status data');

    final maxTotal = statuses.fold(0.0, (m, s) => math.max(m, s.total));

    return ErpSectionCard(
      title: 'WASTAGE BY JOB STATUS',
      icon: Icons.donut_small_rounded,
      child: Column(
        children: statuses.map((s) {
          final color = _statusColor(s.status);
          final pct = maxTotal > 0 ? s.total / maxTotal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.status[0].toUpperCase() + s.status.substring(1),
                      style: const TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text('${s.total.toStringAsFixed(1)} m',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Text('(${s.count}×)',
                        style: const TextStyle(
                            color: ErpColors.textMuted, fontSize: 10)),
                  ]),
                  const SizedBox(height: 5),
                  Stack(children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: ErpColors.bgMuted,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 600),
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ]),
                ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String msg;
  const _EmptyCard(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
    ),
    child: Center(
      child: Text(msg,
          style: const TextStyle(
              color: ErpColors.textMuted, fontSize: 12)),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorState({required this.msg, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline,
          size: 40, color: ErpColors.textMuted),
      const SizedBox(height: 12),
      const Text('Failed to load analytics',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      Text(msg,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: retry,
        style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue, elevation: 0),
        icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
        label: const Text('Retry',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}