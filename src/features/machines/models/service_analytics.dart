// ══════════════════════════════════════════════════════════════
//  WHAT THE FLOOR COSTS TO KEEP RUNNING
//
//  Mirrors services/serviceAnomaly.js. Nothing is recomputed here —
//  the median-and-MAD arithmetic that decides what counts as unusual
//  lives on the server, and a second implementation on the phone would
//  eventually disagree with the web about whose work looks odd.
//
//  ── The findings are not accusations ───────────────────────────
//  Every finding carries an `innocent` reading, and it is required,
//  not optional. These point at named people's work; a statistic
//  printed without the ordinary explanation beside it reads as a
//  charge. The server never uses the word fraud and neither does any
//  screen built on this.
// ══════════════════════════════════════════════════════════════

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

class SpendPoint {
  final String month; // 'YYYY-MM'
  final double total;
  final double labour;
  final double parts;
  final int services;

  const SpendPoint({
    required this.month,
    required this.total,
    required this.labour,
    required this.parts,
    required this.services,
  });

  factory SpendPoint.fromJson(Map<String, dynamic> j) => SpendPoint(
        month: j['month']?.toString() ?? '',
        total: _num(j['total']),
        labour: _num(j['labour']),
        parts: _num(j['parts']),
        services: (j['services'] as num?)?.toInt() ?? 0,
      );

  /// 'Aug' from '2026-08' — the axis label.
  String get shortMonth {
    final parts = month.split('-');
    if (parts.length < 2) return month;
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    return (m >= 1 && m <= 12) ? names[m] : month;
  }
}

class NamedAmount {
  final String name;
  final double amount;
  const NamedAmount({required this.name, required this.amount});
}

class ServiceSpend {
  final int windowDays;
  final List<SpendPoint> series;
  final double total;
  final int services;

  /// The MEDIAN month, not the mean — one rebuild must not become the
  /// number somebody budgets against for the rest of the year.
  final double typicalMonth;
  final double meanMonth;

  final List<NamedAmount> byType;
  final List<NamedAmount> byTechnician;

  const ServiceSpend({
    required this.windowDays,
    required this.series,
    required this.total,
    required this.services,
    required this.typicalMonth,
    required this.meanMonth,
    required this.byType,
    required this.byTechnician,
  });

  factory ServiceSpend.fromJson(Map<String, dynamic> j) => ServiceSpend(
        windowDays: (j['windowDays'] as num?)?.toInt() ?? 365,
        series: (j['series'] as List? ?? const [])
            .map((e) => SpendPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: _num(j['total']),
        services: (j['services'] as num?)?.toInt() ?? 0,
        typicalMonth: _num(j['typicalMonth']),
        meanMonth: _num(j['meanMonth']),
        byType: (j['byType'] as List? ?? const [])
            .map((e) => NamedAmount(
                  name: (e as Map)['type']?.toString() ?? '—',
                  amount: _num(e['amount']),
                ))
            .toList(),
        byTechnician: (j['byTechnician'] as List? ?? const [])
            .map((e) => NamedAmount(
                  name: (e as Map)['technician']?.toString() ?? '—',
                  amount: _num(e['amount']),
                ))
            .toList(),
      );

  static const empty = ServiceSpend(
    windowDays: 365, series: [], total: 0, services: 0,
    typicalMonth: 0, meanMonth: 0, byType: [], byTechnician: [],
  );
}

class Finding {
  final String kind;
  final String subject;
  final double severity;
  final String title;
  final String detail;

  /// The ordinary explanation. Never optional — see the header.
  final String innocent;

  const Finding({
    required this.kind,
    required this.subject,
    required this.severity,
    required this.title,
    required this.detail,
    required this.innocent,
  });

  factory Finding.fromJson(Map<String, dynamic> j) => Finding(
        kind: j['kind']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        severity: _num(j['severity']),
        title: j['title']?.toString() ?? '',
        detail: j['detail']?.toString() ?? '',
        innocent: j['innocent']?.toString() ?? '',
      );
}

class Anomalies {
  /// False when there is too little history to say anything. That is a
  /// different statement from "nothing is wrong", and the screens keep
  /// them apart.
  final bool ready;
  final String? reason;
  final int windowDays;
  final int services;
  final List<Finding> findings;

  const Anomalies({
    required this.ready,
    required this.reason,
    required this.windowDays,
    required this.services,
    required this.findings,
  });

  factory Anomalies.fromJson(Map<String, dynamic> j) => Anomalies(
        ready: j['ready'] == true,
        reason: j['reason']?.toString(),
        windowDays: (j['windowDays'] as num?)?.toInt() ?? 365,
        services: (j['services'] as num?)?.toInt() ?? 0,
        findings: (j['findings'] as List? ?? const [])
            .map((e) => Finding.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static const empty = Anomalies(
      ready: false, reason: null, windowDays: 365, services: 0, findings: []);
}

class CostlyMachine {
  final String machineId;
  final String machineID; // the code on the loom
  final double total;
  final int services;

  const CostlyMachine({
    required this.machineId,
    required this.machineID,
    required this.total,
    required this.services,
  });

  factory CostlyMachine.fromJson(Map<String, dynamic> j) => CostlyMachine(
        machineId: j['machineId']?.toString() ?? '',
        machineID: j['machineID']?.toString() ?? '—',
        total: _num(j['total']),
        services: (j['services'] as num?)?.toInt() ?? 0,
      );
}

class ServiceAnalytics {
  final int days;
  final ServiceSpend spend;
  final Anomalies anomalies;
  final List<CostlyMachine> costliest;

  const ServiceAnalytics({
    required this.days,
    required this.spend,
    required this.anomalies,
    required this.costliest,
  });

  factory ServiceAnalytics.fromJson(Map<String, dynamic> j) => ServiceAnalytics(
        days: (j['days'] as num?)?.toInt() ?? 365,
        spend: j['spend'] == null
            ? ServiceSpend.empty
            : ServiceSpend.fromJson(Map<String, dynamic>.from(j['spend'] as Map)),
        anomalies: j['anomalies'] == null
            ? Anomalies.empty
            : Anomalies.fromJson(Map<String, dynamic>.from(j['anomalies'] as Map)),
        costliest: (j['costliest'] as List? ?? const [])
            .map((e) => CostlyMachine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

// ── Production, for the same machine and the same months ───────
class ProductionPoint {
  final String month;
  final double meters;
  final int shifts;

  const ProductionPoint({
    required this.month,
    required this.meters,
    required this.shifts,
  });

  factory ProductionPoint.fromJson(Map<String, dynamic> j) => ProductionPoint(
        month: j['month']?.toString() ?? '',
        meters: _num(j['meters']),
        shifts: (j['shifts'] as num?)?.toInt() ?? 0,
      );

  String get shortMonth => SpendPoint(
        month: month, total: 0, labour: 0, parts: 0, services: 0,
      ).shortMonth;
}

class ProductionSeries {
  final int days;
  final List<ProductionPoint> series;
  final double totalMeters;

  const ProductionSeries({
    required this.days,
    required this.series,
    required this.totalMeters,
  });

  factory ProductionSeries.fromJson(Map<String, dynamic> j) => ProductionSeries(
        days: (j['days'] as num?)?.toInt() ?? 365,
        series: (j['series'] as List? ?? const [])
            .map((e) => ProductionPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        totalMeters: _num(j['totalMeters']),
      );

  static const empty = ProductionSeries(days: 365, series: [], totalMeters: 0);
}
