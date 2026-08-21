// Run with:  dart run src/features/profile/user_profile_check.dart

import 'user_profile.dart';

int _passed = 0;
final _failures = <String>[];

void check(String what, bool ok, [String? detail]) {
  if (ok) {
    _passed++;
  } else {
    _failures.add('FAIL: $what${detail == null ? '' : '  ($detail)'}');
  }
}

void main() {
  // ── Initials ──────────────────────────────────────────────
  // First and last word, not the first two characters.
  check('two names give two letters', initialsFor('Ravi Kumar') == 'RK');
  check('one name gives one letter', initialsFor('Anu') == 'A');
  check('three names use first and LAST',
      initialsFor('Ravi Shankar Kumar') == 'RK',
      'got ${initialsFor('Ravi Shankar Kumar')}');
  check('already upper stays upper', initialsFor('RAVI KUMAR') == 'RK');
  check('lower is raised', initialsFor('ravi kumar') == 'RK');
  check('extra spaces do not produce blanks',
      initialsFor('  Ravi   Kumar  ') == 'RK');
  check('an empty name gives a placeholder', initialsFor('') == '?');
  check('whitespace only gives a placeholder', initialsFor('   ') == '?');

  // CONTROL: the naive version — name.substring(0, 2) — would give
  // 'RA' here, and this is the assertion that would catch it.
  check('CONTROL: not the first two characters',
      initialsFor('Ravi Kumar') != 'RA');

  // ── Title case ────────────────────────────────────────────
  // `department` is stored as typed and `role` is lowercased by
  // utils/roles.js, so printing them side by side needs one of them
  // normalised or the screen reads as a bug.
  check('a lowercase role is raised', titleCase('production') == 'Production');
  check('an underscore becomes a space',
      titleCase('quality_control') == 'Quality Control');
  check('SHOUTING is calmed', titleCase('ACCOUNTS') == 'Accounts');
  check('mixed is normalised', titleCase('hUmAn ReSources') == 'Human Resources');
  check('empty stays empty', titleCase('') == '');
  check('whitespace stays empty', titleCase('   ') == '');

  // ── Member since ──────────────────────────────────────────
  check('a date reads as a month and year',
      memberSinceLabel(DateTime.utc(2026, 3, 14)) == 'Member since March 2026');
  check('December is not off by one',
      memberSinceLabel(DateTime.utc(2025, 12, 1)) == 'Member since December 2025',
      'got ${memberSinceLabel(DateTime.utc(2025, 12, 1))}');
  check('January is not off by one',
      memberSinceLabel(DateTime.utc(2025, 1, 1)) == 'Member since January 2025');
  check('no date gives null, not a placeholder',
      memberSinceLabel(null) == null,
      'a profile reading "Member since —" is worse than one that '
      'does not mention it');

  // ── The feature list, which reads backwards ───────────────
  // An empty list means UNRESTRICTED. Rendering it as "no access"
  // would tell an admin they can open nothing.
  final unrestricted = UserProfile.fromJson({
    'name': 'Owner', 'role': 'admin', 'features': [],
  });
  check('an empty feature list is not a limit',
      !unrestricted.hasFeatureLimits);

  final limited = UserProfile.fromJson({
    'name': 'Floor Lead', 'role': 'production',
    'features': ['/jobs', '/warping'],
  });
  check('a populated feature list IS a limit', limited.hasFeatureLimits);
  check('the features survive parsing', limited.features.length == 2);

  final missing = UserProfile.fromJson({'name': 'X'});
  check('an absent feature list is not a limit', !missing.hasFeatureLimits,
      'absent and empty must mean the same thing here');

  check('blank feature entries are dropped',
      UserProfile.fromJson({'features': ['/jobs', '', '/qc']})
          .features.length == 2);

  // ── The linked employee ───────────────────────────────────
  // Office logins have none. An empty staff card would imply the
  // person is missing from the workforce, which is a different and
  // alarming claim.
  check('no employee key gives null',
      UserProfile.fromJson({'name': 'Clerk'}).employee == null);
  check('a null employee gives null',
      UserProfile.fromJson({'employee': null}).employee == null);
  check('CONTROL: an employee object is kept',
      UserProfile.fromJson({
        'employee': {'_id': 'e1', 'name': 'Ravi', 'department': 'weaving'},
      }).employee?.name == 'Ravi');
  check('an employee with no id is not an employee',
      LinkedEmployee.fromJson({'name': 'Ghost'}) == null,
      'a populate that failed comes back as a fragment, and rendering '
      'it would show a staff card for somebody who is not there');
  check('a non-map employee does not throw',
      LinkedEmployee.fromJson('e1') == null);

  // ── Parsing the real shape ────────────────────────────────
  final p = UserProfile.fromJson({
    'id': 'u1',
    'name': 'Ravi Kumar',
    'email': 'ravi@t.co',
    'role': 'production',
    'department': 'Weaving',
    'createdAt': '2026-03-14T06:20:00.000Z',
    'employee': {
      '_id': 'e9', 'name': 'Ravi Kumar', 'department': 'Weaving',
      'phoneNumber': '9000000000', 'role': 'operator',
    },
    'features': ['/jobs'],
  });
  check('id parses', p.id == 'u1');
  check('email parses', p.email == 'ravi@t.co');
  check('createdAt parses', p.memberSince?.year == 2026);
  check('the employee phone parses', p.employee?.phoneNumber == '9000000000');
  check('initials come off the name', initialsFor(p.name) == 'RK');

  // A malformed date must not throw — a profile page is not worth
  // taking down over a timestamp.
  check('a broken date is null rather than an exception',
      UserProfile.fromJson({'createdAt': 'not-a-date'}).memberSince == null);
  check('an empty date is null',
      UserProfile.fromJson({'createdAt': ''}).memberSince == null);

  for (final f in _failures) {
    // ignore: avoid_print
    print(f);
  }
  // ignore: avoid_print
  print(_failures.isEmpty
      ? 'ALL PASS ($_passed checks)'
      : '${_failures.length} FAILED, $_passed passed');
}
