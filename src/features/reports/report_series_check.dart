import 'report_series.dart';

// ══════════════════════════════════════════════════════════════
//  RUN ME:  dart run src/features/reports/report_series_check.dart
//
//  This repo carries no pubspec and no test harness, so there is
//  nowhere for a package:test file to live. What made a check
//  possible here anyway is that report_series.dart is arithmetic
//  with no Flutter import — so this runs on a bare Dart VM from the
//  repo root, with no package config and nothing to install.
//
//  ── Why bother, for a chart ────────────────────────────────────
//  Because every failure this guards against is SILENT. A chart that
//  drops an idle day still draws; it just draws a lie, and a lie in
//  the shape of a plausible bar is not something a reviewer or a
//  user will catch. Analysis passing tells you the file compiles and
//  nothing more.
//
//  The first case has a deliberate CONTROL beside it: a series with
//  no gaps must come back the same length. Without it, "4 bars from
//  2 points" would also pass if the builder simply padded everything
//  it was ever handed.
// ══════════════════════════════════════════════════════════════

int failed = 0;
void check(String what, bool ok, [String extra = '']) {
  print('${ok ? "PASS" : "FAIL"}  $what ${ok ? '' : extra}');
  if (!ok) failed++;
}

List<Map<String, dynamic>> pts(Map<String, num> m) =>
    [for (final e in m.entries) {'date': e.key, 'meters': e.value}];

void main() {
  // 1. An interior idle day must appear as a zero bar, not vanish.
  var bars = buildReportBars(
      pts({'2026-08-01': 100, '2026-08-04': 50}), 'meters');
  check('interior gap filled: 4 bars not 2', bars.length == 4,
      'got ${bars.length}');
  check('gap days are zero',
      bars[1].value == 0 && bars[2].value == 0,
      'got ${bars.map((b) => b.value).toList()}');
  check('real values preserved',
      bars.first.value == 100 && bars.last.value == 50);
  check('day labels are day numbers',
      bars.first.label == '01' && bars.last.label == '04',
      'got ${bars.first.label}/${bars.last.label}');

  // CONTROL: without a gap the count must equal the input, or test 1
  // would pass simply because the builder always pads.
  bars = buildReportBars(pts({'2026-08-01': 1, '2026-08-02': 2}), 'meters');
  check('control: no gap => no padding', bars.length == 2, 'got ${bars.length}');

  // 2. Past a month of days, bucket into months summing the days.
  final fy = <String, num>{};
  for (var m = 4; m <= 9; m++) {
    for (var d = 1; d <= 28; d++) {
      fy['2026-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}'] = 2;
    }
  }
  bars = buildReportBars(pts(fy), 'meters');
  check('168 days => 6 month bars', bars.length == 6, 'got ${bars.length}');
  check('each month sums its days (28*2=56)',
      bars.every((b) => b.value == 56),
      'got ${bars.map((b) => b.value).toList()}');
  check('month labels are names',
      bars.first.label == 'Apr' && bars.last.label == 'Sep',
      'got ${bars.first.label}/${bars.last.label}');

  // A month with nothing at all still gets its bar.
  bars = buildReportBars(
      pts({'2026-01-15': 10, '2026-04-15': 20}), 'meters');
  check('empty months between are drawn', bars.length == 4,
      'got ${bars.length}');
  check('empty months are zero',
      bars[1].value == 0 && bars[2].value == 0);

  // 3. Negatives survive (stock movements plot a signed net).
  final signed = [
    {'date': '2026-08-01', 'net': -40},
    {'date': '2026-08-03', 'net': 25},
  ];
  bars = buildReportBars(signed, 'net');
  check('negative preserved, not clamped',
      bars.first.value == -40 && bars.last.value == 25,
      'got ${bars.map((b) => b.value).toList()}');
  check('gap between them filled', bars.length == 3);

  // 4. Axis thinning drops labels, never bars.
  final long = <String, num>{};
  for (var d = 1; d <= 31; d++) {
    long['2026-03-${d.toString().padLeft(2, '0')}'] = d;
  }
  bars = buildReportBars(pts(long), 'meters');
  check('31 days stay daily', bars.length == 31, 'got ${bars.length}');
  final named = bars.where((b) => b.label.isNotEmpty).length;
  check('labels thinned to <=8', named <= 8, 'got $named named');
  check('values all still there',
      bars.map((b) => b.value).reduce((a, b) => a + b) == 496,
      'sum ${bars.map((b) => b.value).reduce((a, b) => a + b)}');

  // 5. Degenerate input is an empty chart, not a crash.
  check('empty series => no bars', buildReportBars([], 'meters').isEmpty);
  check('junk dates ignored',
      buildReportBars([
        {'date': 'not-a-date', 'meters': 5},
        {'date': '', 'meters': 5},
        {'meters': 5},
      ], 'meters').isEmpty);
  check('missing metric reads as zero',
      buildReportBars([{'date': '2026-08-01'}], 'meters').single.value == 0);
  check('duplicate day summed, not dropped',
      buildReportBars([
        {'date': '2026-08-01', 'meters': 3},
        {'date': '2026-08-01', 'meters': 4},
      ], 'meters').single.value == 7);

  // 6. A year of daily points must not produce a year of bars.
  final year = <String, num>{};
  for (var i = 0; i < 366; i++) {
    final d = DateTime.utc(2025, 4, 1).add(Duration(days: i));
    year['${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] = 1;
  }
  bars = buildReportBars(pts(year), 'meters');
  check('366 days => 13 months, not 366 bars', bars.length == 13,
      'got ${bars.length}');
  check('total conserved through bucketing',
      bars.map((b) => b.value).reduce((a, b) => a + b) == 366,
      'got ${bars.map((b) => b.value).reduce((a, b) => a + b)}');

  print(failed == 0 ? '\nALL PASS' : '\n$failed FAILED');
}
