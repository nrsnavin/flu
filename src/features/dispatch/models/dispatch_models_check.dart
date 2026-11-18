// ignore_for_file: avoid_print
import 'dispatch_models.dart';

// ══════════════════════════════════════════════════════════════
//  RUN ME:  dart run src/features/dispatch/models/dispatch_models_check.dart
//
//  dispatch_models.dart imports no Flutter, so it runs on a bare Dart
//  VM from the repo root (as src/core/scan_payload_check.dart does).
// ══════════════════════════════════════════════════════════════

int failed = 0;
void check(String what, bool ok, [String extra = '']) {
  print('${ok ? "PASS" : "FAIL"}  $what ${ok ? '' : extra}');
  if (!ok) failed++;
}

void main() {
  // ── What the server sends ─────────────────────────────────
  final q = DispatchQueue.fromJson({
    'success': true,
    'counts': {'awaiting': 1, 'queued': 1, 'late': 1},
    'items': [
      {
        '_id': 'a1', 'kind': 'job', 'job': 'j1', 'customerName': 'Sunrise Garments', 'ref': 'J-3',
        'title': '20mm Knitted, 25mm Knitted +1 more', 'quantity': 125000, 'orderNo': 41,
        'status': 'awaiting_urgency', 'readyAt': '2026-11-18T04:00:00.000Z', 'urgency': null, 'dueAt': null, 'late': false,
      },
      {
        '_id': 'b2', 'kind': 'sample', 'sample': {'_id': 's9'}, 'customerName': 'Zenith', 'ref': 'Sample #12',
        'title': 'Shade card', 'quantity': 0, 'orderNo': null, 'status': 'queued', 'readyAt': '2026-11-17T04:00:00.000Z',
        'urgency': 'today_morning', 'urgencyLabel': 'Today morning', 'dueAt': '2026-11-18T07:30:00.000Z',
        'urgencySetByName': 'Meena', 'late': true,
      },
    ],
  });
  check('two items, in the server\'s order', q.items.length == 2 && q.items.first.ref == 'J-3');
  check('counts as sent', q.awaiting == 1 && q.queued == 1 && q.late == 1);
  final a = q.items[0], b = q.items[1];
  check('awaiting has no urgency or deadline', a.awaiting && a.urgency == null && a.dueAt == null);
  check('job id read', a.jobId == 'j1' && a.sampleId == null);
  check('a populated sample still gives its id', b.sampleId == 's9');
  check('order number and quantity', a.orderNo == 41 && a.quantity == 125000);
  check('a sample with no order', b.orderNo == null && b.quantity == 0);
  check('late and who set it', b.late && b.urgencySetByName == 'Meena');
  check('the deadline is the same instant', b.dueAt!.toUtc().toIso8601String() == '2026-11-18T07:30:00.000Z');

  // Counts worked out when an older server sends none.
  final bare = DispatchQueue.fromJson({'items': [{'_id': 'x', 'status': 'queued', 'late': true}, {'_id': 'y', 'status': 'awaiting_urgency'}]});
  check('counts without counts', bare.awaiting == 1 && bare.queued == 1 && bare.late == 1);
  check('nothing at all is an empty queue', DispatchQueue.fromJson({}).items.isEmpty);

  // ── When it has to leave ──────────────────────────────────
  final now = DateTime(2026, 11, 18, 10, 30);
  check('1 PM today', dueText(DateTime(2026, 11, 18, 13, 0), now) == 'by 1:00 PM today', dueText(DateTime(2026, 11, 18, 13, 0), now));
  check('7 PM today', dueText(DateTime(2026, 11, 18, 19, 0), now) == 'by 7:00 PM today');
  check('end of today', dueText(DateTime(2026, 11, 18, 23, 59, 59), now) == 'by end of day today');
  check('end of tomorrow', dueText(DateTime(2026, 11, 19, 23, 59, 59), now) == 'by end of day tomorrow');
  check('"tomorrow" read the next day is today',
      dueText(DateTime(2026, 11, 19, 23, 59, 59), DateTime(2026, 11, 19, 8, 0)) == 'by end of day today');
  check('yesterday\'s morning slot', dueText(DateTime(2026, 11, 17, 13, 0), now) == 'by 1:00 PM yesterday');
  check('further off names the date', dueText(DateTime(2026, 11, 25, 23, 59, 59), now) == 'by end of day 25 Nov');
  check('midnight is 12, noon is 12', clock(DateTime(2026, 1, 1, 0, 5)) == '12:05 AM' && clock(DateTime(2026, 1, 1, 12, 0)) == '12:00 PM');

  // ── How long ──────────────────────────────────────────────
  check('minutes', span(const Duration(minutes: 45)) == '45m');
  check('hours and minutes', span(const Duration(hours: 2, minutes: 10)) == '2h 10m');
  check('whole hours', span(const Duration(hours: 3)) == '3h');
  check('days and hours', span(const Duration(days: 3, hours: 2)) == '3d 2h');
  check('whole days', span(const Duration(days: 2)) == '2d');
  check('never negative', span(const Duration(minutes: -5)) == '0m');

  // ── Metres, the Indian way ────────────────────────────────
  check('hundreds', metres(950) == '950 m');
  check('thousands', metres(12500) == '12,500 m', metres(12500));
  check('lakhs', metres(125000) == '1,25,000 m', metres(125000));
  check('crores', metres(12500000) == '1,25,00,000 m', metres(12500000));

  print(failed == 0 ? '\nall passed' : '\n$failed FAILED');
  if (failed != 0) throw StateError('$failed check(s) failed');
}
