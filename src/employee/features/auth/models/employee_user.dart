/// Combined view of the logged-in user + their linked Employee
/// document. Built from the `/user/me` response.
class EmployeeUser {
  final String userId;
  final String name;
  final String email;
  final String role;

  // ── Linked Employee fields (null if no link) ────────────────
  final String? employeeId;
  final String? department;
  final String? phoneNumber;
  final String? employeeRole;   // from Employee.role (e.g. weaver)
  final double? hourlyRate;

  const EmployeeUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.employeeId,
    this.department,
    this.phoneNumber,
    this.employeeRole,
    this.hourlyRate,
  });

  bool get hasEmployeeLink => employeeId != null && employeeId!.isNotEmpty;

  factory EmployeeUser.fromMe(Map<String, dynamic> j) {
    final emp = j['employee'];
    final empMap = emp is Map ? emp : null;
    return EmployeeUser(
      userId:       j['id']?.toString()      ?? '',
      name:         j['name']?.toString()    ?? '',
      email:        j['email']?.toString()   ?? '',
      role:         j['role']?.toString()    ?? '',
      employeeId:   empMap?['_id']?.toString(),
      department:   empMap?['department']?.toString(),
      phoneNumber:  empMap?['phoneNumber']?.toString(),
      employeeRole: empMap?['role']?.toString(),
      hourlyRate:   (empMap?['hourlyRate'] as num?)?.toDouble(),
    );
  }

  EmployeeUser copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
    String? employeeId,
    String? department,
    String? phoneNumber,
    String? employeeRole,
    double? hourlyRate,
  }) =>
      EmployeeUser(
        userId:        userId        ?? this.userId,
        name:          name          ?? this.name,
        email:         email         ?? this.email,
        role:          role          ?? this.role,
        employeeId:    employeeId    ?? this.employeeId,
        department:    department    ?? this.department,
        phoneNumber:   phoneNumber   ?? this.phoneNumber,
        employeeRole:  employeeRole  ?? this.employeeRole,
        hourlyRate:    hourlyRate    ?? this.hourlyRate,
      );

  static const empty = EmployeeUser(
    userId: '', name: '', email: '', role: '',
  );
}
