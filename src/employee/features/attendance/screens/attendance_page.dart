import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/attendance_controller.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmpAttendanceController(), tag: 'attendance');
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('Attendance', style: ErpTextStyles.pageTitle),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _Error(msg: c.errorMsg.value!, onRetry: c.fetchMonth);
        }
        return RefreshIndicator(
          onRefresh: c.fetchMonth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _MonthSelector(c: c),
              const SizedBox(height: 12),
              _SummaryCard(c: c),
              const SizedBox(height: 14),
              _CalendarCard(c: c),
              const SizedBox(height: 12),
              const _Legend(),
            ],
          ),
        );
      }),
    );
  }
}

// ── Month / Year selector ──────────────────────────────────────
class _MonthSelector extends StatelessWidget {
  final EmpAttendanceController c;
  const _MonthSelector({required this.c});

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM')
        .format(DateTime(c.selectedYear.value, c.selectedMonth.value));
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(children: [
        const Icon(Icons.event_outlined,
            color: ErpColors.accentBlue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$monthName ${c.selectedYear.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ErpTextStyles.cardTitle),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            int m = c.selectedMonth.value - 1;
            int y = c.selectedYear.value;
            if (m == 0) { m = 12; y -= 1; }
            c.changeMonth(y, m);
          },
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            int m = c.selectedMonth.value + 1;
            int y = c.selectedYear.value;
            if (m == 13) { m = 1; y += 1; }
            c.changeMonth(y, m);
          },
        ),
      ]),
    );
  }
}

// ── KPI summary card ───────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final EmpAttendanceController c;
  const _SummaryCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.stats.value ?? const {};
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attendance Rate', style: ErpTextStyles.kpiLabel),
          const SizedBox(height: 4),
          Text('${c.attendancePct}%', style: ErpTextStyles.kpiValue),
          const SizedBox(height: 14),
          Row(children: [
            _MiniStat('Present', '${SafeJson.asInt(s['present'])}'),
            const SizedBox(width: 8),
            _MiniStat('Late',    '${SafeJson.asInt(s['late'])}'),
            const SizedBox(width: 8),
            _MiniStat('Absent',  '${SafeJson.asInt(s['absent'])}'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _MiniStat('Half Day', '${SafeJson.asInt(s['halfDay'])}'),
            const SizedBox(width: 8),
            _MiniStat('On Leave', '${SafeJson.asInt(s['onLeave'])}'),
            const SizedBox(width: 8),
            _MiniStat('Late Min', '${SafeJson.asInt(s['totalLateMin'])}'),
          ]),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ErpColors.navyMid,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ErpTextStyles.kpiLabel),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

// ── Calendar card ──────────────────────────────────────────────
class _CalendarCard extends StatelessWidget {
  final EmpAttendanceController c;
  const _CalendarCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final focused = DateTime(c.selectedYear.value, c.selectedMonth.value, 1);
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.all(8),
      // A plain month grid, Monday first. It was the table_calendar
      // package with every gesture and the header turned off — a month
      // of day cells is all it drew, and the admin app this screen now
      // lives in does not carry that package.
      child: _MonthGrid(
        month: focused,
        cell: (day) => _DayCell(c: c, day: day, isToday: _sameDay(day, DateTime.now())),
        onTap: (day) {
          final entry = c.entryFor(day);
          if (entry != null) _showDaySheet(context, day, entry);
        },
      ),
    );
  }

  void _showDaySheet(
      BuildContext ctx, DateTime day, Map<String, dynamic> entry) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: ErpColors.borderMid,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(DateFormat('EEEE, dd MMM yyyy').format(day),
                style: ErpTextStyles.cardTitle),
            const SizedBox(height: 14),
            _ShiftRow('Day Shift',   entry['dayShift']),
            const SizedBox(height: 8),
            _ShiftRow('Night Shift', entry['nightShift']),
          ],
        ),
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final String label;
  final dynamic shift;
  const _ShiftRow(this.label, this.shift);

  @override
  Widget build(BuildContext context) {
    if (shift == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          const Text('Untracked',
              style: TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic)),
        ]),
      );
    }
    final s      = SafeJson.asMap(shift);
    final status = SafeJson.asString(s['status']).toLowerCase();
    final color  = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          if (SafeJson.asString(s['checkIn']).isNotEmpty)
            Text('In: ${SafeJson.asString(s['checkIn'], '—')}    '
                 'Out: ${SafeJson.asString(s['checkOut'], '—')}',
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 11)),
          if ((SafeJson.asNum(s['lateMinutes']) ?? 0) > 0)
            Text('Late: ${SafeJson.asNum(s['lateMinutes'])} min',
                style: const TextStyle(
                    color: ErpColors.warningAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          if (SafeJson.asString(s['notes']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Note: ${SafeJson.asString(s['notes'])}',
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

// ── Month grid ─────────────────────────────────────────────────
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _MonthGrid extends StatelessWidget {
  final DateTime month; // any day in the month shown
  final Widget Function(DateTime day) cell;
  final void Function(DateTime day) onTap;
  const _MonthGrid({required this.month, required this.cell, required this.onTap});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday = 1 → no blanks
    final rows = ((lead + days) / 7).ceil();
    const label = TextStyle(
        color: ErpColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        for (final d in _weekdays)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(child: Text(d, style: label)),
            ),
          ),
      ]),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var col = 0; col < 7; col++)
            Expanded(
              child: Builder(builder: (_) {
                final n = r * 7 + col - lead + 1;
                if (n < 1 || n > days) return const SizedBox(height: 46);
                final day = DateTime(month.year, month.month, n);
                return SizedBox(
                  height: 46,
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onTap(day),
                      child: cell(day),
                    ),
                  ),
                );
              }),
            ),
        ]),
    ]);
  }
}

// ── Day cell ───────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final EmpAttendanceController c;
  final DateTime day;
  final bool isToday;
  const _DayCell({required this.c, required this.day, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    final entry   = c.entryFor(day);
    final summary = (entry?['summary']?.toString() ?? 'untracked').toLowerCase();
    final color   = _statusColor(summary);
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(
            color: isToday ? ErpColors.accentBlue : color.withValues(alpha: 0.4),
            width: isToday ? 1.4 : 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: summary == 'untracked'
                ? ErpColors.textMuted
                : ErpColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'present':  return ErpColors.successGreen;
    case 'late':     return ErpColors.warningAmber;
    case 'half_day': return ErpColors.accentLight;
    case 'absent':   return ErpColors.errorRed;
    case 'on_leave': return ErpColors.accentBlue;
    case 'mixed':    return ErpColors.warningAmber;
    default:         return ErpColors.borderMid;
  }
}

// ── Legend ─────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    final items = const [
      ['present',  'Present'],
      ['late',     'Late'],
      ['half_day', 'Half Day'],
      ['absent',   'Absent'],
      ['on_leave', 'On Leave'],
    ];
    return Wrap(
      spacing: 8, runSpacing: 6,
      children: items.map((e) {
        final color = _statusColor(e[0]);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(e[1],
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        );
      }).toList(),
    );
  }
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
