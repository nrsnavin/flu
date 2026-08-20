import 'scan_payload.dart';

// ══════════════════════════════════════════════════════════════
//  RUN ME:  dart run src/core/scan_payload_check.dart
//
//  Same reasoning as report_series_check.dart: this repo carries no
//  pubspec and no test harness, but scan_payload.dart imports no
//  Flutter, so it runs on a bare Dart VM from the repo root with
//  nothing to install.
//
//  Worth guarding because every failure here is silent in the same
//  direction — the operator scans a good label, nothing is selected,
//  and the conclusion is "the scanner does not work". The CONTROLS
//  matter as much as the cases: a parser that accepted everything
//  would pass most of the positive tests on its own.
// ══════════════════════════════════════════════════════════════

int failed = 0;
void check(String what, bool ok, [String extra = '']) {
  print('${ok ? "PASS" : "FAIL"}  $what ${ok ? '' : extra}');
  if (!ok) failed++;
}

const id = '6a85c96260514cc7d9a7401f';

void main() {
  // ── The label's own payload ───────────────────────────────
  var r = parseScannedJob('https://erp.example.com/jobs/$id');
  check('label URL yields the id', r.id == id, 'got $r');
  check('label URL yields no jobNo', r.jobNo == null, 'got $r');

  check('http as well as https',
      parseScannedJob('http://erp.example.com/jobs/$id').id == id);
  check('a trailing slash is fine',
      parseScannedJob('https://h/jobs/$id/').id == id);
  check('a query string is fine',
      parseScannedJob('https://h/jobs/$id?print=1').id == id);
  check('a fragment is fine',
      parseScannedJob('https://h/jobs/$id#top').id == id);
  check('a port is fine',
      parseScannedJob('http://192.168.1.9:5173/jobs/$id').id == id);
  check('uppercase hex is fine',
      parseScannedJob('https://h/jobs/${id.toUpperCase()}').id ==
          id.toUpperCase());
  check('surrounding whitespace is trimmed',
      parseScannedJob('  https://h/jobs/$id \n').id == id);

  // ── The other two shapes ──────────────────────────────────
  check('a bare object id', parseScannedJob(id).id == id);
  check('a bare job number', parseScannedJob('4821').jobNo == 4821,
      'got ${parseScannedJob('4821')}');
  check('a hash-prefixed job number',
      parseScannedJob('#4821').jobNo == 4821);
  check('a job number is not read as an id',
      parseScannedJob('4821').id == null);

  // ── CONTROLS: things that must NOT match ──────────────────
  // Without these, a parser that returned something for every input
  // would pass every test above.
  check('a non-job URL is rejected',
      parseScannedJob('https://erp.example.com/orders/$id').isEmpty,
      'got ${parseScannedJob('https://erp.example.com/orders/$id')}');
  check('a bare hostname is rejected',
      parseScannedJob('https://erp.example.com').isEmpty);
  check('free text is rejected',
      parseScannedJob('BATCH-2291-RUBBER').isEmpty);
  check('an empty string is rejected', parseScannedJob('').isEmpty);
  check('null is rejected', parseScannedJob(null).isEmpty);
  check('23 hex chars is not an id',
      parseScannedJob(id.substring(1)).isEmpty,
      'got ${parseScannedJob(id.substring(1))}');
  check('25 hex chars is not an id',
      parseScannedJob('${id}a').isEmpty);
  check('non-hex of the right length is not an id',
      parseScannedJob('z' * 24).isEmpty);
  check('zero is not a job number', parseScannedJob('0').isEmpty);
  check('a 10-digit barcode is not a job number',
      parseScannedJob('8901234567890').isEmpty,
      'got ${parseScannedJob('8901234567890')}');
  check('a number with a suffix is not a job number',
      parseScannedJob('4821-A').isEmpty);
  check('jobs elsewhere in the path does not match',
      parseScannedJob('https://h/archive/jobs-old/$id').isEmpty,
      'got ${parseScannedJob('https://h/archive/jobs-old/$id')}');

  // ── The rejection wording is specific ─────────────────────
  check('a stray link is named as a link',
      scanRejectionMessage('https://example.com').contains('link'));
  check('nothing read says so',
      scanRejectionMessage('').contains('Nothing'));

  print(failed == 0 ? '\nALL PASS' : '\n$failed FAILED');
}
