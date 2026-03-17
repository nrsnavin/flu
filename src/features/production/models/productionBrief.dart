// ══════════════════════════════════════════════════════════════
//  PRODUCTION DATE-RANGE MODELS
//  File: lib/src/features/production/models/production_models.dart
// ══════════════════════════════════════════════════════════════

// ── Shift summary on a single day ────────────────────────────
class ShiftSummary {
  final bool   exists;
  final String? shiftPlanId;
  final int    machines;
  final int    operators;
  final int    production;
  final int    target;
  final double efficiency;
  final String status;       // open | in_progress | completed
  final String? startTime;
  final String? endTime;
  final String? supervisor;

  const ShiftSummary({
    required this.exists,
    this.shiftPlanId,
    required this.machines,
    required this.operators,
    required this.production,
    required this.target,
    required this.efficiency,
    required this.status,
    this.startTime,
    this.endTime,
    this.supervisor,
  });

  factory ShiftSummary.empty() => const ShiftSummary(
    exists: false, machines: 0, operators: 0,
    production: 0, target: 0, efficiency: 0, status: 'none',
  );

  factory ShiftSummary.fromJson(Map<String, dynamic> j) => ShiftSummary(
    exists:      j['exists']      as bool? ?? false,
    shiftPlanId: j['shiftPlanId']?.toString(),
    machines:    (j['machines']   as num?)?.toInt()    ?? 0,
    operators:   (j['operators']  as num?)?.toInt()    ?? 0,
    production:  (j['production'] as num?)?.toInt()    ?? 0,
    target:      (j['target']     as num?)?.toInt()    ?? 0,
    efficiency:  (j['efficiency'] as num?)?.toDouble() ?? 0,
    status:      j['status']?.toString()               ?? 'none',
    startTime:   j['startTime']?.toString(),
    endTime:     j['endTime']?.toString(),
    supervisor:  j['supervisor']?.toString(),
  );
}

// ── One calendar day production summary ──────────────────────
class DailyProduction {
  final String date;          // YYYY-MM-DD
  final String dateLabel;     // "23 Jan 2026"
  final String dayOfWeek;     // "Mon"
  final int    totalProduction;
  final int    totalTarget;
  final double efficiency;
  final int    runningMachines;
  final int    totalOperators;
  final bool   hasData;
  final ShiftSummary dayShift;
  final ShiftSummary nightShift;

  const DailyProduction({
    required this.date,
    required this.dateLabel,
    required this.dayOfWeek,
    required this.totalProduction,
    required this.totalTarget,
    required this.efficiency,
    required this.runningMachines,
    required this.totalOperators,
    required this.hasData,
    required this.dayShift,
    required this.nightShift,
  });

  factory DailyProduction.fromJson(Map<String, dynamic> j) => DailyProduction(
    date:             j['date']?.toString()       ?? '',
    dateLabel:        j['dateLabel']?.toString()  ?? '',
    dayOfWeek:        j['dayOfWeek']?.toString()  ?? '',
    totalProduction:  (j['totalProduction'] as num?)?.toInt()    ?? 0,
    totalTarget:      (j['totalTarget']     as num?)?.toInt()    ?? 0,
    efficiency:       (j['efficiency']      as num?)?.toDouble() ?? 0,
    runningMachines:  (j['runningMachines'] as num?)?.toInt()    ?? 0,
    totalOperators:   (j['totalOperators']  as num?)?.toInt()    ?? 0,
    hasData:          j['hasData'] as bool? ?? false,
    dayShift:         j['dayShift'] != null
        ? ShiftSummary.fromJson(j['dayShift'] as Map<String, dynamic>)
        : ShiftSummary.empty(),
    nightShift:       j['nightShift'] != null
        ? ShiftSummary.fromJson(j['nightShift'] as Map<String, dynamic>)
        : ShiftSummary.empty(),
  );
}

// ── Downtime reason entry ─────────────────────────────────────
class DowntimeReason {
  final String reason;
  final int    minutes;
  const DowntimeReason({required this.reason, required this.minutes});

  factory DowntimeReason.fromJson(Map<String, dynamic> j) => DowntimeReason(
    reason:  j['reason']?.toString()  ?? '',
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
  );
}

// ── Per-machine detail within a shift ────────────────────────
class MachineShiftDetail {
  final int    rowIndex;
  final String machineId;
  final String machineNo;
  final String machineType;
  final String department;
  final String operatorId;
  final String operatorName;
  final String operatorDept;
  final String operatorSkill;
  final int    noOfHeads;
  final int    speed;
  final int    target;
  final int    production;
  final double efficiency;
  final String? timerStart;
  final String? timerEnd;
  final int    runMinutes;
  final int    downtimeMinutes;
  final int    activeMinutes;
  final List<DowntimeReason> downtimeReasons;
  final String remarks;
  final String status;

  const MachineShiftDetail({
    required this.rowIndex,
    required this.machineId,
    required this.machineNo,
    required this.machineType,
    required this.department,
    required this.operatorId,
    required this.operatorName,
    required this.operatorDept,
    required this.operatorSkill,
    required this.noOfHeads,
    required this.speed,
    required this.target,
    required this.production,
    required this.efficiency,
    this.timerStart,
    this.timerEnd,
    required this.runMinutes,
    required this.downtimeMinutes,
    required this.activeMinutes,
    required this.downtimeReasons,
    required this.remarks,
    required this.status,
  });

  factory MachineShiftDetail.fromJson(Map<String, dynamic> j) {
    final dtList = (j['downtimeReasons'] as List<dynamic>?)
        ?.map((e) => DowntimeReason.fromJson(e as Map<String,dynamic>))
        .toList() ?? [];
    return MachineShiftDetail(
      rowIndex:        (j['rowIndex']        as num?)?.toInt()    ?? 0,
      machineId:       j['machineId']?.toString()                 ?? '',
      machineNo:       j['machineNo']?.toString()                 ?? '-',
      machineType:     j['machineType']?.toString()               ?? '-',
      department:      j['department']?.toString()                ?? '-',
      operatorId:      j['operatorId']?.toString()                ?? '',
      operatorName:    j['operatorName']?.toString()              ?? '-',
      operatorDept:    j['operatorDept']?.toString()              ?? '-',
      operatorSkill:   j['operatorSkill']?.toString()             ?? '-',
      noOfHeads:       (j['noOfHeads']       as num?)?.toInt()    ?? 0,
      speed:           (j['speed']           as num?)?.toInt()    ?? 0,
      target:          (j['target']          as num?)?.toInt()    ?? 0,
      production:      (j['production']      as num?)?.toInt()    ?? 0,
      efficiency:      (j['efficiency']      as num?)?.toDouble() ?? 0,
      timerStart:      j['timerStart']?.toString(),
      timerEnd:        j['timerEnd']?.toString(),
      runMinutes:      (j['runMinutes']       as num?)?.toInt()   ?? 0,
      downtimeMinutes: (j['downtimeMinutes']  as num?)?.toInt()   ?? 0,
      activeMinutes:   (j['activeMinutes']    as num?)?.toInt()   ?? 0,
      downtimeReasons: dtList,
      remarks:         j['remarks']?.toString()                   ?? '',
      status:          j['status']?.toString()                    ?? 'open',
    );
  }

  // Formatted timer strings
  String get formattedRunTime {
    final h = runMinutes ~/ 60;
    final m = runMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get formattedDowntime {
    final h = downtimeMinutes ~/ 60;
    final m = downtimeMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

// ── Full shift plan detail ─────────────────────────────────────
class ShiftSummaryStats {
  final int    totalMachines;
  final int    totalOperators;
  final int    totalProduction;
  final int    totalTarget;
  final double avgEfficiency;
  final int    totalRunMinutes;
  final int    totalDowntime;
  final String highestProducer;

  const ShiftSummaryStats({
    required this.totalMachines,
    required this.totalOperators,
    required this.totalProduction,
    required this.totalTarget,
    required this.avgEfficiency,
    required this.totalRunMinutes,
    required this.totalDowntime,
    required this.highestProducer,
  });

  factory ShiftSummaryStats.fromJson(Map<String,dynamic> j) => ShiftSummaryStats(
    totalMachines:    (j['totalMachines']    as num?)?.toInt()    ?? 0,
    totalOperators:   (j['totalOperators']   as num?)?.toInt()    ?? 0,
    totalProduction:  (j['totalProduction']  as num?)?.toInt()    ?? 0,
    totalTarget:      (j['totalTarget']      as num?)?.toInt()    ?? 0,
    avgEfficiency:    (j['avgEfficiency']    as num?)?.toDouble() ?? 0,
    totalRunMinutes:  (j['totalRunMinutes']  as num?)?.toInt()    ?? 0,
    totalDowntime:    (j['totalDowntime']    as num?)?.toInt()    ?? 0,
    highestProducer:  j['highestProducer']?.toString()            ?? '-',
  );

  String get formattedRunTime {
    final h = totalRunMinutes ~/ 60;
    final m = totalRunMinutes % 60;
    return '${h}h ${m}m';
  }
}

class ShiftPlanDetail {
  final String   shiftPlanId;
  final String   date;
  final String   dateLabel;
  final String   shiftType;   // day | night
  final String   status;
  final String?  startTime;
  final String?  endTime;
  final String?  supervisorId;
  final String?  supervisorName;
  final String?  jobNo;
  final String   department;
  final String   remarks;
  final ShiftSummaryStats  summary;
  final List<MachineShiftDetail> machines;

  const ShiftPlanDetail({
    required this.shiftPlanId,
    required this.date,
    required this.dateLabel,
    required this.shiftType,
    required this.status,
    this.startTime,
    this.endTime,
    this.supervisorId,
    this.supervisorName,
    this.jobNo,
    required this.department,
    required this.remarks,
    required this.summary,
    required this.machines,
  });

  factory ShiftPlanDetail.fromJson(Map<String,dynamic> j) {
    final sup  = j['supervisor'] as Map<String,dynamic>?;
    final job  = j['job']        as Map<String,dynamic>?;
    return ShiftPlanDetail(
      shiftPlanId:    j['shiftPlanId']?.toString() ?? '',
      date:           j['date']?.toString()        ?? '',
      dateLabel:      j['dateLabel']?.toString()   ?? '',
      shiftType:      j['shiftType']?.toString()   ?? 'day',
      status:         j['status']?.toString()      ?? 'open',
      startTime:      j['startTime']?.toString(),
      endTime:        j['endTime']?.toString(),
      supervisorId:   sup?['id']?.toString(),
      supervisorName: sup?['name']?.toString(),
      jobNo:          job?['jobNo']?.toString(),
      department:     j['department']?.toString()  ?? '-',
      remarks:        j['remarks']?.toString()     ?? '',
      summary: ShiftSummaryStats.fromJson(
          j['summary'] as Map<String,dynamic>? ?? {}),
      machines: (j['machines'] as List<dynamic>?)
          ?.map((e) => MachineShiftDetail.fromJson(e as Map<String,dynamic>))
          .toList() ?? [],
    );
  }
}