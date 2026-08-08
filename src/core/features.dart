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
  FeatureDef('/samples', 'Sample Requests', 'Sales', ['admin', 'finance', 'production']),

  FeatureDef('/planner', 'Auto Planner', 'Production', ['admin', 'production']),
  FeatureDef('/warping', 'Warping', 'Production', ['admin', 'production']),
  FeatureDef('/covering', 'Covering', 'Production', ['admin', 'production']),
  FeatureDef('/packing', 'Packing', 'Production', ['admin', 'packing']),
  FeatureDef('/qc', 'Quality Control', 'Production', ['admin', 'packing']),
  FeatureDef('/shift-plans', 'Shift Plans', 'Production', ['admin', 'production']),
  FeatureDef('/shift-verification', 'Shift Verification', 'Production', ['admin', 'production']),
  FeatureDef('/production', 'Production View', 'Production', ['admin', 'production']),
  FeatureDef('/wastage', 'Wastage', 'Production', ['admin', 'production']),

  FeatureDef('/customers', 'Customers', 'Masters', ['admin', 'finance']),
  FeatureDef('/suppliers', 'Suppliers', 'Masters', ['admin', 'finance']),
  FeatureDef('/purchase-orders', 'Purchase Orders', 'Masters', ['admin', 'finance']),
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
  FeatureDef('/machine-issues', 'Machine Issues', 'Communication'),
  FeatureDef('/notification-settings', 'Notifications', 'Communication', ['admin']),

  FeatureDef('/advisor', 'AI Advisor', 'AI', ['admin', 'finance']),
  FeatureDef('/assistant', 'Ask Jarvis', 'AI'),

  FeatureDef('/users', 'Users', 'Administration', ['admin']),
  FeatureDef('/data-io', 'Data Import/Export', 'Administration', ['admin']),
  FeatureDef('/settings', 'Settings', 'Administration'),
];

// Legacy departments (pre-merge) alias to the merged "production" dept.
const _legacyDeptAlias = {'preparatory': 'production', 'weaving': 'production'};

List<String> allFeatureKeys() => kFeatures.map((f) => f.key).toList();

List<String> alwaysOnKeys() =>
    kFeatures.where((f) => f.always).map((f) => f.key).toList();

// Default feature set for a department — used to seed the checklist.
List<String> featuresForDepartment(String dept) {
  final d = _legacyDeptAlias[dept] ?? dept;
  if (d == 'admin') return allFeatureKeys();
  return kFeatures
      .where((f) {
        if (f.depts == null) return true;
        return f.depts!.contains(d);
      })
      .map((f) => f.key)
      .toList();
}

// Sections in catalog order, for the grouped checklist UI.
List<String> featureSections() {
  final seen = <String>[];
  for (final f in kFeatures) {
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
