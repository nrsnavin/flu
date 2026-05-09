/// Keys used in SharedPreferences for the employee app's persistent
/// session. Kept as a single source of truth so login/logout/auth-gate
/// can't drift out of sync.
class StorageKeys {
  static const isLoggedIn = 'isLoggedIn';
  static const token      = 'token';
  static const userId     = 'userId';
  static const userName   = 'userName';
  static const userEmail  = 'userEmail';
  static const userRole   = 'userRole';
  // Linked employee id (the canonical filter for shift/wastage/payroll
  // queries). Saved on login so the home dashboard can render even
  // when /user/me hasn't been re-fetched yet.
  static const employeeId       = 'employeeId';
  static const employeeName     = 'employeeName';
  static const employeeDept     = 'employeeDept';
  static const employeeRole     = 'employeeRole';
  static const employeePhone    = 'employeePhone';
  static const employeeRate     = 'employeeRate';
}
