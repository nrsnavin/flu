// ══════════════════════════════════════════════════════════════
//  EMPLOYEE MODELS — unified single file
// ══════════════════════════════════════════════════════════════

import '../aadhaar_qr.dart' show AadhaarCheck;

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
  final double hourlyRate;
  final Map<String, dynamic>? skillProfile;
  /// As on their Aadhaar card ('' when not recorded).
  final String dob;
  final String gender;
  final String address;
  final String pincode;
  /// The last check of their Aadhaar card's QR code; null until someone checks it.
  final AadhaarCheck? aadhaarCheck;

  const EmployeeDetail({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.department,
    required this.role,
    required this.aadhar,
    required this.performance,
    required this.totalShifts,
    this.hourlyRate = 0,
    this.skillProfile,
    this.dob = '',
    this.gender = '',
    this.address = '',
    this.pincode = '',
    this.aadhaarCheck,
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
      hourlyRate:  double.tryParse(json['hourlyRate']?.toString() ?? '0') ?? 0,
      skillProfile: json['skillProfile'] is Map
          ? Map<String, dynamic>.from(json['skillProfile'] as Map)
          : null,
      dob:          json['dob']?.toString()          ?? '',
      gender:       json['gender']?.toString()       ?? '',
      address:      json['address']?.toString()      ?? '',
      pincode:      json['pincode']?.toString()      ?? '',
      aadhaarCheck: AadhaarCheck.from(json['aadhaarCheck']),
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

  /// ₹/hour — derived from the DAY-shift (12h) salary the form asks for.
  final double hourlyRate;

  /// Onboarding skill & performance questionnaire (see
  /// skill_questionnaire_form.dart). Sent as-is; backend schema
  /// validates the enum levels.
  final Map<String, dynamic>? skillProfile;

  /// As on the Aadhaar card (sent only when filled in).
  final String dob;      // YYYY-MM-DD
  final String gender;   // male, female or other
  final String address;
  final String pincode;

  /// The card's QR code, scanned on the form with the holder's consent:
  /// the server reads it again and keeps the check with the record.
  final String? aadhaarQr;

  const EmployeeCreate({
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.department,
    required this.aadhaar,
    this.hourlyRate = 0,
    this.skillProfile,
    this.dob = '',
    this.gender = '',
    this.address = '',
    this.pincode = '',
    this.aadhaarQr,
  });

  Map<String, dynamic> toJson() => {
    'name':        name,
    'phoneNumber': phoneNumber,
    'role':        role,
    'department':  department,
    'aadhar':      aadhaar,   // schema field is 'aadhar' not 'aadhaar'
    'hourlyRate':  hourlyRate,
    if (skillProfile != null) 'skillProfile': skillProfile,
    if (dob.isNotEmpty) 'dob': dob,
    if (gender.isNotEmpty) 'gender': gender,
    if (address.isNotEmpty) 'address': address,
    if (pincode.isNotEmpty) 'pincode': pincode,
    if (aadhaarQr != null) ...{'aadhaarQr': aadhaarQr, 'aadhaarQrConsent': true},
  };
}