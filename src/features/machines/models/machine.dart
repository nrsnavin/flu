// ══════════════════════════════════════════════════════════════
//  MACHINE MODELS — unified single file
// ══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  MachineListItem  (used in list view)
// ─────────────────────────────────────────────────────────────

class MachineListItem {
  final String id;        // MongoDB _id
  final String machineCode; // e.g. "LOOM-EL-01"
  final String manufacturer;
  final int noOfHeads;
  final int noOfHooks;
  final String status;  // "free" | "running" | "maintenance"

  const MachineListItem({
    required this.id,
    required this.machineCode,
    required this.manufacturer,
    required this.noOfHeads,
    required this.noOfHooks,
    required this.status,
  });

  /// FIX: original MachineList.fromJson used a strict `switch` pattern
  /// match that required `elastics` to be a String. The API actually
  /// returns `elastics` as a List<Map> (array of {elastic, head} objects).
  /// This caused a FormatException on EVERY machine → list was always empty.
  factory MachineListItem.fromJson(Map<String, dynamic> json) {
    return MachineListItem(
      id:           json['_id']?.toString()          ?? '',
      machineCode:  json['ID']?.toString()           ?? '—',
      manufacturer: json['manufacturer']?.toString() ?? '—',
      noOfHeads:    (json['NoOfHead']  as num?)?.toInt() ?? 0,
      noOfHooks:    (json['NoOfHooks'] as num?)?.toInt() ?? 0,
      status:       json['status']?.toString()       ?? 'free',
    );
  }

  bool get isRunning     => status == 'running';
  bool get isFree        => status == 'free';
  bool get isMaintenance => status == 'maintenance';
}

// ─────────────────────────────────────────────────────────────
//  MachineDetail  (used in detail view)
// ─────────────────────────────────────────────────────────────

class MachineDetail {
  final String machineCode;
  final String manufacturer;
  final int noOfHeads;
  final int noOfHooks;
  final String status;
  final String? dateOfPurchase;
  final String? currentJobNo;    // job order number if running
  final List<Map<String, dynamic>> elastics;

  const MachineDetail({
    required this.machineCode,
    required this.manufacturer,
    required this.noOfHeads,
    required this.noOfHooks,
    required this.status,
    this.dateOfPurchase,
    this.currentJobNo,
    this.elastics = const [],
  });

  factory MachineDetail.fromJson(Map<String, dynamic> json) {
    return MachineDetail(
      machineCode:    json['id']?.toString()           ?? '—',
      manufacturer:   json['manufacturer']?.toString() ?? '—',
      noOfHeads:      (json['heads']  as num?)?.toInt() ?? 0,
      noOfHooks:      (json['hooks']  as num?)?.toInt() ?? 0,
      status:         json['status']?.toString()       ?? 'free',
      dateOfPurchase: json['dateOfPurchase']?.toString(),
      currentJobNo:   json['currentJobNo']?.toString(),
      elastics:       (json['elastics'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
          [],
    );
  }

  bool get isRunning     => status == 'running';
  bool get isFree        => status == 'free';
  bool get isMaintenance => status == 'maintenance';
}

// ─────────────────────────────────────────────────────────────
//  MachineShiftHistory  (shift rows in detail view)
// ─────────────────────────────────────────────────────────────

class MachineShiftHistory {
  final String id;
  final DateTime date;
  final String shiftType;      // "DAY" | "NIGHT"
  final String operatorName;
  final int runtimeMinutes;
  final int outputMeters;
  final double efficiency;     // 0–100 percent
  final String? description;
  final String? feedback;

  const MachineShiftHistory({
    required this.id,
    required this.date,
    required this.shiftType,
    required this.operatorName,
    required this.runtimeMinutes,
    required this.outputMeters,
    required this.efficiency,
    this.description,
    this.feedback,
  });

  factory MachineShiftHistory.fromJson(Map<String, dynamic> json) {
    return MachineShiftHistory(
      id:             json['id']?.toString()           ?? '',
      date:           DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      shiftType:      json['shift']?.toString()        ?? '—',
      operatorName:   json['employee']?.toString()     ?? '—',
      runtimeMinutes: (json['runtimeMinutes'] as num?)?.toInt() ?? 0,
      outputMeters:   (json['outputMeters']   as num?)?.toInt() ?? 0,
      efficiency:     double.tryParse(
          json['efficiency']?.toString() ?? '0') ?? 0.0,
      description:    json['description']?.toString(),
      feedback:       json['feedback']?.toString(),
    );
  }

  String get runtimeFormatted {
    final h = runtimeMinutes ~/ 60;
    final m = runtimeMinutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ─────────────────────────────────────────────────────────────
//  MachineCreate  (payload for add form)
//
//  FIX: removed `elastics` field — elastics are assigned per-head
//  during the weaving plan step, NOT at machine creation time.
//  Sending a String for elastics was violating the schema array type.
// ─────────────────────────────────────────────────────────────

class MachineCreate {
  final String machineCode;
  final String manufacturer;
  final int noOfHeads;
  final int noOfHooks;
  final String? dateOfPurchase;

  const MachineCreate({
    required this.machineCode,
    required this.manufacturer,
    required this.noOfHeads,
    required this.noOfHooks,
    this.dateOfPurchase,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'ID':           machineCode,
      'manufacturer': manufacturer,
      'NoOfHead':     noOfHeads,
      'NoOfHooks':    noOfHooks,
    };
    if (dateOfPurchase != null && dateOfPurchase!.isNotEmpty) {
      map['DateOfPurchase'] = dateOfPurchase;
    }
    return map;
  }
}