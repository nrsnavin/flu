// ignore_for_file: avoid_print
import 'bulk_result.dart';

// ══════════════════════════════════════════════════════════════
//  RUN ME:  dart run src/core/bulk_result_check.dart
//
//  bulk_result.dart imports no Flutter, so it runs on a bare Dart VM
//  from the repo root (as scan_payload_check.dart does).
//
//  Guarded because the failure it replaced was silent: the screen said
//  "5 machines updated" for a batch of which the server had taken 3.
// ══════════════════════════════════════════════════════════════

int failed = 0;
void check(String what, bool ok, [String extra = '']) {
  print('${ok ? "PASS" : "FAIL"}  $what ${ok ? '' : extra}');
  if (!ok) failed++;
}

void main() {
  // ── Everything went ───────────────────────────────────────
  var r = BulkSaveResult.from({'success': true, 'saved': 3, 'skipped': []}, 3);
  check('all saved: not partial', !r.partial && r.saved == 3);
  check('all saved: the count alone', r.message() == '3 shifts saved', r.message());
  check('one is singular',
      BulkSaveResult.from({'saved': 1, 'skipped': []}, 1).message() == '1 shift saved');
  check('the caller names the thing',
      BulkSaveResult.from({'saved': 2, 'skipped': []}, 2)
              .message(one: 'machine', many: 'machines') ==
          '2 machines saved');

  // ── Some were left out ────────────────────────────────────
  r = BulkSaveResult.from({
    'saved': 3,
    'skipped': [
      {'id': 'a', 'reason': 'Already closed'},
      {'id': 'b', 'reason': 'Already closed'},
      {'id': 'c', 'reason': 'Shift is finalised — an admin must reopen it first'},
    ],
  }, 6);
  check('partial is said', r.partial && r.saved == 3 && r.skipped == 3);
  check('each reason once, with how many',
      r.message() ==
          '3 shifts saved. 3 not taken: Already closed (2); Shift is finalised — an admin must reopen it first.',
      r.message());

  // ── CONTROLS: what was SENT is never reported as saved ────
  r = BulkSaveResult.from({'saved': 0, 'skipped': [{'id': 'a', 'reason': 'Machine was loading'}]}, 5);
  check('nothing taken says 0, not what was sent', r.message().startsWith('0 shifts saved'), r.message());
  r = BulkSaveResult.from({'skipped': [{'id': 'a'}, {'id': 'b'}]}, 5);
  check('no count sent: sent less skipped', r.saved == 3 && r.skipped == 2, '${r.saved}/${r.skipped}');
  check('a reason that is missing still counts', r.message().contains('2 not taken: Not taken (2).'), r.message());

  // ── An answer that says nothing (an older server) ─────────
  check('an empty body is taken at its word', BulkSaveResult.from(null, 4).message() == '4 shifts saved');
  check('a body that is not a map', BulkSaveResult.from('ok', 4).saved == 4);
  check('skipped sent as a number (never was a list) is ignored',
      BulkSaveResult.from({'saved': 4, 'skipped': 0}, 4).message() == '4 shifts saved');

  print(failed == 0 ? '\nall passed' : '\n$failed FAILED');
  if (failed != 0) throw StateError('$failed check(s) failed');
}
