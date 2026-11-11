/// What the employee side keeps on the phone between openings: the
/// linked employee's card, so the home screen can draw while /user/me
/// is on its way, or with no signal at all.
///
/// The session itself — the token, signed in or not — is the admin
/// app's (see authentication/controllers/storage_keys.dart). These keys
/// are prefixed so they can never overwrite one of those: the employee
/// app's own `isLoggedIn` and `token` had the same names, and clearing
/// "the employee's" would have signed the whole app out.
class EmpStorageKeys {
  static const userId        = 'emp.userId';
  static const userName      = 'emp.userName';
  static const userEmail     = 'emp.userEmail';
  static const userRole      = 'emp.userRole';
  static const employeeId    = 'emp.employeeId';
  static const employeeDept  = 'emp.employeeDept';
  static const employeeRole  = 'emp.employeeRole';
  static const employeePhone = 'emp.employeePhone';
  static const employeeRate  = 'emp.employeeRate';

  static const all = [
    userId, userName, userEmail, userRole,
    employeeId, employeeDept, employeeRole, employeePhone, employeeRate,
  ];
}
