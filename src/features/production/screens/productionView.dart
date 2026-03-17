// ══════════════════════════════════════════════════════════════
//  PRODUCTION RANGE PAGE
//  File: lib/src/features/production/screens/production_range_page.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/production/screens/shiftViewPage.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../shiftPlanView/screens/shiftPlanDetail.dart';
import '../controllers/productionController.dart';
import '../models/productionBrief.dart';

class ProductionRangePage extends StatefulWidget {
  const ProductionRangePage({super.key});

  @override
  State<ProductionRangePage> createState() => _ProductionRangePageState();
}

class _ProductionRangePageState extends State<ProductionRangePage> {
  late final ProductionRangeController _c;

  @override
  void initState() {
    super.initState();
    Get.delete<ProductionRangeController>(force: true);
    _c = Get.put(ProductionRangeController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: Colors.white,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Production Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Date range view',
              style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _c.fetchRange,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
        ),
      ),
      body: Column(
        children: [
          _DateRangeBar(c: _c),
          _RangeKpiStrip(c: _c),
          Expanded(child: _Body(c: _c)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DATE RANGE PICKER BAR
// ══════════════════════════════════════════════════════════════
class _DateRangeBar extends StatelessWidget {
  final ProductionRangeController c;
  const _DateRangeBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.navyDark,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        children: [
          // Date picker row
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: 'From',
                  onTap: () async {
                    final d = await _pick(context, c.startDate.value);
                    if (d != null) {
                      final end = c.endDate.value;
                      if (end != null && d.isAfter(end)) {
                        c.setDateRange(d, d);
                      } else {
                        c.setDateRange(d, end ?? d);
                      }
                    }
                  },
                  dateObs: c.startDate,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: ErpColors.textOnDarkSub,
                  size: 16,
                ),
              ),
              Expanded(
                child: _DateButton(
                  label: 'To',
                  onTap: () async {
                    final d = await _pick(context, c.endDate.value);
                    if (d != null) {
                      final start = c.startDate.value;
                      if (start != null && d.isBefore(start)) {
                        c.setDateRange(d, d);
                      } else {
                        c.setDateRange(start ?? d, d);
                      }
                    }
                  },
                  dateObs: c.endDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick preset chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip('Today', 'today', c),
                _PresetChip('7 Days', 'week', c),
                _PresetChip('Month', 'month', c),
                _PresetChip('30 Days', 'last30', c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pick(BuildContext context, DateTime? initial) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ErpColors.accentBlue,
              surface: Color(0xFF1B2B45),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Rxn<DateTime> dateObs;
  const _DateButton({
    required this.label,
    required this.onTap,
    required this.dateObs,
  });

  @override
  Widget build(BuildContext context) => Obx(() {
    final d = dateObs.value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: ErpColors.accentBlue,
              size: 14,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 9,
                  ),
                ),
                Text(
                  d == null
                      ? 'Select date'
                      : '${d.day.toString().padLeft(2, '0')} '
                            '${_months[d.month - 1]} ${d.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _PresetChip extends StatelessWidget {
  final String label, keyd;
  final ProductionRangeController c;
  const _PresetChip(this.label, this.keyd, this.c);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => c.applyPreset(keyd),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: ErpColors.accentBlue.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ErpColors.accentBlue.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  RANGE KPI STRIP
// ══════════════════════════════════════════════════════════════
class _RangeKpiStrip extends StatelessWidget {
  final ProductionRangeController c;
  const _RangeKpiStrip({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoading.value || c.dailyList.isEmpty)
      return const SizedBox.shrink();
    return Container(
      color: const Color(0xFF1B2B45),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _KpiCell('Total Production', '${c.rangeTotalProduction}m'),
          _kdiv(),
          _KpiCell(
            'Active Days',
            '${c.rangeActiveDays} / ${c.dailyList.length}',
          ),
          _kdiv(),
          _KpiCell(
            'Avg Efficiency',
            '${c.rangeAvgEfficiency.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  });

  Widget _kdiv() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: const Color(0xFF2D4A6E),
  );
}

class _KpiCell extends StatelessWidget {
  final String label, value;
  const _KpiCell(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 9),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  BODY — LIST / LOADING / ERROR
// ══════════════════════════════════════════════════════════════
class _Body extends StatelessWidget {
  final ProductionRangeController c;
  const _Body({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoading.value) return const _LoadingState();
    if (c.errorMsg.value != null) return _ErrorState(c: c);
    if (c.dailyList.isEmpty) return const _EmptyState();
    return RefreshIndicator(
      color: ErpColors.accentBlue,
      onRefresh: c.fetchRange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        itemCount: c.dailyList.length,
        itemBuilder: (_, i) => _DayRow(day: c.dailyList[i], c: c),
      ),
    );
  });
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: ErpColors.accentBlue),
        SizedBox(height: 12),
        Text(
          'Loading production data…',
          style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final ProductionRangeController c;
  const _ErrorState({required this.c});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: ErpColors.errorRed,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            c.errorMsg.value!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ErpColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: c.fetchRange,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 16,
            ),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bar_chart_rounded, color: ErpColors.textMuted, size: 52),
        SizedBox(height: 12),
        Text(
          'No production data for this range',
          style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  DAY ROW  —  date header + optional expanded shift cards
// ══════════════════════════════════════════════════════════════
class _DayRow extends StatelessWidget {
  final DailyProduction day;
  final ProductionRangeController c;
  const _DayRow({required this.day, required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    final expanded = c.expandedDate.value == day.date;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: expanded
              ? ErpColors.accentBlue.withOpacity(0.4)
              : ErpColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date header tile
          InkWell(
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            onTap: day.hasData ? () => c.toggleDate(day.date) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Date badge
                  Container(
                    width: 46,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: day.hasData
                          ? ErpColors.accentBlue.withOpacity(0.1)
                          : ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          day.date.split('-')[2],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: day.hasData
                                ? ErpColors.accentBlue
                                : ErpColors.textMuted,
                          ),
                        ),
                        Text(
                          day.dayOfWeek,
                          style: TextStyle(
                            fontSize: 9,
                            color: day.hasData
                                ? ErpColors.accentBlue
                                : ErpColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Production info
                  Expanded(
                    child: day.hasData
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${day.totalProduction} m',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: ErpColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _EfficiencyBadge(day.efficiency),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _MiniStat(
                                    Icons.settings_rounded,
                                    '${day.runningMachines} machines',
                                  ),
                                  const SizedBox(width: 10),
                                  _MiniStat(
                                    Icons.person_outline_rounded,
                                    '${day.totalOperators} operators',
                                  ),
                                  const SizedBox(width: 10),
                                  if (day.dayShift.exists)
                                    _ShiftDot('D', ErpColors.accentBlue),
                                  if (day.nightShift.exists)
                                    _ShiftDot('N', const Color(0xFF7C3AED)),
                                ],
                              ),
                            ],
                          )
                        : const Text(
                            'No shifts recorded',
                            style: TextStyle(
                              color: ErpColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                  ),

                  if (day.hasData)
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: ErpColors.textSecondary,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Expanded shift cards ─────────────────────────
          if (expanded) ...[
            Container(height: 1, color: ErpColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (day.dayShift.exists)
                    Expanded(
                      child: _ShiftCard(
                        shiftType: 'day',
                        summary: day.dayShift,
                      ),
                    ),
                  if (day.dayShift.exists && day.nightShift.exists)
                    const SizedBox(width: 10),
                  if (day.nightShift.exists)
                    Expanded(
                      child: _ShiftCard(
                        shiftType: 'night',
                        summary: day.nightShift,
                      ),
                    ),
                  if (!day.dayShift.exists && !day.nightShift.exists)
                    const Text('No shift data'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  });
}

// ══════════════════════════════════════════════════════════════
//  SHIFT CARD  (Day / Night)
// ══════════════════════════════════════════════════════════════
class _ShiftCard extends StatelessWidget {
  final String shiftType;
  final ShiftSummary summary;
  const _ShiftCard({required this.shiftType, required this.summary});

  bool get isDay => shiftType == 'day';

  @override
  Widget build(BuildContext context) {
    final accent = isDay ? ErpColors.accentBlue : const Color(0xFF7C3AED);
    final bgLight = isDay
        ? ErpColors.accentBlue.withOpacity(0.06)
        : const Color(0xFF7C3AED).withOpacity(0.06);

    return GestureDetector(
      onTap: () {
        if (summary.shiftPlanId != null) {
          Get.to(() => ShiftPlanDetailPage(), arguments: summary.shiftPlanId!);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDay ? 'Day Shift' : 'Night Shift',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _StatusPill(summary.status),
                ],
              ),
            ),

            // Stats grid
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CardStat(
                        Icons.factory_rounded,
                        '${summary.machines}',
                        'Machines',
                        accent,
                      ),
                      const SizedBox(width: 8),
                      _CardStat(
                        Icons.person_rounded,
                        '${summary.operators}',
                        'Operators',
                        accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CardStat(
                        Icons.straighten_rounded,
                        '${summary.production}m',
                        'Production',
                        ErpColors.successGreen,
                      ),
                      const SizedBox(width: 8),
                      _CardStat(
                        Icons.speed_rounded,
                        '${summary.efficiency.toStringAsFixed(1)}%',
                        'Efficiency',
                        summary.efficiency >= 100
                            ? ErpColors.successGreen
                            : summary.efficiency >= 85
                            ? ErpColors.warningAmber
                            : ErpColors.errorRed,
                      ),
                    ],
                  ),
                  if (summary.supervisor != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.supervisor_account_rounded,
                          size: 12,
                          color: ErpColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary.supervisor!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: ErpColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  // View detail button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: accent,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _CardStat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: ErpColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Small helpers ─────────────────────────────────────────────
class _EfficiencyBadge extends StatelessWidget {
  final double eff;
  const _EfficiencyBadge(this.eff);

  @override
  Widget build(BuildContext context) {
    final color = eff >= 100
        ? ErpColors.successGreen
        : eff >= 85
        ? ErpColors.warningAmber
        : ErpColors.errorRed;
    final bg = eff >= 100
        ? const Color(0xFFF0FDF4)
        : eff >= 85
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFFEF2F2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${eff.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniStat(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 11, color: ErpColors.textSecondary),
      const SizedBox(width: 3),
      Text(
        text,
        style: const TextStyle(fontSize: 10, color: ErpColors.textSecondary),
      ),
    ],
  );
}

class _ShiftDot extends StatelessWidget {
  final String label;
  final Color color;
  const _ShiftDot(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Center(
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);
  @override
  Widget build(BuildContext context) {
    final map = {
      'completed': (ErpColors.successGreen, const Color(0xFFF0FDF4)),
      'in_progress': (const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      'open': (ErpColors.accentBlue, const Color(0xFFEFF6FF)),
      'none': (ErpColors.textMuted, ErpColors.bgMuted),
    };
    final (fg, bg) = map[status] ?? (ErpColors.textSecondary, ErpColors.bgBase);
    final lbl =
        {
          'completed': 'Done',
          'in_progress': 'Active',
          'open': 'Open',
          'none': '—',
        }[status] ??
        status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        lbl,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}
