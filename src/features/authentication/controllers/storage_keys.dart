class StorageKeys {
  static const isLoggedIn = 'isLoggedIn';
  static const token     = 'token';
  static const id        = 'id';
  static const name      = 'name';
  static const role      = 'role';
  // Comma-joined per-user feature keys (nav paths). Empty => unrestricted.
  static const features  = 'features';
  // A worker's own login (the server's "selfService"): the app opens on
  // the employee screens. Kept so a cold start with no signal still
  // opens on the right side.
  static const selfService = 'selfService';
  // The employee record this login is linked to, if any: a staff login
  // with one gets "My work".
  static const employee  = 'employee';
}
