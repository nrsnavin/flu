// ══════════════════════════════════════════════════════════════
//  ATTENDANCE PAGE  — main hub
//  File: lib/src/features/attendance/screens/attendance_page.dart
//
//  Three views inside the same page (no separate routes):
//    1. Mark Shift  — bulk mark + quick-toggle per employee
//    2. Summary     — factory-wide stats + per-employee table
//    3. Calendar    — monthly calendar for a selected employee
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/attendence_controller.dart';
import '../models/attendence_model.dart';


// ── Colours ────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF080F1A);
  static const surface  = Color(0xFF0E1829);
  static const surface2 = Color(0xFF162035);
  static const surface3 = Color(0xFF1C2A42);
  static const border   = Color(0xFF1C3050);

  static const blue     = Color(0xFF2563EB);
  static const blueLt   = Color(0xFF3B82F6);
  static const green    = Color(0xFF10B981);
  static const greenLt  = Color(0xFF34D399);
  static const amber    = Color(0xFFF59E0B);
  static const red      = Color(0xFFEF4444);
  static const redLt    = Color(0xFFFCA5A5);
  static const purple   = Color(0xFF8B5CF6);
  static const orange   = Color(0xFFF97316);
  static const cyan     = Color(0xFF06B6D4);
  static const teal     = Color(0xFF14B8A6);

  static const textPrim  = Color(0xFFF1F5F9);
  static const textSec   = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

  // Status colours
  static Color statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:   return green;
      case AttendanceStatus.late:      return amber;
      case AttendanceStatus.half_day:  return orange;
      case AttendanceStatus.absent:    return red;
      case AttendanceStatus.on_leave:  return purple;
      case AttendanceStatus.untracked: return textMuted;
    }
  }
}

const _months = ['Jan','Feb','Mar','Apr','May','Jun',
  'Jul','Aug','Sep','Oct','Nov','Dec'];

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')} ${_months[d.month-1]} ${d.year}';

// ══════════════════════════════════════════════════════════════
//  ENTRY POINT
// ══════════════════════════════════════════════════════════════
class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.delete<AttendanceController>(force: true);
    final c = Get.put(AttendanceController());

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _TopBar(c: c),
        _ViewSwitcher(c: c),
        Expanded(child: Obx(() {
          switch (c.activeView.value) {
            case AttendanceView.markShift: return _MarkShiftView(c: c);
            case AttendanceView.summary:   return _SummaryView(c: c);
            case AttendanceView.calendar:  return _CalendarView(c: c);
          }
        })),
      ]),
    );
  }
}

// ── Top app bar ────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final AttendanceController c;
  const _TopBar({required this.c});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 10),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: Get.back,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _C.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.border)),
            child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _C.textSec),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Attendance', style: TextStyle(
              color: _C.textPrim, fontSize: 16, fontWeight: FontWeight.w800)),
          const Text('Mark · Summary · Calendar',
              style: TextStyle(color: _C.textMuted, fontSize: 10)),
        ])),
        GestureDetector(
          onTap: () {
            if (c.activeView.value == AttendanceView.markShift) c.fetchDailyAttendance();
            if (c.activeView.value == AttendanceView.summary)   c.fetchSummary();
            if (c.activeView.value == AttendanceView.calendar)  c.fetchCalendar();
          },
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _C.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.border)),
            child: const Icon(Icons.refresh_rounded, size: 16, color: _C.textSec),
          ),
        ),
      ]),
    );
  }
}

// ── View switcher tabs ─────────────────────────────────────────
class _ViewSwitcher extends StatelessWidget {
  final AttendanceController c;
  const _ViewSwitcher({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Obx(() => Row(children: [
        _tab(c, '📋 Mark Shift', AttendanceView.markShift),
        const SizedBox(width: 8),
        _tab(c, '📊 Summary',    AttendanceView.summary),
        const SizedBox(width: 8),
        _tab(c, '📅 Calendar',   AttendanceView.calendar),
      ])),
    );
  }

  Widget _tab(AttendanceController c, String label, AttendanceView view) {
    final active = c.activeView.value == view;
    return GestureDetector(
      onTap: () => c.activeView.value = view,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: active ? _C.blue.withOpacity(0.2) : _C.surface3,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: active ? _C.blue.withOpacity(0.6) : _C.border)),
        child: Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? _C.blueLt : _C.textSec)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 1 — MARK SHIFT
// ══════════════════════════════════════════════════════════════
class _MarkShiftView extends StatelessWidget {
  final AttendanceController c;
  const _MarkShiftView({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _MarkShiftHeader(c: c),
      Expanded(child: Obx(() {
        if (c.isLoadingDaily.value) return const _LoadingView();
        if (c.dailyError.value != null)
          return _ErrorMsg(msg: c.dailyError.value!);
        if (c.draftMap.isEmpty) return const _EmptyMsg('No employees found');
        return _EmployeeMarkList(c: c);
      })),
    ]);
  }
}

class _MarkShiftHeader extends StatelessWidget {
  final AttendanceController c;
  const _MarkShiftHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(children: [
        // Date + shift picker row
        Obx(() => Row(children: [
          // Date picker
          Expanded(child: GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: c.selectedDate.value,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.dark(
                            primary: _C.blue, surface: _C.surface2,
                            onSurface: _C.textPrim)),
                    child: child!),
              );
              if (d != null) {
                c.selectedDate.value = d;
                c.fetchDailyAttendance();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _C.surface3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border)),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded, size: 13, color: _C.textSec),
                const SizedBox(width: 6),
                Text(_fmtDate(c.selectedDate.value),
                    style: const TextStyle(color: _C.textPrim,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          // Shift toggle
          _ShiftToggle(c: c),
        ])),
        const SizedBox(height: 10),
        // Live summary chips
        Obx(() {
          final total = c.totalEmployeesInDraft;
          if (total == 0) return const SizedBox.shrink();
          return Row(children: [
            _QuickChip('${c.presentCount}  P', _C.green),
            const SizedBox(width: 5),
            _QuickChip('${c.absentCount}  A', _C.red),
            const SizedBox(width: 5),
            _QuickChip('${c.lateCount}  L', _C.amber),
            const SizedBox(width: 5),
            _QuickChip('${c.halfDayCount}  H', _C.orange),
            if (c.onLeaveCount > 0) ...[
              const SizedBox(width: 5),
              _QuickChip('${c.onLeaveCount}  LV', _C.purple),
            ],
            const Spacer(),
            // Mark all present shortcut
            GestureDetector(
              onTap: c.markAllPresent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _C.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _C.green.withOpacity(0.4))),
                child: const Text('All Present',
                    style: TextStyle(color: _C.green, fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 10),
        // Save button
        Obx(() => GestureDetector(
          onTap: c.isSaving.value ? null : c.saveAttendance,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.isSaving.value
                  ? [_C.surface3, _C.surface3]
                  : [const Color(0xFF1D4ED8), _C.blue]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: c.isSaving.value
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: _C.textSec, strokeWidth: 2))
                : const Text('Save Attendance',
                style: TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w800))),
          ),
        )),
        // Save feedback
        Obx(() {
          if (c.saveSuccess.value)
            return const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('✅ Attendance saved successfully',
                    style: TextStyle(color: _C.green, fontSize: 11)));
          if (c.saveError.value != null)
            return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('⚠️ ${c.saveError.value}',
                    style: const TextStyle(color: _C.red, fontSize: 11)));
          return const SizedBox.shrink();
        }),
      ]),
    );
  }
}

class _ShiftToggle extends StatelessWidget {
  final AttendanceController c;
  const _ShiftToggle({required this.c});
  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(children: [
      _shiftBtn(c, 'DAY',   Icons.wb_sunny_rounded),
      const SizedBox(width: 4),
      _shiftBtn(c, 'NIGHT', Icons.nights_stay_rounded),
    ]));
  }
  Widget _shiftBtn(AttendanceController c, String shift, IconData icon) {
    final active = c.selectedShift.value == shift;
    return GestureDetector(
      onTap: () {
        c.selectedShift.value = shift;
        c.fetchDailyAttendance();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: active ? _C.blue.withOpacity(0.2) : _C.surface3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? _C.blue.withOpacity(0.5) : _C.border)),
        child: Row(children: [
          Icon(icon, size: 12, color: active ? _C.blueLt : _C.textMuted),
          const SizedBox(width: 4),
          Text(shift, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: active ? _C.blueLt : _C.textSec)),
        ]),
      ),
    );
  }
}

// ── Employee mark list ────────────────────────────────────────
class _EmployeeMarkList extends StatelessWidget {
  final AttendanceController c;
  const _EmployeeMarkList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entries = c.draftMap.entries.toList()
        ..sort((a, b) => a.value.name.compareTo(b.value.name));
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
        itemCount: entries.length,
        itemBuilder: (_, i) => _EmployeeMarkRow(
          empId: entries[i].key,
          record: entries[i].value,
          c: c,
        ),
      );
    });
  }
}

class _EmployeeMarkRow extends StatelessWidget {
  final String empId;
  final AttendanceRecord record;
  final AttendanceController c;
  const _EmployeeMarkRow({required this.empId, required this.record, required this.c});

  @override
  Widget build(BuildContext context) {
    final status = record.status;
    final color  = _C.statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _C.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        // Main row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            // Avatar
            Container(width: 36, height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.12),
                    border: Border.all(color: color.withOpacity(0.5))),
                child: Center(child: Text(
                    record.name.isNotEmpty ? record.name[0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.name, style: const TextStyle(
                  color: _C.textPrim, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('${record.department}${record.skill.isNotEmpty ? " · ${record.skill}" : ""}',
                  style: const TextStyle(color: _C.textSec, fontSize: 10)),
            ])),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: color.withOpacity(0.4))),
              child: Text('${status.emoji} ${status.label}',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        // Status toggle buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(children: [
            _StatusBtn(empId, AttendanceStatus.present,  c),
            const SizedBox(width: 4),
            _StatusBtn(empId, AttendanceStatus.late,     c),
            const SizedBox(width: 4),
            _StatusBtn(empId, AttendanceStatus.half_day, c),
            const SizedBox(width: 4),
            _StatusBtn(empId, AttendanceStatus.absent,   c),
            const SizedBox(width: 4),
            _StatusBtn(empId, AttendanceStatus.on_leave, c),
          ]),
        ),
        // Expanded details for late / leave
        if (status == AttendanceStatus.late)
          _LateDetails(empId: empId, record: record, c: c),
        if (status == AttendanceStatus.on_leave)
          _LeaveDetails(empId: empId, record: record, c: c),
      ]),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String empId;
  final AttendanceStatus status;
  final AttendanceController c;
  const _StatusBtn(this.empId, this.status, this.c);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = c.draftMap[empId]?.status == status;
      final color  = _C.statusColor(status);
      return GestureDetector(
        onTap: () => c.setStatus(empId, status),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
              color: active ? color.withOpacity(0.2) : _C.surface3,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: active ? color.withOpacity(0.6) : _C.border)),
          child: Text(status.emoji,
              style: const TextStyle(fontSize: 13)),
        ),
      );
    });
  }
}

class _LateDetails extends StatelessWidget {
  final String empId;
  final AttendanceRecord record;
  final AttendanceController c;
  const _LateDetails({required this.empId, required this.record, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: _C.amber.withOpacity(0.07),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _C.amber.withOpacity(0.25))),
      child: Row(children: [
        const Icon(Icons.timer_rounded, size: 13, color: _C.amber),
        const SizedBox(width: 6),
        const Text('Late by:', style: TextStyle(color: _C.amber, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Wrap(spacing: 5, children: [15, 30, 45, 60, 90].map((m) {
          final active = record.lateMinutes == m;
          return GestureDetector(
            onTap: () => c.setLateMinutes(empId, m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: active ? _C.amber.withOpacity(0.2) : _C.surface3,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: active ? _C.amber.withOpacity(0.5) : _C.border)),
              child: Text('${m}m', style: TextStyle(
                  color: active ? _C.amber : _C.textSec,
                  fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          );
        }).toList())),
      ]),
    );
  }
}

class _LeaveDetails extends StatelessWidget {
  final String empId;
  final AttendanceRecord record;
  final AttendanceController c;
  const _LeaveDetails({required this.empId, required this.record, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: _C.purple.withOpacity(0.07),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _C.purple.withOpacity(0.25))),
      child: Row(children: [
        const Icon(Icons.beach_access_rounded, size: 13, color: _C.purple),
        const SizedBox(width: 6),
        const Text('Type:', style: TextStyle(color: _C.purple, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        ...['casual', 'sick', 'unpaid'].map((type) {
          final active = record.leaveType == type;
          return GestureDetector(
            onTap: () => c.setLeaveType(empId, type),
            child: Container(
              margin: const EdgeInsets.only(right: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: active ? _C.purple.withOpacity(0.2) : _C.surface3,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: active ? _C.purple.withOpacity(0.5) : _C.border)),
              child: Text(type[0].toUpperCase() + type.substring(1),
                  style: TextStyle(color: active ? _C.purple : _C.textSec,
                      fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          );
        }),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 2 — SUMMARY
// ══════════════════════════════════════════════════════════════
class _SummaryView extends StatelessWidget {
  final AttendanceController c;
  const _SummaryView({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SummaryHeader(c: c),
      Expanded(child: Obx(() {
        if (c.isLoadingSummary.value) return const _LoadingView();
        if (c.summaryError.value != null)
          return _ErrorMsg(msg: c.summaryError.value!);
        final factory = c.factorySummary.value;
        if (factory == null || c.summaryList.isEmpty)
          return const _EmptyMsg('No attendance records for this period');
        return _SummaryContent(c: c, factory: factory);
      })),
    ]);
  }
}

class _SummaryHeader extends StatelessWidget {
  final AttendanceController c;
  const _SummaryHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Obx(() => Row(children: [
        Expanded(child: _datePill(context, 'From', c.summaryStart.value, (d) {
          c.summaryStart.value = d;
          c.fetchSummary();
        })),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 12, color: _C.textMuted)),
        Expanded(child: _datePill(context, 'To', c.summaryEnd.value, (d) {
          c.summaryEnd.value = d;
          c.fetchSummary();
        })),
      ])),
    );
  }

  Widget _datePill(BuildContext ctx, String label, DateTime dt, void Function(DateTime) cb) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: ctx, initialDate: dt,
          firstDate: DateTime(2023), lastDate: DateTime.now(),
          builder: (c2, child) => Theme(data: Theme.of(c2).copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: _C.blue, surface: _C.surface2, onSurface: _C.textPrim)),
              child: child!),
        );
        if (d != null) cb(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: _C.surface3,
            borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.border)),
        child: Row(children: [
          Text('$label: ', style: const TextStyle(color: _C.textMuted, fontSize: 10)),
          Text(_fmtDate(dt), style: const TextStyle(
              color: _C.textPrim, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final AttendanceController c;
  final FactorySummary factory;
  const _SummaryContent({required this.c, required this.factory});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      // Factory-wide KPI cards
      _SectionLabel('🏭 Factory Overview'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _KpiBox('${factory.attendancePct}%', 'Attendance', _C.green)),
        const SizedBox(width: 8),
        Expanded(child: _KpiBox('${factory.totalShifts}', 'Total Shifts', _C.blue)),
        const SizedBox(width: 8),
        Expanded(child: _KpiBox('${factory.absentCount}', 'Absent', _C.red)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _KpiBox('${factory.presentCount}', 'Present', _C.green)),
        const SizedBox(width: 8),
        Expanded(child: _KpiBox('${factory.lateCount}', 'Late', _C.amber)),
        const SizedBox(width: 8),
        Expanded(child: _KpiBox('${factory.onLeaveCount}', 'On Leave', _C.purple)),
      ]),
      const SizedBox(height: 14),

      // Attendance rate bar
      _SectionLabel('📊 Attendance Rate'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _C.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${factory.attendancePct}% present', style: const TextStyle(
                color: _C.textPrim, fontSize: 15, fontWeight: FontWeight.w800)),
            Text('${factory.totalShifts} shift-slots',
                style: const TextStyle(color: _C.textSec, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(height: 10, child: Row(children: [
              if (factory.presentCount > 0)
                Expanded(flex: factory.presentCount, child: Container(color: _C.green)),
              if (factory.lateCount > 0)
                Expanded(flex: factory.lateCount, child: Container(color: _C.amber)),
              if (factory.halfDayCount > 0)
                Expanded(flex: factory.halfDayCount, child: Container(color: _C.orange)),
              if (factory.absentCount > 0)
                Expanded(flex: factory.absentCount, child: Container(color: _C.red)),
              if (factory.onLeaveCount > 0)
                Expanded(flex: factory.onLeaveCount, child: Container(color: _C.purple)),
            ])),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 4, children: [
            _LegendDot(_C.green,  'Present'),
            _LegendDot(_C.amber,  'Late'),
            _LegendDot(_C.orange, 'Half Day'),
            _LegendDot(_C.red,    'Absent'),
            _LegendDot(_C.purple, 'Leave'),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      // Per-employee list (sorted by attendance % ascending — lowest first)
      _SectionLabel('👷 Employees — Lowest Attendance First'),
      const SizedBox(height: 8),
      ...c.summaryList.map((e) => _EmployeeSummaryTile(row: e, c: c)),
      const SizedBox(height: 20),
    ]);
  }
}

class _EmployeeSummaryTile extends StatelessWidget {
  final EmployeeSummaryRow row;
  final AttendanceController c;
  const _EmployeeSummaryTile({required this.row, required this.c});

  @override
  Widget build(BuildContext context) {
    final pct   = row.attendancePct;
    final color = pct >= 90 ? _C.green : pct >= 75 ? _C.amber : _C.red;

    return GestureDetector(
      onTap: () => c.openCalendar(row.employeeId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _C.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pct < 75 ? _C.red.withOpacity(0.3) : _C.border)),
        child: Row(children: [
          // Avatar
          Container(width: 36, height: 36, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.4))),
              child: Center(child: Text(
                  row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.name, style: const TextStyle(
                color: _C.textPrim, fontSize: 13, fontWeight: FontWeight.w700)),
            Text('${row.department}  ·  ${row.total} shifts',
                style: const TextStyle(color: _C.textSec, fontSize: 10)),
            const SizedBox(height: 4),
            Stack(children: [
              Container(height: 4, decoration: BoxDecoration(
                  color: _C.surface3, borderRadius: BorderRadius.circular(2))),
              FractionallySizedBox(
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(height: 4, decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)))),
            ]),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$pct%', style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            Row(children: [
              _MiniDot(_C.green, row.present),
              _MiniDot(_C.amber, row.late),
              _MiniDot(_C.red,   row.absent),
            ]),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 14, color: _C.textMuted),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW 3 — MONTHLY CALENDAR
// ══════════════════════════════════════════════════════════════
class _CalendarView extends StatelessWidget {
  final AttendanceController c;
  const _CalendarView({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.calendarEmpId.value == null) {
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.touch_app_rounded, color: _C.textMuted, size: 48),
          const SizedBox(height: 12),
          const Text('Tap an employee in Summary\nto view their calendar',
              style: TextStyle(color: _C.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => c.activeView.value = AttendanceView.summary,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: _C.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.blue.withOpacity(0.4))),
              child: const Text('Go to Summary',
                  style: TextStyle(color: _C.blueLt, fontWeight: FontWeight.w700)),
            ),
          ),
        ]));
      }

      return Column(children: [
        _CalendarHeader(c: c),
        if (c.isLoadingCalendar.value) const Expanded(child: _LoadingView()),
        if (c.calendarError.value != null && !c.isLoadingCalendar.value)
          Expanded(child: _ErrorMsg(msg: c.calendarError.value!)),
        if (!c.isLoadingCalendar.value && c.calendarError.value == null)
          Expanded(child: _CalendarContent(c: c)),
      ]);
    });
  }
}

class _CalendarHeader extends StatelessWidget {
  final AttendanceController c;
  const _CalendarHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final emp   = c.calendarEmployee.value;
      final name  = emp?['name']?.toString() ?? '–';
      final dept  = emp?['department']?.toString() ?? '';
      return Container(
        color: _C.surface,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(children: [
          // Employee name
          Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(
                shape: BoxShape.circle, color: _C.blue.withOpacity(0.15),
                border: Border.all(color: _C.blue.withOpacity(0.4))),
                child: Center(child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: _C.blueLt, fontSize: 13, fontWeight: FontWeight.w900)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  color: _C.textPrim, fontSize: 14, fontWeight: FontWeight.w800)),
              Text(dept, style: const TextStyle(color: _C.textSec, fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 10),
          // Month navigator
          Row(children: [
            GestureDetector(
                onTap: c.prevMonth,
                child: Container(width: 32, height: 32, decoration: BoxDecoration(
                    color: _C.surface3, borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _C.border)),
                    child: const Icon(Icons.chevron_left_rounded, color: _C.textSec, size: 18))),
            const SizedBox(width: 10),
            Expanded(child: Center(child: Text(
                '${_months[c.calendarMonth.value - 1]} ${c.calendarYear.value}',
                style: const TextStyle(color: _C.textPrim, fontSize: 14, fontWeight: FontWeight.w800)))),
            const SizedBox(width: 10),
            GestureDetector(
                onTap: c.nextMonth,
                child: Container(width: 32, height: 32, decoration: BoxDecoration(
                    color: _C.surface3, borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _C.border)),
                    child: const Icon(Icons.chevron_right_rounded, color: _C.textSec, size: 18))),
          ]),
        ]),
      );
    });
  }
}

class _CalendarContent extends StatelessWidget {
  final AttendanceController c;
  const _CalendarContent({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final days = c.calendarDays;
      if (days.isEmpty) return const _EmptyMsg('No data for this month');

      final firstDow = days.first.dayOfWeek;
      final startOffset = _dowOffset(firstDow);

      return ListView(padding: const EdgeInsets.all(14), children: [
        // Weekday header
        Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
            .map((d) => Expanded(child: Center(child: Text(d,
            style: const TextStyle(color: _C.textMuted, fontSize: 10,
                fontWeight: FontWeight.w600)))))
            .toList()),
        const SizedBox(height: 6),
        // Calendar grid
        _buildGrid(days, startOffset),
        const SizedBox(height: 14),
        // Legend
        Wrap(spacing: 10, runSpacing: 5, children: [
          _LegendDot(_C.green,   'Present'),
          _LegendDot(_C.amber,   'Late'),
          _LegendDot(_C.orange,  'Half Day'),
          _LegendDot(_C.red,     'Absent'),
          _LegendDot(_C.purple,  'Leave'),
          _LegendDot(_C.surface3,'Untracked'),
        ]),
        const SizedBox(height: 14),
        // Stats for the month
        _MonthStats(c: c),
        const SizedBox(height: 20),
      ]);
    });
  }

  int _dowOffset(String dow) {
    const order = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    return order.indexOf(dow).clamp(0, 6);
  }

  Widget _buildGrid(List<CalendarDay> days, int startOffset) {
    final cells = <Widget>[];
    // Empty cells before start
    for (int i = 0; i < startOffset; i++) {
      cells.add(const _DayCell(null));
    }
    for (final day in days) {
      cells.add(_DayCell(day));
    }
    // Pad to fill last row
    while (cells.length % 7 != 0) {
      cells.add(const _DayCell(null));
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(Row(children: cells.sublist(i, i + 7)
          .map((c) => Expanded(child: c)).toList()));
      rows.add(const SizedBox(height: 4));
    }
    return Column(children: rows);
  }
}

class _DayCell extends StatelessWidget {
  final CalendarDay? day;
  const _DayCell(this.day);

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(height: 44);
    final status = day!.summaryStatus;
    final color  = _C.statusColor(status);
    final isUntracked = status == AttendanceStatus.untracked;

    return Container(
      height: 44,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: isUntracked ? _C.surface2 : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isUntracked ? _C.border : color.withOpacity(0.5))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${day!.day}', style: TextStyle(
            color: isUntracked ? _C.textMuted : _C.textPrim,
            fontSize: 12, fontWeight: FontWeight.w800)),
        if (!isUntracked)
          Text(status.emoji, style: const TextStyle(fontSize: 9)),
      ]),
    );
  }
}

class _MonthStats extends StatelessWidget {
  final AttendanceController c;
  const _MonthStats({required this.c});

  @override
  Widget build(BuildContext context) {
    final days = c.calendarDays;
    final allSlots = [
      ...days.where((d) => d.dayShift != null).map((d) => d.dayShift!),
      ...days.where((d) => d.nightShift != null).map((d) => d.nightShift!),
    ];
    if (allSlots.isEmpty) return const SizedBox.shrink();

    int count(String s) => allSlots.where((d) => d['status'] == s).length;
    final total    = allSlots.length;
    final present  = count('present');
    final late     = count('late');
    final absent   = count('absent');
    final halfDay  = count('half_day');
    final onLeave  = count('on_leave');
    final pct      = total > 0
        ? ((present + late + halfDay * 0.5) / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _C.surface2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Month Summary', style: const TextStyle(
            color: _C.textPrim, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatBox('$pct%',    'Attendance', _C.green)),
          const SizedBox(width: 6),
          Expanded(child: _StatBox('$present', 'Present',    _C.green)),
          const SizedBox(width: 6),
          Expanded(child: _StatBox('$late',    'Late',       _C.amber)),
          const SizedBox(width: 6),
          Expanded(child: _StatBox('$absent',  'Absent',     _C.red)),
        ]),
        if (halfDay > 0 || onLeave > 0) ...[
          const SizedBox(height: 6),
          Row(children: [
            if (halfDay > 0)
              Expanded(child: _StatBox('$halfDay', 'Half Day', _C.orange)),
            if (halfDay > 0 && onLeave > 0) const SizedBox(width: 6),
            if (onLeave > 0)
              Expanded(child: _StatBox('$onLeave', 'Leave', _C.purple)),
            if ((halfDay > 0) != (onLeave > 0))
              const Spacer(),
          ]),
        ],
      ]),
    );
  }
}

// ── Shared atomic widgets ──────────────────────────────────────
class _QuickChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _QuickChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35))),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w800)),
  );
}

class _KpiBox extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _KpiBox(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: _C.textSec, fontSize: 10)),
    ]),
  );
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _StatBox(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
        color: _C.surface3,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: _C.textSec, fontSize: 9)),
    ]),
  );
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(
        color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: _C.textSec, fontSize: 10)),
  ]);
}

class _MiniDot extends StatelessWidget {
  final Color color;
  final int   count;
  const _MiniDot(this.color, this.count);
  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(3)),
      child: Text('$count',
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 0.3));
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: _C.blue, strokeWidth: 2));
}

class _ErrorMsg extends StatelessWidget {
  final String msg;
  const _ErrorMsg({required this.msg});
  @override
  Widget build(BuildContext context) => Center(
      child: Text(msg, style: const TextStyle(color: _C.red, fontSize: 13),
          textAlign: TextAlign.center));
}

class _EmptyMsg extends StatelessWidget {
  final String msg;
  const _EmptyMsg(this.msg);
  @override
  Widget build(BuildContext context) => Center(
      child: Text(msg, style: const TextStyle(color: _C.textMuted, fontSize: 13)));
}