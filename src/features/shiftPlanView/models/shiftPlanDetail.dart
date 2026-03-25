// ══════════════════════════════════════════════════════════════
//  SHIFT PLAN DETAIL MODEL
//  File: lib/src/features/shiftPlanView/models/shiftPlanDetail.dart
//
//  FIXES:
//  • ShiftPlanDetailModel.fromJson: was reading json['plan'] but the
//    backend /shiftPlanById response wraps machines in json['machines']
//    → machines list was always empty.
//  • ShiftMachineDetail.fromJson: was reading json['productionMeters']
//    but the backend returns the flat key as json['production']
//    → production always showed 0.
//  • Added shiftDetailId field (from json['id']) — the ShiftDetail _id
//    needed to navigate to ShiftDetailPage on double-tap.
// ══════════════════════════════════════════════════════════════

class ShiftPlanDetailModel {
  final String id;
  final String shift;         // "DAY" | "NIGHT"
  final DateTime date;
  final String description;
  final double totalProduction;
  final String status;        // "draft" | "confirmed"
  final List<ShiftMachineDetail> machines;

  const ShiftPlanDetailModel({
    required this.id,
    required this.shift,
    required this.date,
    required this.description,
    required this.totalProduction,
    required this.status,
    required this.machines,
  });

  factory ShiftPlanDetailModel.fromJson(Map<String, dynamic> json) {
    return ShiftPlanDetailModel(
      id:              json['_id']?.toString()         ?? json['id']?.toString() ?? '',
      shift:           json['shift']?.toString()       ?? 'DAY',
      date:            DateTime.tryParse(json['date']?.toString() ?? '')
          ?? DateTime.now(),
      description:     json['description']?.toString() ?? '',
      totalProduction: (json['totalProduction'] as num?)?.toDouble() ?? 0,
      // Older records without this field default to 'confirmed' so they
      // don't suddenly appear as drafts after the migration.
      status:   json['status']?.toString() ?? 'confirmed',
      // FIX: backend returns 'machines', not 'plan'
      machines: (json['machines'] as List<dynamic>?)
          ?.map((e) => ShiftMachineDetail.fromJson(e as Map<String, dynamic>))
          .toList()
          ?? [],
    );
  }
}

class ShiftMachineDetail {
  /// The ShiftDetail document _id — used to navigate to ShiftDetailPage.
  final String shiftDetailId;
  final String machineName;
  final String jobOrderNo;
  final String operatorName;
  final double production;
  final String timer;
  final String status;   // "open" | "running" | "closed"

  const ShiftMachineDetail({
    required this.shiftDetailId,
    required this.machineName,
    required this.jobOrderNo,
    required this.operatorName,
    required this.production,
    required this.timer,
    required this.status,
  });

  factory ShiftMachineDetail.fromJson(Map<String, dynamic> json) {
    return ShiftMachineDetail(
      // FIX: backend returns the ShiftDetail _id as json['id']
      shiftDetailId: json['id']?.toString() ?? '',
      machineName:   json['machineName']?.toString()   ?? '—',
      jobOrderNo:    json['jobOrderNo']?.toString()    ?? '—',
      operatorName:  json['operatorName']?.toString()  ?? '—',
      // FIX: backend flattens this as 'production', not 'productionMeters'
      production:    (json['production'] as num?)?.toDouble() ?? 0,
      timer:         json['timer']?.toString()         ?? '00:00:00',
      status:        json['status']?.toString()        ?? 'open',
    );
  }
}