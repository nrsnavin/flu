// ══════════════════════════════════════════════════════════════
//  ANALYTICS MODELS  v2
//  File: lib/src/features/production/models/analytics_models.dart
// ══════════════════════════════════════════════════════════════

class WeeklyPatternPoint {
  final int    dayIndex;
  final String dayName;
  final int    avgProduction;
  final int    shiftCount;
  const WeeklyPatternPoint({ required this.dayIndex, required this.dayName,
    required this.avgProduction, required this.shiftCount });
  factory WeeklyPatternPoint.fromJson(Map<String,dynamic> j) => WeeklyPatternPoint(
    dayIndex:      (j['dayIndex']      as num?)?.toInt() ?? 0,
    dayName:       j['dayName']?.toString()  ?? '',
    avgProduction: (j['avgProduction'] as num?)?.toInt() ?? 0,
    shiftCount:    (j['shiftCount']    as num?)?.toInt() ?? 0,
  );
}

class TrendPoint {
  final String date;
  final String dateLabel;
  final String dayOfWeek;
  final int    production;
  final int    machines;
  final int    operators;
  const TrendPoint({ required this.date, required this.dateLabel,
    required this.dayOfWeek, required this.production,
    required this.machines, required this.operators });
  factory TrendPoint.fromJson(Map<String,dynamic> j) => TrendPoint(
    date:       j['date']?.toString()      ?? '',
    dateLabel:  j['dateLabel']?.toString() ?? '',
    dayOfWeek:  j['dayOfWeek']?.toString() ?? '',
    production: (j['production'] as num?)?.toInt() ?? 0,
    machines:   (j['machines']   as num?)?.toInt() ?? 0,
    operators:  (j['operators']  as num?)?.toInt() ?? 0,
  );
}

class DayVsNight {
  final int day;
  final int night;
  const DayVsNight({ required this.day, required this.night });
  factory DayVsNight.fromJson(Map<String,dynamic> j) => DayVsNight(
    day:   (j['day']   as num?)?.toInt() ?? 0,
    night: (j['night'] as num?)?.toInt() ?? 0,
  );
  double get dayPct => total == 0 ? 0.5 : day / total;
  int    get total  => day + night;
}

class AnalyticsSummary {
  final int        totalProduction;
  final int        activeShifts;
  final int        activeMachines;
  final int        activeEmployees;
  final int        avgPerShift;
  final int        overallAvg;
  final int        anomalyCount;
  final int        totalRunMinutes;
  final int        avgEfficiencyScore;
  final int        factoryConsistency;
  final DayVsNight dayVsNight;

  const AnalyticsSummary({
    required this.totalProduction, required this.activeShifts,
    required this.activeMachines,  required this.activeEmployees,
    required this.avgPerShift,     required this.overallAvg,
    required this.anomalyCount,    required this.totalRunMinutes,
    required this.avgEfficiencyScore, required this.factoryConsistency,
    required this.dayVsNight,
  });

  factory AnalyticsSummary.empty() => AnalyticsSummary(
    totalProduction:0, activeShifts:0, activeMachines:0, activeEmployees:0,
    avgPerShift:0, overallAvg:0, anomalyCount:0, totalRunMinutes:0,
    avgEfficiencyScore:0, factoryConsistency:0,
    dayVsNight: const DayVsNight(day:0, night:0),
  );

  factory AnalyticsSummary.fromJson(Map<String,dynamic> j) => AnalyticsSummary(
    totalProduction:    (j['totalProduction']    as num?)?.toInt() ?? 0,
    activeShifts:       (j['activeShifts']       as num?)?.toInt() ?? 0,
    activeMachines:     (j['activeMachines']     as num?)?.toInt() ?? 0,
    activeEmployees:    (j['activeEmployees']    as num?)?.toInt() ?? 0,
    avgPerShift:        (j['avgPerShift']        as num?)?.toInt() ?? 0,
    overallAvg:         (j['overallAvg']         as num?)?.toInt() ?? 0,
    anomalyCount:       (j['anomalyCount']       as num?)?.toInt() ?? 0,
    totalRunMinutes:    (j['totalRunMinutes']    as num?)?.toInt() ?? 0,
    avgEfficiencyScore: (j['avgEfficiencyScore'] as num?)?.toInt() ?? 0,
    factoryConsistency: (j['factoryConsistency'] as num?)?.toInt() ?? 0,
    dayVsNight: DayVsNight.fromJson(j['dayVsNight'] as Map<String,dynamic>? ?? {}),
  );
}

class MachineAnalytics {
  final String machineId;
  final String machineNo;
  final String manufacturer;
  final int    noOfHeads;
  final int    shiftCount;
  final int    totalProduction;
  final int    avgPerShift;
  final int    efficiencyPerHead;
  final int    consistencyScore;
  final int    improvement;
  final int    streak;
  final int    bestShift;
  final int    worstShift;
  final String trendDirection;
  final int    totalRunMinutes;
  final int    utilizationPct;
  final int    anomalyCount;
  final bool   isActive;
  final List<TrendPoint> trend;

  const MachineAnalytics({
    required this.machineId,    required this.machineNo,
    required this.manufacturer, required this.noOfHeads,
    required this.shiftCount,   required this.totalProduction,
    required this.avgPerShift,  required this.efficiencyPerHead,
    required this.consistencyScore, required this.improvement,
    required this.streak,       required this.bestShift,
    required this.worstShift,   required this.trendDirection,
    required this.totalRunMinutes, required this.utilizationPct,
    required this.anomalyCount, required this.isActive,
    required this.trend,
  });

  factory MachineAnalytics.fromJson(Map<String,dynamic> j) => MachineAnalytics(
    machineId:         j['machineId']?.toString()        ?? '',
    machineNo:         j['machineNo']?.toString()        ?? '-',
    manufacturer:      j['manufacturer']?.toString()     ?? '-',
    noOfHeads:         (j['noOfHeads']         as num?)?.toInt() ?? 0,
    shiftCount:        (j['shiftCount']        as num?)?.toInt() ?? 0,
    totalProduction:   (j['totalProduction']   as num?)?.toInt() ?? 0,
    avgPerShift:       (j['avgPerShift']       as num?)?.toInt() ?? 0,
    efficiencyPerHead: (j['efficiencyPerHead'] as num?)?.toInt() ?? 0,
    consistencyScore:  (j['consistencyScore']  as num?)?.toInt() ?? 0,
    improvement:       (j['improvement']       as num?)?.toInt() ?? 0,
    streak:            (j['streak']            as num?)?.toInt() ?? 0,
    bestShift:         (j['bestShift']         as num?)?.toInt() ?? 0,
    worstShift:        (j['worstShift']        as num?)?.toInt() ?? 0,
    trendDirection:    j['trendDirection']?.toString()   ?? 'stable',
    totalRunMinutes:   (j['totalRunMinutes']   as num?)?.toInt() ?? 0,
    utilizationPct:    (j['utilizationPct']    as num?)?.toInt() ?? 0,
    anomalyCount:      (j['anomalyCount']      as num?)?.toInt() ?? 0,
    isActive:          j['isActive'] as bool? ?? false,
    trend: (j['trend'] as List?)?.map((e)=>TrendPoint.fromJson(e as Map<String,dynamic>)).toList() ?? [],
  );
}

class Achievement {
  final String id;
  final String label;
  final String icon;
  final String desc;
  const Achievement({ required this.id, required this.label, required this.icon, required this.desc });
  factory Achievement.fromJson(Map<String,dynamic> j) => Achievement(
    id:    j['id']?.toString()    ?? '',
    label: j['label']?.toString() ?? '',
    icon:  j['icon']?.toString()  ?? '🏆',
    desc:  j['desc']?.toString()  ?? '',
  );
}

class EmployeeAnalytics {
  final String employeeId;
  final String name;
  final String department;
  final String skill;
  final String role;
  final int    rank;
  final int    shiftCount;
  final int    totalProduction;
  final int    avgPerShift;
  final int    consistencyScore;
  final int    improvement;
  final int    streak;
  final int    bestShift;
  final int    worstShift;
  final String trendDirection;
  final int    totalRunMinutes;
  final int    anomalyCount;
  final String badge;
  final String badgeLabel;
  final bool   isTopPerformer;
  final int    percentile;
  final int    xp;
  final int    level;
  final String levelLabel;
  final String levelIcon;
  final String levelColor;
  final int    levelProgress;
  final int?   nextLevelXp;
  final List<String>      xpBreakdown;
  final List<Achievement> achievements;

  const EmployeeAnalytics({
    required this.employeeId, required this.name,       required this.department,
    required this.skill,      required this.role,        required this.rank,
    required this.shiftCount, required this.totalProduction, required this.avgPerShift,
    required this.consistencyScore, required this.improvement, required this.streak,
    required this.bestShift,  required this.worstShift,  required this.trendDirection,
    required this.totalRunMinutes, required this.anomalyCount,
    required this.badge,      required this.badgeLabel,  required this.isTopPerformer,
    required this.percentile, required this.xp,           required this.level,
    required this.levelLabel, required this.levelIcon,   required this.levelColor,
    required this.levelProgress, required this.nextLevelXp,
    required this.xpBreakdown, required this.achievements,
  });

  factory EmployeeAnalytics.fromJson(Map<String,dynamic> j) => EmployeeAnalytics(
    employeeId:       j['employeeId']?.toString()       ?? '',
    name:             j['name']?.toString()             ?? '-',
    department:       j['department']?.toString()       ?? '-',
    skill:            j['skill']?.toString()            ?? '-',
    role:             j['role']?.toString()             ?? '-',
    rank:             (j['rank']             as num?)?.toInt() ?? 0,
    shiftCount:       (j['shiftCount']       as num?)?.toInt() ?? 0,
    totalProduction:  (j['totalProduction']  as num?)?.toInt() ?? 0,
    avgPerShift:      (j['avgPerShift']      as num?)?.toInt() ?? 0,
    consistencyScore: (j['consistencyScore'] as num?)?.toInt() ?? 0,
    improvement:      (j['improvement']      as num?)?.toInt() ?? 0,
    streak:           (j['streak']           as num?)?.toInt() ?? 0,
    bestShift:        (j['bestShift']        as num?)?.toInt() ?? 0,
    worstShift:       (j['worstShift']       as num?)?.toInt() ?? 0,
    trendDirection:   j['trendDirection']?.toString()   ?? 'stable',
    totalRunMinutes:  (j['totalRunMinutes']  as num?)?.toInt() ?? 0,
    anomalyCount:     (j['anomalyCount']     as num?)?.toInt() ?? 0,
    badge:            j['badge']?.toString()            ?? 'none',
    badgeLabel:       j['badgeLabel']?.toString()       ?? '',
    isTopPerformer:   j['isTopPerformer'] as bool?      ?? false,
    percentile:       (j['percentile']       as num?)?.toInt() ?? 0,
    xp:               (j['xp']               as num?)?.toInt() ?? 0,
    level:            (j['level']            as num?)?.toInt() ?? 1,
    levelLabel:       j['levelLabel']?.toString()       ?? 'Rookie',
    levelIcon:        j['levelIcon']?.toString()        ?? '🌱',
    levelColor:       j['levelColor']?.toString()       ?? '#94A3B8',
    levelProgress:    (j['levelProgress']    as num?)?.toInt() ?? 0,
    nextLevelXp:      (j['nextLevelXp']      as num?)?.toInt(),
    xpBreakdown: (j['xpBreakdown'] as List?)?.map((e)=>e.toString()).toList() ?? [],
    achievements: (j['achievements'] as List?)
        ?.map((e)=>Achievement.fromJson(e as Map<String,dynamic>)).toList() ?? [],
  );
}

class ProductionAnomaly {
  final String type;
  final String severity;
  final String date;
  final String dateLabel;
  final String entityType;
  final String entityId;
  final String entityName;
  final int    value;
  final int    threshold;
  final String message;

  const ProductionAnomaly({
    required this.type,       required this.severity,
    required this.date,       required this.dateLabel,
    required this.entityType, required this.entityId,
    required this.entityName, required this.value,
    required this.threshold,  required this.message,
  });

  factory ProductionAnomaly.fromJson(Map<String,dynamic> j) => ProductionAnomaly(
    type:       j['type']?.toString()       ?? '',
    severity:   j['severity']?.toString()   ?? 'low',
    date:       j['date']?.toString()       ?? '',
    dateLabel:  j['dateLabel']?.toString()  ?? '',
    entityType: j['entityType']?.toString() ?? '',
    entityId:   j['entityId']?.toString()   ?? '',
    entityName: j['entityName']?.toString() ?? '-',
    value:      (j['value']     as num?)?.toInt() ?? 0,
    threshold:  (j['threshold'] as num?)?.toInt() ?? 0,
    message:    j['message']?.toString()    ?? '',
  );

  bool get isHigh   => severity == 'high';
  bool get isMedium => severity == 'medium';

  String get typeLabel {
    switch (type) {
      case 'ZERO_PRODUCTION':  return 'Zero Output';
      case 'LOW_PRODUCTION':   return 'Critical Low';
      case 'UNDERPERFORMANCE': return 'Below Average';
      case 'PRODUCTION_SPIKE': return 'Output Spike';
      default:                 return type;
    }
  }
}

class AnalyticsData {
  final AnalyticsSummary         summary;
  final List<TrendPoint>         trend;
  final List<WeeklyPatternPoint> weeklyPattern;
  final List<MachineAnalytics>   byMachine;
  final List<EmployeeAnalytics>  byEmployee;
  final List<ProductionAnomaly>  anomalies;

  const AnalyticsData({
    required this.summary,       required this.trend,
    required this.weeklyPattern, required this.byMachine,
    required this.byEmployee,    required this.anomalies,
  });

  factory AnalyticsData.fromJson(Map<String,dynamic> j) => AnalyticsData(
    summary:       AnalyticsSummary.fromJson(j['summary'] as Map<String,dynamic>? ?? {}),
    trend:         (j['trend']         as List?)?.map((e)=>TrendPoint.fromJson(e as Map<String,dynamic>)).toList() ?? [],
    weeklyPattern: (j['weeklyPattern'] as List?)?.map((e)=>WeeklyPatternPoint.fromJson(e as Map<String,dynamic>)).toList() ?? [],
    byMachine:     (j['byMachine']     as List?)?.map((e)=>MachineAnalytics.fromJson(e as Map<String,dynamic>)).toList() ?? [],
    byEmployee:    (j['byEmployee']    as List?)?.map((e)=>EmployeeAnalytics.fromJson(e as Map<String,dynamic>)).toList() ?? [],
    anomalies:     (j['anomalies']     as List?)?.map((e)=>ProductionAnomaly.fromJson(e as Map<String,dynamic>)).toList() ?? [],
  );
}