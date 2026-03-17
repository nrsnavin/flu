// ══════════════════════════════════════════════════════════════
//  ATTENDANCE MODELS
//  File: lib/src/features/attendance/models/attendance_models.dart
// ══════════════════════════════════════════════════════════════

// ── Status helpers ────────────────────────────────────────────
enum AttendanceStatus { present, late, half_day, absent, on_leave, untracked }

extension AttendanceStatusX on AttendanceStatus {
  String get value {
    switch (this) {
      case AttendanceStatus.present:   return 'present';
      case AttendanceStatus.late:      return 'late';
      case AttendanceStatus.half_day:  return 'half_day';
      case AttendanceStatus.absent:    return 'absent';
      case AttendanceStatus.on_leave:  return 'on_leave';
      case AttendanceStatus.untracked: return 'untracked';
    }
  }

  String get label {
    switch (this) {
      case AttendanceStatus.present:   return 'Present';
      case AttendanceStatus.late:      return 'Late';
      case AttendanceStatus.half_day:  return 'Half Day';
      case AttendanceStatus.absent:    return 'Absent';
      case AttendanceStatus.on_leave:  return 'On Leave';
      case AttendanceStatus.untracked: return 'Not Marked';
    }
  }

  String get emoji {
    switch (this) {
      case AttendanceStatus.present:   return '✅';
      case AttendanceStatus.late:      return '⏰';
      case AttendanceStatus.half_day:  return '🔶';
      case AttendanceStatus.absent:    return '❌';
      case AttendanceStatus.on_leave:  return '🏖️';
      case AttendanceStatus.untracked: return '–';
    }
  }

  static AttendanceStatus fromString(String? s) {
    switch (s) {
      case 'present':   return AttendanceStatus.present;
      case 'late':      return AttendanceStatus.late;
      case 'half_day':  return AttendanceStatus.half_day;
      case 'absent':    return AttendanceStatus.absent;
      case 'on_leave':  return AttendanceStatus.on_leave;
      default:          return AttendanceStatus.untracked;
    }
  }
}

// ── Single attendance record ──────────────────────────────────
class AttendanceRecord {
  final String?           id;
  final String            employeeId;
  final String            name;
  final String            department;
  final String            skill;
  final String            role;
  final String            date;        // YYYY-MM-DD
  final String            dateLabel;
  final String            dayOfWeek;
  final String            shift;       // DAY | NIGHT
  final AttendanceStatus  status;
  final String            checkIn;
  final String            checkOut;
  final int               lateMinutes;
  final String            leaveType;
  final String            notes;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.department,
    required this.skill,
    required this.role,
    required this.date,
    required this.dateLabel,
    required this.dayOfWeek,
    required this.shift,
    required this.status,
    required this.checkIn,
    required this.checkOut,
    required this.lateMinutes,
    required this.leaveType,
    required this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    id:          j['id']?.toString(),
    employeeId:  j['employeeId']?.toString() ?? '',
    name:        j['name']?.toString()       ?? '–',
    department:  j['department']?.toString() ?? '–',
    skill:       j['skill']?.toString()      ?? '',
    role:        j['role']?.toString()       ?? '',
    date:        j['date']?.toString()       ?? '',
    dateLabel:   j['dateLabel']?.toString()  ?? '',
    dayOfWeek:   j['dayOfWeek']?.toString()  ?? '',
    shift:       j['shift']?.toString()      ?? 'DAY',
    status:      AttendanceStatusX.fromString(j['status']?.toString()),
    checkIn:     j['checkIn']?.toString()    ?? '',
    checkOut:    j['checkOut']?.toString()   ?? '',
    lateMinutes: (j['lateMinutes'] as num?)?.toInt() ?? 0,
    leaveType:   j['leaveType']?.toString()  ?? '',
    notes:       j['notes']?.toString()      ?? '',
  );

  AttendanceRecord copyWith({
    AttendanceStatus? status,
    String? checkIn,
    String? checkOut,
    int?    lateMinutes,
    String? leaveType,
    String? notes,
  }) => AttendanceRecord(
    id: id, employeeId: employeeId, name: name, department: department,
    skill: skill, role: role, date: date, dateLabel: dateLabel,
    dayOfWeek: dayOfWeek, shift: shift,
    status:      status      ?? this.status,
    checkIn:     checkIn     ?? this.checkIn,
    checkOut:    checkOut    ?? this.checkOut,
    lateMinutes: lateMinutes ?? this.lateMinutes,
    leaveType:   leaveType   ?? this.leaveType,
    notes:       notes       ?? this.notes,
  );
}

// ── Employee stub (for unmarked list) ─────────────────────────
class EmployeeStub {
  final String id;
  final String name;
  final String department;
  final String skill;
  final String role;

  const EmployeeStub({
    required this.id, required this.name, required this.department,
    required this.skill, required this.role,
  });

  factory EmployeeStub.fromJson(Map<String, dynamic> j) => EmployeeStub(
    id:         j['id']?.toString()         ?? '',
    name:       j['name']?.toString()       ?? '–',
    department: j['department']?.toString() ?? '–',
    skill:      j['skill']?.toString()      ?? '',
    role:       j['role']?.toString()       ?? '',
  );
}

// ── Status breakdown ──────────────────────────────────────────
class StatusBreakdown {
  final int present;
  final int late;
  final int halfDay;
  final int absent;
  final int onLeave;

  const StatusBreakdown({
    required this.present, required this.late, required this.halfDay,
    required this.absent,  required this.onLeave,
  });

  int get total => present + late + halfDay + absent + onLeave;

  factory StatusBreakdown.empty() => const StatusBreakdown(
      present:0, late:0, halfDay:0, absent:0, onLeave:0);

  factory StatusBreakdown.fromJson(Map<String, dynamic> j) => StatusBreakdown(
    present:  (j['present']  as num?)?.toInt() ?? 0,
    late:     (j['late']     as num?)?.toInt() ?? 0,
    halfDay:  (j['half_day'] as num?)?.toInt() ?? 0,
    absent:   (j['absent']   as num?)?.toInt() ?? 0,
    onLeave:  (j['on_leave'] as num?)?.toInt() ?? 0,
  );
}

// ── Daily attendance response (GET /date) ─────────────────────
class DailyAttendanceData {
  final String               date;
  final String               dateLabel;
  final String               shift;
  final List<AttendanceRecord> records;
  final List<EmployeeStub>   unmarked;
  final int                  totalMarked;
  final int                  totalUnmarked;
  final StatusBreakdown      breakdown;

  const DailyAttendanceData({
    required this.date, required this.dateLabel, required this.shift,
    required this.records, required this.unmarked,
    required this.totalMarked, required this.totalUnmarked,
    required this.breakdown,
  });

  factory DailyAttendanceData.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? {};
    return DailyAttendanceData(
      date:          j['date']?.toString()      ?? '',
      dateLabel:     j['dateLabel']?.toString() ?? '',
      shift:         j['shift']?.toString()     ?? 'all',
      records:       (data['records'] as List?)?.map((e) =>
          AttendanceRecord.fromJson(e as Map<String,dynamic>)).toList() ?? [],
      unmarked:      (data['unmarked'] as List?)?.map((e) =>
          EmployeeStub.fromJson(e as Map<String,dynamic>)).toList() ?? [],
      totalMarked:   (data['totalMarked']   as num?)?.toInt() ?? 0,
      totalUnmarked: (data['totalUnmarked'] as num?)?.toInt() ?? 0,
      breakdown:     StatusBreakdown.fromJson(data['breakdown'] as Map<String,dynamic>? ?? {}),
    );
  }
}

// ── Employee history response (GET /employee/:id) ─────────────
class EmployeeAttendanceSummary {
  final String name;
  final String department;
  final int    total;
  final int    present;
  final int    late;
  final int    halfDay;
  final int    absent;
  final int    onLeave;
  final int    attendancePct;
  final int    totalLateMinutes;

  const EmployeeAttendanceSummary({
    required this.name,        required this.department,
    required this.total,       required this.present,
    required this.late,        required this.halfDay,
    required this.absent,      required this.onLeave,
    required this.attendancePct, required this.totalLateMinutes,
  });

  factory EmployeeAttendanceSummary.fromJson(Map<String, dynamic> j,
      Map<String, dynamic> emp) => EmployeeAttendanceSummary(
    name:             emp['name']?.toString()       ?? '–',
    department:       emp['department']?.toString() ?? '–',
    total:            (j['total']            as num?)?.toInt() ?? 0,
    present:          (j['present']          as num?)?.toInt() ?? 0,
    late:             (j['late']             as num?)?.toInt() ?? 0,
    halfDay:          (j['halfDay']          as num?)?.toInt() ?? 0,
    absent:           (j['absent']           as num?)?.toInt() ?? 0,
    onLeave:          (j['onLeave']          as num?)?.toInt() ?? 0,
    attendancePct:    (j['attendancePct']    as num?)?.toInt() ?? 0,
    totalLateMinutes: (j['totalLateMinutes'] as num?)?.toInt() ?? 0,
  );
}

// ── Monthly calendar day ──────────────────────────────────────
class CalendarDay {
  final String            date;
  final int               day;
  final String            dayOfWeek;
  final String            summary;    // present | late | absent | … | untracked
  final Map<String,dynamic>? dayShift;
  final Map<String,dynamic>? nightShift;

  const CalendarDay({
    required this.date, required this.day, required this.dayOfWeek,
    required this.summary, required this.dayShift, required this.nightShift,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
    date:       j['date']?.toString()      ?? '',
    day:        (j['day'] as num?)?.toInt() ?? 0,
    dayOfWeek:  j['dayOfWeek']?.toString() ?? '',
    summary:    j['summary']?.toString()   ?? 'untracked',
    dayShift:   j['dayShift']  as Map<String,dynamic>?,
    nightShift: j['nightShift'] as Map<String,dynamic>?,
  );

  AttendanceStatus get summaryStatus =>
      AttendanceStatusX.fromString(summary);
}

// ── Summary response (GET /summary) ──────────────────────────
class FactorySummary {
  final int totalShifts;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int onLeaveCount;
  final int halfDayCount;
  final int attendancePct;

  const FactorySummary({
    required this.totalShifts, required this.presentCount,
    required this.lateCount,   required this.absentCount,
    required this.onLeaveCount,required this.halfDayCount,
    required this.attendancePct,
  });

  factory FactorySummary.fromJson(Map<String, dynamic> j) => FactorySummary(
    totalShifts:  (j['totalShifts']  as num?)?.toInt() ?? 0,
    presentCount: (j['presentCount'] as num?)?.toInt() ?? 0,
    lateCount:    (j['lateCount']    as num?)?.toInt() ?? 0,
    absentCount:  (j['absentCount']  as num?)?.toInt() ?? 0,
    onLeaveCount: (j['onLeaveCount'] as num?)?.toInt() ?? 0,
    halfDayCount: (j['halfDayCount'] as num?)?.toInt() ?? 0,
    attendancePct:(j['attendancePct'] as num?)?.toInt() ?? 0,
  );
}

class EmployeeSummaryRow {
  final String employeeId;
  final String name;
  final String department;
  final int    total;
  final int    present;
  final int    late;
  final int    halfDay;
  final int    absent;
  final int    onLeave;
  final int    totalLateMin;
  final int    attendancePct;

  const EmployeeSummaryRow({
    required this.employeeId, required this.name,    required this.department,
    required this.total,      required this.present, required this.late,
    required this.halfDay,    required this.absent,  required this.onLeave,
    required this.totalLateMin, required this.attendancePct,
  });

  factory EmployeeSummaryRow.fromJson(Map<String, dynamic> j) => EmployeeSummaryRow(
    employeeId:    j['employeeId']?.toString()  ?? '',
    name:          j['name']?.toString()        ?? '–',
    department:    j['department']?.toString()  ?? '–',
    total:         (j['total']         as num?)?.toInt() ?? 0,
    present:       (j['present']       as num?)?.toInt() ?? 0,
    late:          (j['late']          as num?)?.toInt() ?? 0,
    halfDay:       (j['halfDay']       as num?)?.toInt() ?? 0,
    absent:        (j['absent']        as num?)?.toInt() ?? 0,
    onLeave:       (j['onLeave']       as num?)?.toInt() ?? 0,
    totalLateMin:  (j['totalLateMin']  as num?)?.toInt() ?? 0,
    attendancePct: (j['attendancePct'] as num?)?.toInt() ?? 0,
  );
}