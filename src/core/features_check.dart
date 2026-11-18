// ignore_for_file: avoid_print
import 'features.dart';

// ══════════════════════════════════════════════════════════════
//  RUN ME:  dart run src/core/features_check.dart
//
//  features.dart imports no Flutter, so it runs on a bare Dart VM from
//  the repo root (as scan_payload_check.dart does).
//
//  What is checked: the Users screen never takes away a permission by
//  not knowing it exists, and never opens a login under a department
//  that is not its own.
// ══════════════════════════════════════════════════════════════

int failed = 0;
void check(String what, bool ok, [Object? got]) {
  print('${ok ? "PASS" : "FAIL"}  $what${ok || got == null ? '' : '  → $got'}');
  if (!ok) failed++;
}

bool same(Iterable<String> a, Iterable<String> b) => a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

// What GET /user/manage/list sends (prod/utils/features.js), cut down,
// with one module this build has never heard of.
const server = [
  {'key': '/', 'label': 'Dashboard', 'section': 'Overview', 'depts': 'all'},
  {'key': '/orders', 'label': 'Orders', 'section': 'Sales', 'depts': ['admin', 'finance']},
  {'key': '/dispatch', 'label': 'Dispatch', 'section': 'Sales', 'depts': ['admin', 'finance', 'packing', 'marketing']},
  {'key': '/packing', 'label': 'Packing', 'section': 'Production', 'depts': ['admin', 'packing']},
  {'key': '/gate-pass', 'label': 'Gate Pass', 'section': 'Production', 'depts': ['admin', 'packing']},
  {'key': '/settings', 'label': 'Settings', 'section': 'Administration', 'depts': 'all'},
];

void main() {
  // ── This build's own copy ─────────────────────────────────
  check('Dispatch is in the catalogue', allFeatureKeys().contains('/dispatch'));
  check('marketing is a department', kDepartments.contains('marketing'));
  check('marketing gets Dispatch and the always-on screens, nothing else',
      same(featuresForDepartment('marketing'), [...alwaysOnKeys(), '/dispatch']), featuresForDepartment('marketing'));
  check('packing gets Dispatch', featuresForDepartment('packing').contains('/dispatch'));
  check('production does not', !featuresForDepartment('production').contains('/dispatch'));
  check('admin gets everything', same(featuresForDepartment('admin'), allFeatureKeys()));
  check('a pre-merge department is production',
      same(featuresForDepartment('weaving'), featuresForDepartment('production')));
  check('no key twice', allFeatureKeys().toSet().length == allFeatureKeys().length);
  check('every section is listed once, in order',
      featureSections().toSet().length == featureSections().length && featureSections().first == 'Overview');
  check('the menu still opens an always-on screen for anyone', hasFeature(const ['/orders'], '/settings'));
  check('and refuses what is not granted', !hasFeature(const ['/orders'], '/dispatch'));
  check('granted is granted', hasFeature(const ['/orders', '/dispatch'], '/dispatch'));

  // ── The server's catalogue ────────────────────────────────
  final cat = catalogFrom(server);
  check('read as sent', cat.length == server.length && cat[2].key == '/dispatch' && cat[2].label == 'Dispatch');
  check('"all" is always-on', cat.first.always && cat.last.always && !cat[1].always);
  check('a module this build never heard of is offered', featuresForDepartment('packing', cat).contains('/gate-pass'));
  check('sections in the server\'s order', featureSections(cat).join('|') == 'Overview|Sales|Production|Administration');
  check('nothing sent is this build\'s copy', identical(catalogFrom(null), kFeatures) && identical(catalogFrom(const []), kFeatures));
  check('junk is this build\'s copy', identical(catalogFrom('x'), kFeatures) && identical(catalogFrom(const [1, 'a']), kFeatures));
  check('an entry without a key is skipped', catalogFrom(const [{'label': 'x'}, {'key': '/a', 'depts': 'all'}]).length == 1);
  check('departments as sent', departmentsFrom(const ['admin', 'stores']).join(',') == 'admin,stores');
  check('none sent is this build\'s', identical(departmentsFrom(null), kDepartments) && identical(departmentsFrom(const []), kDepartments));

  // ── The department a login opens under ────────────────────
  check('its own', departmentOf({'department': 'marketing', 'role': 'marketing'}) == 'marketing');
  check('pre-merge weaving is production', departmentOf({'department': 'weaving', 'role': 'production'}) == 'production');
  check('the owner from before departments is Admin', departmentOf({'role': 'admin'}) == 'admin');
  check('role accounts is finance', departmentOf({'role': 'accounts', 'department': null}) == 'finance');
  check('role marketing is marketing', departmentOf({'role': 'marketing', 'department': ''}) == 'marketing');
  check('a retired role is production', departmentOf({'role': 'stores'}) == 'production');
  check('a new login is production', departmentOf(null) == 'production');
  check('a department the server no longer offers falls to the role',
      departmentOf({'department': 'marketing', 'role': 'accounts'}, const ['admin', 'production', 'packing', 'finance']) == 'finance');

  // ── The boxes ticked on opening ───────────────────────────
  final marketing = {'department': 'marketing', 'role': 'marketing', 'features': ['/', '/settings', '/dispatch']};
  check('a marketing login keeps Dispatch', featuresOnOpen(marketing).contains('/dispatch'));
  final packer = {'department': 'packing', 'role': 'production', 'features': ['/', '/packing', '/dispatch', '/gate-pass']};
  check('a packer keeps Dispatch', featuresOnOpen(packer).contains('/dispatch'));
  check('with the server\'s catalogue, also the module this build does not know',
      same(featuresOnOpen(packer, catalog: cat), ['/', '/packing', '/dispatch', '/gate-pass']), featuresOnOpen(packer, catalog: cat));
  check('what the department cannot have is dropped',
      !featuresOnOpen({'department': 'packing', 'features': ['/', '/orders', '/packing']}).contains('/orders'));
  final owner = {'role': 'admin', 'features': allFeatureKeys()};
  check('the old owner opens with everything ticked', same(featuresOnOpen(owner), allFeatureKeys()));
  check('a login with no list gets its department\'s',
      same(featuresOnOpen({'department': 'finance'}), featuresForDepartment('finance')));
  check('and an empty list the same', same(featuresOnOpen({'department': 'finance', 'features': []}), featuresForDepartment('finance')));

  print(failed == 0 ? '\nall passed' : '\n$failed FAILED');
  if (failed != 0) throw StateError('$failed check(s) failed');
}
