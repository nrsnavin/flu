// ══════════════════════════════════════════════════════════════
//  WASTAGE MODELS — unified single file
// ══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  WastageJobSummary  (list page: one card per job)
//
//  BUGS FIXED:
//  1. checkingJobModel.dart: JobElasticModel.fromJson reads
//     json["elastic"] as String but after populate it's a Map
//     → toString() = "[object Object]". Null-safe parse handles
//     both unpopulated (ObjectId string) and populated (Map).
// ─────────────────────────────────────────────────────────────

class WastageJobSummary {
  final String id;
  final int jobOrderNo;
  final String status;
  final DateTime date;
  final String? customerName;
  final double totalWastage;
  final int wastageCount;
  final DateTime? lastAdded;
  final List<WastageElasticTally> wastageElastic;

  const WastageJobSummary({
    required this.id,
    required this.jobOrderNo,
    required this.status,
    required this.date,
    this.customerName,
    required this.totalWastage,
    required this.wastageCount,
    this.lastAdded,
    required this.wastageElastic,
  });

  factory WastageJobSummary.fromJson(Map<String, dynamic> json) {
    final cust = json['customer'];
    return WastageJobSummary(
      id:           json['_id']?.toString()          ?? '',
      jobOrderNo:  (json['jobOrderNo'] as num?)?.toInt() ?? 0,
      status:       json['status']?.toString()       ?? '—',
      date:         DateTime.tryParse(
          json['date']?.toString() ?? '') ??
          DateTime.now(),
      customerName: cust is Map
          ? cust['name']?.toString()
          : cust?.toString(),
      totalWastage: (json['totalWastage'] as num?)?.toDouble() ?? 0.0,
      wastageCount: (json['wastageCount'] as num?)?.toInt()    ?? 0,
      lastAdded:    DateTime.tryParse(
          json['lastAdded']?.toString() ?? ''),
      wastageElastic: (json['wastageElastic'] as List? ?? [])
          .map((e) => WastageElasticTally.fromJson(
          e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WastageElasticTally  (per-elastic wastage total on a job)
// ─────────────────────────────────────────────────────────────

class WastageElasticTally {
  final String elasticId;
  final String elasticName;
  final double quantity;

  const WastageElasticTally({
    required this.elasticId,
    required this.elasticName,
    required this.quantity,
  });

  factory WastageElasticTally.fromJson(Map<String, dynamic> json) {
    final el = json['elastic'];
    return WastageElasticTally(
      // FIX: handle both unpopulated ObjectId string and populated Map
      elasticId:   el is Map ? el['_id']?.toString()  ?? '' : el?.toString() ?? '',
      elasticName: el is Map ? el['name']?.toString() ?? '—' : '—',
      quantity:   (json['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WastageRecord  (individual wastage entry)
// ─────────────────────────────────────────────────────────────

class WastageRecord {
  final String id;
  final String jobId;
  final int? jobNo;
  final String? jobStatus;
  final String elasticId;
  final String elasticName;
  final String employeeId;
  final String employeeName;
  final String? employeeDept;
  final double quantity;
  final double penalty;
  final String reason;
  final DateTime createdAt;

  const WastageRecord({
    required this.id,
    required this.jobId,
    this.jobNo,
    this.jobStatus,
    required this.elasticId,
    required this.elasticName,
    required this.employeeId,
    required this.employeeName,
    this.employeeDept,
    required this.quantity,
    required this.penalty,
    required this.reason,
    required this.createdAt,
  });

  factory WastageRecord.fromJson(Map<String, dynamic> json) {
    final job = json['job'];
    final el  = json['elastic'];
    final emp = json['employee'];
    return WastageRecord(
      id:           json['_id']?.toString()          ?? '',
      jobId:        job is Map ? job['_id']?.toString() ?? ''
          : job?.toString() ?? '',
      jobNo:        job is Map
          ? (job['jobOrderNo'] as num?)?.toInt()
          : null,
      jobStatus:    job is Map ? job['status']?.toString() : null,
      elasticId:    el is Map  ? el['_id']?.toString()  ?? '' : el?.toString()  ?? '',
      elasticName:  el is Map  ? el['name']?.toString() ?? '—' : '—',
      employeeId:   emp is Map ? emp['_id']?.toString() ?? '' : emp?.toString() ?? '',
      employeeName: emp is Map ? emp['name']?.toString() ?? '—' : '—',
      employeeDept: emp is Map ? emp['department']?.toString() : null,
      quantity:    (json['quantity'] as num?)?.toDouble() ?? 0.0,
      penalty:     (json['penalty']  as num?)?.toDouble() ?? 0.0,
      reason:       json['reason']?.toString()       ?? '—',
      createdAt:    DateTime.tryParse(
          json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WastageJobOption  (Add Wastage — job selector dropdown)
//
//  BUGS FIXED:
//  1. elastic._id was read as String but after populate is Map.
//  2. elastic.name was never populated → "Elastic ID: xxx".
// ─────────────────────────────────────────────────────────────

class WastageJobOption {
  final String id;
  final int jobOrderNo;
  final String status;
  final List<WastageElasticOption> elastics;

  const WastageJobOption({
    required this.id,
    required this.jobOrderNo,
    required this.status,
    required this.elastics,
  });

  factory WastageJobOption.fromJson(Map<String, dynamic> json) {
    return WastageJobOption(
      id:         json['_id']?.toString()           ?? '',
      jobOrderNo: (json['jobOrderNo'] as num?)?.toInt() ?? 0,
      status:     json['status']?.toString()        ?? 'weaving',
      elastics: (json['elastics'] as List? ?? [])
          .map((e) => WastageElasticOption.fromJson(
          e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WastageElasticOption {
  final String id;
  final String name; // FIX: was elasticId only — no name
  final int quantity;

  const WastageElasticOption({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory WastageElasticOption.fromJson(Map<String, dynamic> json) {
    // FIX: elastic can be a populated Map {_id, name} or bare ObjectId string
    final el = json['elastic'];
    return WastageElasticOption(
      id:       el is Map ? el['_id']?.toString() ?? '' : el?.toString() ?? '',
      name:     el is Map ? el['name']?.toString() ?? '—' : '—',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName => name != '—' ? name : id;
}

// ─────────────────────────────────────────────────────────────
//  EmployeeOption  (Add Wastage — employee selector)
// ─────────────────────────────────────────────────────────────

class EmployeeOption {
  final String id;
  final String name;
  final String? department;

  const EmployeeOption({
    required this.id,
    required this.name,
    this.department,
  });

  factory EmployeeOption.fromJson(Map<String, dynamic> json) {
    return EmployeeOption(
      id:         json['_id']?.toString()         ?? '',
      name:       json['name']?.toString()        ?? '—',
      department: json['department']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WastageAnalytics  (summary / analytics page)
// ─────────────────────────────────────────────────────────────

class WastageAnalytics {
  final List<EmployeeWastageStat> topEmployees;
  final List<ElasticWastageStat>  byElastic;
  final List<StatusWastageStat>   byStatus;
  final List<DailyWastageStat>    trend;
  final double totalWastage;
  final double totalPenalty;
  final int    totalCount;
  final int    days;

  const WastageAnalytics({
    required this.topEmployees,
    required this.byElastic,
    required this.byStatus,
    required this.trend,
    required this.totalWastage,
    required this.totalPenalty,
    required this.totalCount,
    required this.days,
  });

  factory WastageAnalytics.fromJson(Map<String, dynamic> json) {
    return WastageAnalytics(
      topEmployees: (json['topEmployees'] as List? ?? [])
          .map((e) => EmployeeWastageStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      byElastic: (json['byElastic'] as List? ?? [])
          .map((e) => ElasticWastageStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      byStatus: (json['byStatus'] as List? ?? [])
          .map((e) => StatusWastageStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      trend: (json['trend'] as List? ?? [])
          .map((e) => DailyWastageStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalWastage:  (json['totalWastage']  as num?)?.toDouble() ?? 0.0,
      totalPenalty:  (json['totalPenalty']  as num?)?.toDouble() ?? 0.0,
      totalCount:    (json['totalCount']    as num?)?.toInt()    ?? 0,
      days:          (json['days']          as num?)?.toInt()    ?? 30,
    );
  }
}

class EmployeeWastageStat {
  final String id;
  final String name;
  final String? department;
  final double total;
  final int count;
  final double avgPenalty;

  const EmployeeWastageStat({
    required this.id,
    required this.name,
    this.department,
    required this.total,
    required this.count,
    required this.avgPenalty,
  });

  factory EmployeeWastageStat.fromJson(Map<String, dynamic> json) {
    return EmployeeWastageStat(
      id:         json['_id']?.toString()         ?? '',
      name:       json['name']?.toString()        ?? '—',
      department: json['department']?.toString(),
      total:     (json['total']      as num?)?.toDouble() ?? 0.0,
      count:     (json['count']      as num?)?.toInt()    ?? 0,
      avgPenalty:(json['avgPenalty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ElasticWastageStat {
  final String id;
  final String name;
  final double total;
  final int count;

  const ElasticWastageStat({
    required this.id,
    required this.name,
    required this.total,
    required this.count,
  });

  factory ElasticWastageStat.fromJson(Map<String, dynamic> json) {
    return ElasticWastageStat(
      id:    json['_id']?.toString()    ?? '',
      name:  json['name']?.toString()   ?? '—',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt()    ?? 0,
    );
  }
}

class StatusWastageStat {
  final String status;
  final double total;
  final int count;

  const StatusWastageStat({
    required this.status,
    required this.total,
    required this.count,
  });

  factory StatusWastageStat.fromJson(Map<String, dynamic> json) {
    return StatusWastageStat(
      status: json['_id']?.toString()    ?? '—',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt()    ?? 0,
    );
  }
}

class DailyWastageStat {
  final String date;    // "YYYY-MM-DD"
  final double total;
  final int count;

  const DailyWastageStat({
    required this.date,
    required this.total,
    required this.count,
  });

  factory DailyWastageStat.fromJson(Map<String, dynamic> json) {
    return DailyWastageStat(
      date:  json['date']?.toString()    ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt()    ?? 0,
    );
  }

  DateTime get dateTime =>
      DateTime.tryParse(date) ?? DateTime.now();
}