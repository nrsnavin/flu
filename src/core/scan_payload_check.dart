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

  _checkTargets();

  print(failed == 0 ? '\nALL PASS' : '\n$failed FAILED');
}

// ══════════════════════════════════════════════════════════════
//  THE FOUR LABELS, AND WHERE EACH ONE GOES
//
//  These payloads are copied from the web's own encoders — see
//  prod_web PackingSlip.tsx:63, CoveringLabels.tsx:95 and
//  WarpingPrints.tsx:213. If those change, these fail, which is the
//  point: the two ends of a printed label have no other thing
//  holding them together.
// ══════════════════════════════════════════════════════════════

const boxId = '70ff2b1a4c9d88e3a1b0c2d4';
const covId = '5c1d9f3e77a0b4c2d8e6f019';

void _checkTargets() {
  // ── Job label ─────────────────────────────────────────────
  var c = parseScannedCode('https://erp.example.com/jobs/$id');
  check('job URL targets the job', c.target == ScanTarget.job, 'got $c');
  check('job URL is direct', c.isDirect && c.id == id, 'got $c');

  // ── Box label ─────────────────────────────────────────────
  c = parseScannedCode('BOX|$boxId|J:1042');
  check('box targets packing', c.target == ScanTarget.packing, 'got $c');
  check('box carries the packing id', c.id == boxId, 'got $c');
  check('box carries the job number too', c.jobNo == 1042, 'got $c');
  check('box opens without a lookup', c.isDirect);

  // A box whose job was not populated when it printed. Still a box,
  // and still openable — the job number is the part that is missing.
  c = parseScannedCode('BOX|$boxId|J:');
  check('box with no job number still targets packing',
      c.target == ScanTarget.packing && c.id == boxId, 'got $c');
  check('box with no job number has none', c.jobNo == null, 'got $c');

  // ── The em-dash ───────────────────────────────────────────
  // `jobNo` is `job?.jobOrderNo ?? "—"`, so this is a real label.
  //
  // These pin the BEHAVIOUR, not the mechanism. Deleting the explicit
  // `v == '—'` guard in _field does not fail them, because
  // int.tryParse rejects an em-dash on its own — checked by mutation,
  // rather than assumed. The guard stays as documentation of what the
  // web actually prints, but it is belt-and-braces: the thing that
  // must not regress is that no job number comes out of it.
  c = parseScannedCode('WARP|J:—|B:1|W:$covId');
  check('em-dash is not a job number', c.jobNo == null, 'got $c');
  check('em-dash label yields nothing to open', c.isEmpty, 'got $c');
  check('a hyphen is treated the same',
      parseScannedCode('WARP|J:-|B:1|W:$covId').jobNo == null);

  // ── Beam labels resolve to their job, by number ───────────
  c = parseScannedCode('WARP|J:1042|B:3|T:7|W:$covId');
  check('warping beam targets the job', c.target == ScanTarget.job, 'got $c');
  check('warping beam gives the job number', c.jobNo == 1042, 'got $c');
  check('warping beam needs a lookup', !c.isDirect, 'got $c');

  c = parseScannedCode('COVB|J:1042|C:$covId|B:2|E:$boxId');
  check('covering beam targets the job', c.target == ScanTarget.job, 'got $c');
  check('covering beam gives the job number', c.jobNo == 1042, 'got $c');

  // The covering id must NOT be mistaken for a job id. This is the
  // failure that would open a real screen showing the wrong record,
  // which is worse than opening nothing.
  check('covering id is not passed off as a job id', c.id == null, 'got $c');

  // ── CONTROLS ──────────────────────────────────────────────
  check('an unknown pipe format is rejected',
      parseScannedCode('PALLET|$boxId|X:1').isEmpty,
      'got ${parseScannedCode('PALLET|$boxId|X:1')}');
  check('a BOX with a non-id in the id slot is not openable',
      parseScannedCode('BOX|not-an-id|J:').isEmpty,
      'got ${parseScannedCode('BOX|not-an-id|J:')}');
  check('a BOX with a non-id but a real job number keeps the number',
      parseScannedCode('BOX|not-an-id|J:1042').jobNo == 1042);
  check('J: on a warping label must be a number, not an id',
      parseScannedCode('WARP|J:$covId|B:1').isEmpty,
      'got ${parseScannedCode('WARP|J:$covId|B:1')}');
  check('a negative job number is rejected',
      parseScannedCode('WARP|J:-4|B:1').isEmpty);

  // ── The job-only view still behaves ───────────────────────
  // These are what packing, QC and the challan already call.
  check('parseScannedJob still reads a job URL',
      parseScannedJob('https://h/jobs/$id').id == id);
  check('a box label offers its job number to the job picker',
      parseScannedJob('BOX|$boxId|J:1042').jobNo == 1042);
  check('a box id is NEVER offered as a job id',
      parseScannedJob('BOX|$boxId|J:1042').id == null,
      'got ${parseScannedJob('BOX|$boxId|J:1042')}');
  check('a beam label offers its job number to the job picker',
      parseScannedJob('WARP|J:1042|B:1|W:$covId').jobNo == 1042);

  // ── Wording ───────────────────────────────────────────────
  check('an unlinked beam label says it was printed too early',
      scanRejectionMessage('WARP|J:—|B:1').contains('before its job'));
  check('a corrupt box label says it needs reprinting',
      scanRejectionMessage('BOX||J:').contains('reprinting'),
      'got "${scanRejectionMessage('BOX||J:')}"');

  _checkShiftRows();
}

// ══════════════════════════════════════════════════════════════
//  THE SHIFT SHEET ROW
//
//  Written by prod utils/shiftSheetPdf.js, not by the web:
//
//    SHIFTROW|<shift detail id>|M:<machine ID>|J:<job no>
//
//  …with `SD-XXXXXX` printed beside it in the Code column for a
//  person to read out. The id is ShiftDetail._id, which is what
//  /shift/shiftDetail?id= takes — so the scan opens the row's own
//  screen with no lookup.
// ══════════════════════════════════════════════════════════════

const sdId = '64b1f0c2a9e77d5310cc4482';

void _checkShiftRows() {
  var c = parseScannedCode('SHIFTROW|$sdId|M:M-14|J:J-1042');
  check('a shift row targets the shift', c.target == ScanTarget.shift, 'got $c');
  check('a shift row carries the shift detail id', c.id == sdId, 'got $c');
  check('a shift row opens without a lookup', c.isDirect, 'got $c');

  // `J:` on THIS label is "J-1042", not "1042" — the printed job
  // label, because the column is meant to be read.
  //
  // Checked by mutation: making SHIFTROW parse `J:` does NOT fail
  // these, because int.tryParse('J-1042') is null regardless. So the
  // assertion below pins behaviour that is currently true for a
  // reason other than the code that expresses it, and the one after
  // it is the load-bearing one — a shift row opens the SHIFT even if
  // that column ever starts carrying a bare number.
  check('a shift row exposes no job number', c.jobNo == null, 'got $c');

  final asIfBare = parseScannedCode('SHIFTROW|$sdId|M:M-14|J:1042');
  check('a shift row still opens the shift, whatever J: holds',
      asIfBare.target == ScanTarget.shift && asIfBare.id == sdId,
      'got $asIfBare');

  // The em-dash again — an unassigned machine or job prints as "—".
  c = parseScannedCode('SHIFTROW|$sdId|M:—|J:—');
  check('a shift row with no machine or job still opens',
      c.target == ScanTarget.shift && c.id == sdId, 'got $c');

  // ── CONTROLS ──────────────────────────────────────────────
  check('a shift row with a damaged id opens nothing',
      parseScannedCode('SHIFTROW|xxxx|M:M-14').isEmpty,
      'got ${parseScannedCode('SHIFTROW|xxxx|M:M-14')}');
  check('a shift row is not mistaken for a job',
      parseScannedCode('SHIFTROW|$sdId|M:M-14|J:J-1042').target !=
          ScanTarget.job);
  check('a shift row is not offered to the job picker',
      parseScannedJob('SHIFTROW|$sdId|M:M-14|J:J-1042').isEmpty,
      'got ${parseScannedJob('SHIFTROW|$sdId|M:M-14|J:J-1042')}');

  // ── The short code is a reading aid, not an identifier ────
  // Six hex characters against an id space where collisions are
  // ordinary. Resolving it would eventually open somebody else's
  // shift, so it is recognised only to say what to do instead.
  c = parseScannedCode('SD-A3F291');
  check('the short code opens nothing', c.isEmpty, 'got $c');
  check('the short code is recognised as one', c.label == 'shift-code',
      'got $c');
  check('the short code says to scan the square code instead',
      scanRejectionMessage('SD-A3F291').contains('square code'),
      'got "${scanRejectionMessage('SD-A3F291')}"');
  check('lowercase short code too',
      parseScannedCode('SD-a3f291').label == 'shift-code');

  check('CONTROL: SD- followed by non-hex is not a short code',
      parseScannedCode('SD-ZZZZZZ').label == null,
      'got ${parseScannedCode('SD-ZZZZZZ')}');
  check('CONTROL: SD- followed by too many chars is not one',
      parseScannedCode('SD-A3F291B').label == null);

  // ── The two message paths agree ───────────────────────────
  // scanCodeMessage and scanRejectionMessage used to be one function
  // that reparsed; the navigator now calls the first directly. If
  // they ever disagree, one caller is lying to the operator.
  for (final raw in [
    'BOX||J:',
    'WARP|J:—|B:1',
    'SHIFTROW|xxxx|M:M-14',
    'SD-A3F291',
    'PALLET|1|X:2',
  ]) {
    check('both message paths agree on "$raw"',
        scanCodeMessage(parseScannedCode(raw)) == scanRejectionMessage(raw),
        'code="${scanCodeMessage(parseScannedCode(raw))}" '
        'raw="${scanRejectionMessage(raw)}"');
  }
}
