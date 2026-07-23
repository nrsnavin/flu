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
  FeatureDef('/analytics', 'Analytics', 'Overview', ['admin', 'weaving']),
  FeatureDef('/reports', 'Reports', 'Overview', ['admin', 'finance']),
  FeatureDef('/audit', 'Audit Trail', 'Overview', ['admin']),

  FeatureDef('/orders', 'Orders', 'Sales', ['admin', 'finance']),
  FeatureDef('/jobs', 'Job Orders', 'Sales', ['admin', 'preparatory', 'weaving', 'packing']),
  FeatureDef('/delivery-challans', 'Delivery Challans', 'Sales', ['admin', 'finance']),

  FeatureDef('/planner', 'Auto Planner', 'Production', ['admin', 'weaving']),
  FeatureDef('/warping', 'Warping', 'Production', ['admin', 'preparatory']),
  FeatureDef('/covering', 'Covering', 'Production', ['admin', 'preparatory']),
  FeatureDef('/packing', 'Packing', 'Production', ['admin', 'packing']),
  FeatureDef('/qc', 'Quality Control', 'Production', ['admin', 'packing']),
  FeatureDef('/shift-plans', 'Shift Plans', 'Production', ['admin', 'weaving']),
  FeatureDef('/shift-verification', 'Shift Verification', 'Production', ['admin', 'weaving']),
  FeatureDef('/production', 'Production View', 'Production', ['admin', 'weaving']),
  FeatureDef('/wastage', 'Wastage', 'Production', ['admin', 'weaving']),

  FeatureDef('/customers', 'Customers', 'Masters', ['admin', 'finance']),
  FeatureDef('/suppliers', 'Suppliers', 'Masters', ['admin', 'finance']),
  FeatureDef('/purchase-orders', 'Purchase Orders', 'Masters', ['admin', 'finance']),
  FeatureDef('/materials', 'Raw Materials', 'Masters', ['admin', 'finance']),
  FeatureDef('/elastics', 'Elastic Products', 'Masters', ['admin', 'finance']),
  FeatureDef('/elastic-groups', 'Elastic Groups', 'Masters', ['admin']),
  FeatureDef('/machines', 'Machines', 'Masters', ['admin', 'weaving']),
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

const _floor = ['preparatory', 'weaving', 'packing'];

List<String> allFeatureKeys() => kFeatures.map((f) => f.key).toList();

List<String> alwaysOnKeys() =>
    kFeatures.where((f) => f.always).map((f) => f.key).toList();

// Default feature set for a department — used to seed the checklist.
List<String> featuresForDepartment(String dept) {
  if (dept == 'admin') return allFeatureKeys();
  return kFeatures
      .where((f) {
        if (f.depts == null) return true;
        if (dept == 'production') return f.depts!.any(_floor.contains);
        return f.depts!.contains(dept);
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
