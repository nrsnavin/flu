// Feature catalog — mirrors prod/utils/features.js and the web nav. A
// user's `features` list (nav-path keys) decides what they can open;
// `depts == null` marks an always-on feature.

class FeatureDef {
  final String key;
  final String label;
  final String section;
  final List<String>? depts; // null => always-on (never gated)
  const FeatureDef(this.key, this.label, this.section, [this.depts]);
  bool get always => depts == null;
}

const List<FeatureDef> kFeatures = [
  FeatureDef('/', 'Dashboard', 'Overview'),
  FeatureDef('/analytics', 'Analytics', 'Overview', ['admin', 'production']),
  FeatureDef('/reports', 'Reports', 'Overview', ['admin', 'finance']),
  // Margin is its own permission: opening an order and seeing the profit
  // on it are different things. Read-only on the phone — the rates and
  // the rate card are entered on the web, where a mistyped figure that
  // re-costs the whole factory is less likely.
  FeatureDef('/order-pnl', 'Order P&L', 'Overview', ['admin', 'finance']),
  FeatureDef('/audit', 'Audit Trail', 'Overview', ['admin']),

  FeatureDef('/orders', 'Orders', 'Sales', ['admin', 'finance']),
  FeatureDef('/jobs', 'Job Orders', 'Sales', ['admin', 'production', 'packing']),
  FeatureDef('/delivery-challans', 'Delivery Challans', 'Sales', ['admin', 'finance']),
  // Tax invoices raised against an order's challans, with the IRN.
  FeatureDef('/invoices', 'Invoices', 'Sales', ['admin', 'finance']),
  // Bills, expenses, receipts and payments, ledgers and ageing.
  FeatureDef('/accounts', 'Accounts', 'Sales', ['admin', 'finance']),
  FeatureDef('/samples', 'Sample Requests', 'Sales', ['admin', 'finance', 'production']),
  // What is packed and waiting to leave, in delivery-urgency order.
  // Marketing sets the urgency; finance raises the challan; packing sends it.
  FeatureDef('/dispatch', 'Dispatch', 'Sales', ['admin', 'finance', 'packing', 'marketing']),

  FeatureDef('/planner', 'Auto Planner', 'Production', ['admin', 'production']),
  FeatureDef('/warping', 'Warping', 'Production', ['admin', 'production']),
  FeatureDef('/covering', 'Covering', 'Production', ['admin', 'production']),
  FeatureDef('/packing', 'Packing', 'Production', ['admin', 'packing']),
  FeatureDef('/qc', 'Quality Control', 'Production', ['admin', 'packing']),
  FeatureDef('/complaints', 'Complaints', 'Production', ['admin', 'packing', 'production']),
  FeatureDef('/shift-plans', 'Shift Plans', 'Production', ['admin', 'production']),
  FeatureDef('/shift-verification', 'Shift Verification', 'Production', ['admin', 'production']),
  FeatureDef('/production', 'Production View', 'Production', ['admin', 'production']),
  FeatureDef('/wastage', 'Wastage', 'Production', ['admin', 'production']),

  FeatureDef('/customers', 'Customers', 'Masters', ['admin', 'finance']),
  FeatureDef('/suppliers', 'Suppliers', 'Masters', ['admin', 'finance']),
  FeatureDef('/purchase-orders', 'Purchase Orders', 'Masters', ['admin', 'finance']),
  FeatureDef('/quotes', 'Quotations', 'Masters', ['admin', 'finance']),
  FeatureDef('/materials', 'Raw Materials', 'Masters', ['admin', 'finance']),
  FeatureDef('/elastics', 'Elastic Products', 'Masters', ['admin', 'finance']),
  FeatureDef('/elastic-groups', 'Elastic Groups', 'Masters', ['admin']),
  FeatureDef('/machines', 'Machines', 'Masters', ['admin', 'production']),
  FeatureDef('/employees', 'Employees', 'Masters', ['admin', 'finance']),

  FeatureDef('/attendance', 'Attendance', 'HR & Payroll', ['admin', 'finance']),
  FeatureDef('/payroll', 'Payroll', 'HR & Payroll', ['admin', 'finance']),
  FeatureDef('/bonus', 'Bonus', 'HR & Payroll', ['admin', 'finance']),
  FeatureDef('/leave', 'Leave', 'HR & Payroll', ['admin', 'finance']),

  FeatureDef('/announcements', 'Announcements', 'Communication'),
  FeatureDef('/feedback', 'Feedback', 'Communication'),
  // Anyone signed in enters what they spent; Accounts approves.
  FeatureDef('/claims', 'Expense Claims', 'Communication'),
  FeatureDef('/machine-issues', 'Machine Issues', 'Communication'),
  FeatureDef('/notification-settings', 'Notifications', 'Communication', ['admin']),

  FeatureDef('/advisor', 'AI Advisor', 'AI', ['admin', 'finance']),
  FeatureDef('/assistant', 'Ask Jarvis', 'AI'),

  FeatureDef('/users', 'Users', 'Administration', ['admin']),
  FeatureDef('/ai-health', 'AI Health', 'Administration', ['admin']),
  FeatureDef('/data-io', 'Data Import/Export', 'Administration', ['admin']),
  FeatureDef('/settings', 'Settings', 'Administration'),
];

// The departments a login can be given — prod/utils/roles.js DEPARTMENTS.
// Marketing answers for the customer (when a delivery is needed) and has
// its own role on the server.
const List<String> kDepartments = ['admin', 'production', 'packing', 'finance', 'marketing'];

// Legacy departments (pre-merge) alias to the merged "production" dept.
const _legacyDeptAlias = {'preparatory': 'production', 'weaving': 'production'};

List<String> allFeatureKeys([List<FeatureDef> catalog = kFeatures]) =>
    catalog.map((f) => f.key).toList();

List<String> alwaysOnKeys([List<FeatureDef> catalog = kFeatures]) =>
    catalog.where((f) => f.always).map((f) => f.key).toList();

// Default feature set for a department — used to seed the checklist.
List<String> featuresForDepartment(String dept, [List<FeatureDef> catalog = kFeatures]) {
  final d = _legacyDeptAlias[dept] ?? dept;
  if (d == 'admin') return allFeatureKeys(catalog);
  return catalog
      .where((f) {
        if (f.depts == null) return true;
        return f.depts!.contains(d);
      })
      .map((f) => f.key)
      .toList();
}

// Sections in catalog order, for the grouped checklist UI.
List<String> featureSections([List<FeatureDef> catalog = kFeatures]) {
  final seen = <String>[];
  for (final f in catalog) {
    if (!seen.contains(f.section)) seen.add(f.section);
  }
  return seen;
}

// Can this user (by stored feature list) open the given feature key?
// An empty/absent list means "unrestricted" (legacy/admin) → allow all.
bool hasFeature(List<String> features, String key) {
  final def = kFeatures.firstWhere(
    (f) => f.key == key,
    orElse: () => const FeatureDef('', '', ''),
  );
  if (def.always) return true;
  if (features.isEmpty) return true; // no explicit restriction
  return features.contains(key);
}

// ══════════════════════════════════════════════════════════════
//  THE USERS SCREEN ASKS THE SERVER WHAT EXISTS
//
//  The list above is this build's copy of the server's catalogue, and a
//  copy falls behind: Dispatch and the Marketing department were added
//  on the server and the web, and this app did not know them. The menu
//  only lost a module. The Users screen did damage — it sends back the
//  boxes it can show, so saving ANY edit to a login that had Dispatch
//  (a new password, a corrected name) took Dispatch away from them, and
//  a marketing login opened as "Production".
//
//  So the Users screen takes the catalogue and the departments from the
//  server's own answer (GET /user/manage/list sends both) and falls back
//  to this copy only when an older server sends neither.
// ══════════════════════════════════════════════════════════════

/// The server's catalogue (`features` on /user/manage/list) as
/// FeatureDefs; this build's copy when it is absent or unreadable.
List<FeatureDef> catalogFrom(dynamic serverFeatures) {
  if (serverFeatures is! List) return kFeatures;
  final out = <FeatureDef>[];
  for (final f in serverFeatures) {
    if (f is! Map) continue;
    final key = f['key']?.toString() ?? '';
    if (key.isEmpty) continue;
    final depts = f['depts'];
    out.add(FeatureDef(
      key,
      (f['label'] ?? key).toString(),
      (f['section'] ?? 'Other').toString(),
      // "all" on the server is always-on; a list names the departments.
      depts is List ? depts.map((d) => d.toString()).toList() : null,
    ));
  }
  return out.isEmpty ? kFeatures : out;
}

/// The departments to offer (`departments` on /user/manage/list).
List<String> departmentsFrom(dynamic serverDepartments) {
  if (serverDepartments is! List) return kDepartments;
  final out = serverDepartments.map((d) => d.toString()).where((d) => d.isNotEmpty).toList();
  return out.isEmpty ? kDepartments : out;
}

/// The department a login is edited under.
///
/// Its own, when it has one the server still accepts. A pre-merge
/// department (preparatory, weaving) is production: sent back as it was,
/// the server refuses it. A login from before departments existed has
/// only a role, and the role says which department that was — the owner
/// (role admin) must open as Admin, not as Production with every box
/// unticked, where one Save would take the whole app away from them.
String departmentOf(Map<String, dynamic>? user, [List<String> departments = kDepartments]) {
  final dept = (user?['department'] ?? '').toString().trim();
  final d = _legacyDeptAlias[dept] ?? dept;
  if (departments.contains(d)) return d;
  final role = (user?['role'] ?? '').toString().trim().toLowerCase();
  final fromRole = const {
    'admin': 'admin',
    'accounts': 'finance',
    'production': 'production',
    'marketing': 'marketing',
  }[role];
  if (fromRole != null && departments.contains(fromRole)) return fromRole;
  return 'production';
}

/// The boxes ticked when a login is opened: what it has, within what
/// its department can have; the department's own set when it has none
/// stored.
List<String> featuresOnOpen(
  Map<String, dynamic>? user, {
  List<FeatureDef> catalog = kFeatures,
  List<String> departments = kDepartments,
}) {
  final scope = featuresForDepartment(departmentOf(user, departments), catalog);
  final raw = user?['features'];
  if (raw is List && raw.isNotEmpty) {
    final has = raw.map((x) => x.toString()).toSet();
    return scope.where(has.contains).toList();
  }
  return scope;
}
