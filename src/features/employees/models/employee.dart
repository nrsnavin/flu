// ══════════════════════════════════════════════════════════════
//  EMPLOYEE MODELS — unified single file
// ══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  EmployeeListItem  (list view)
//
//  FIX: original Emplist.fromJson used an exhaustive switch pattern
//  requiring 'role': String role.  Schema has `role` with no required
//  flag, so any employee created without a role returned null and
//  the switch fell to the throw branch → FormatException on EVERY
//  employee → list always empty.
//  FIX: `import 'dart:ffi'` was present — completely wrong import.
// ─────────────────────────────────────────────────────────────

class EmployeeListItem {
  final String id;
  final String name;
  final String department;
  final String role;
  final double performance;
  final String? phoneNumber;

  const EmployeeListItem({
    required this.id,
    required this.name,
    required this.department,
    required this.role,
    required this.performance,
    this.phoneNumber,
  });

  factory EmployeeListItem.fromJson(Map<String, dynamic> json) {
    return EmployeeListItem(
      id:          json['_id']?.toString()           ?? '',
      name:        json['name']?.toString()          ?? '—',
      department:  json['department']?.toString()    ?? '—',
      role:        json['role']?.toString()          ?? '—',
      performance: double.tryParse(
          json['performance']?.toString() ?? '0') ?? 0.0,
      phoneNumber: json['phoneNumber']?.toString(),
    );
  }

  /// First letter of name for avatar
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ─────────────────────────────────────────────────────────────
//  EmployeeDetail  (detail view)
// ─────────────────────────────────────────────────────────────

class EmployeeDetail {
  final String id;
  final String name;
  final String phoneNumber;
  final String department;
  final String role;
  final String aadhar;
  final double performance;
  final int totalShifts;

  const EmployeeDetail({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.department,
    required this.role,
    required this.aadhar,
    required this.performance,
    required this.totalShifts,
  });

  factory EmployeeDetail.fromJson(Map<String, dynamic> json) {
    return EmployeeDetail(
      id:          json['id']?.toString()            ?? '',
      name:        json['name']?.toString()          ?? '—',
      phoneNumber: json['phoneNumber']?.toString()   ?? '—',
      department:  json['department']?.toString()    ?? '—',
      role:        json['role']?.toString()          ?? '—',
      aadhar:      json['aadhar']?.toString()        ?? 'Not Provided',
      performance: double.tryParse(
          json['performance']?.toString() ?? '0') ?? 0.0,
      totalShifts: (json['totalShifts'] as num?)?.toInt() ?? 0,
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ─────────────────────────────────────────────────────────────
//  ShiftHistory  (shift rows in detail view)
//
//  FIX: fromJson had no null guards → any null field in API response
//  caused a TypeError crash.
// ─────────────────────────────────────────────────────────────

class ShiftHistory {
  final String id;
  final DateTime date;
  final String shiftType;
  final String machineName;
  final String description;
  final String feedback;
  final int runtimeMinutes;
  final int outputMeters;
  final double efficiency;

  const ShiftHistory({
    required this.id,
    required this.date,
    required this.shiftType,
    required this.machineName,
    required this.runtimeMinutes,
    required this.outputMeters,
    required this.efficiency,
    required this.description,
    required this.feedback,
  });

  factory ShiftHistory.fromJson(Map<String, dynamic> json) {
    return ShiftHistory(
      id:             json['id']?.toString()           ?? '',
      date:           DateTime.tryParse(
          json['date']?.toString() ?? '') ??
          DateTime.now(),
      shiftType:      json['shift']?.toString()        ?? '—',
      machineName:    json['machine']?.toString()      ?? '—',
      runtimeMinutes: (json['runtimeMinutes'] as num?)?.toInt() ?? 0,
      outputMeters:   (json['outputMeters']   as num?)?.toInt() ?? 0,
      efficiency:     double.tryParse(
          json['efficiency']?.toString() ?? '0') ?? 0.0,
      description:    json['description']?.toString() ?? '',
      feedback:       json['feedback']?.toString()    ?? '',
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
//  EmployeeCreate  (add form payload)
// ─────────────────────────────────────────────────────────────

class EmployeeCreate {
  final String name;
  final String phoneNumber;
  final String role;
  final String department;
  final String aadhaar;

  const EmployeeCreate({
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.department,
    required this.aadhaar,
  });

  Map<String, dynamic> toJson() => {
    'name':        name,
    'phoneNumber': phoneNumber,
    'role':        role,
    'department':  department,
    'aadhar':      aadhaar,   // schema field is 'aadhar' not 'aadhaar'
  };
}