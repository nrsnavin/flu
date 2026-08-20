// The model, not the widget: this file is arithmetic, and importing
// the chart would pull dart:ui in and make it untestable off-device.
import '../../core/models/mini_bar.dart';

// ══════════════════════════════════════════════════════════════
//  TURNING A REPORT SERIES INTO BARS YOU CAN TRUST ON A PHONE
//
//  All five report endpoints return the same shape: a list of
//  { date: "YYYY-MM-DD", <metric>: n }, one entry per day, sorted.
//  The web hands that straight to recharts. Doing the same here would
//  be wrong twice over, and both faults are silent.
//
//  ── 1. The series omits days, and that closes real gaps ────────
//  Every one of the five builds its series with a $group over the
//  documents that exist in the window. A day on which nothing was
//  produced, dispatched, ordered or purchased produces no group, so
//  it is ABSENT — not zero. Plotted as-is the bars sit shoulder to
//  shoulder, and a week with three idle days looks exactly like a
//  week with seven busy ones. On a wide axis with dated ticks a
//  person might catch the jump; in a 120px strip on a phone, nobody
//  will.
//
//  So every day between the first and the last is filled in, and the
//  ones the server did not mention get 0 — which is what happened.
//
//  ── Why the window comes from the keys, not from `range` ───────
//  The obvious source for the window is the report's own
//  range.from/range.to. It is the wrong one. resolveRange() builds
//  those bounds with setHours(0,0,0,0) — midnight in the SERVER's
//  local zone — while the series keys are written by $dateToString,
//  which is UTC. On an IST deployment the two are a day apart: the
//  window would start a day early and, worse, end a day early, so
//  the most recent day's bar would silently vanish from the chart.
//  Reconciling them would mean guessing the server's offset. The
//  keys themselves carry no such ambiguity, so the span between the
//  first and last of them is what gets filled.
//
//  The cost is that a stretch of idle days at either END of the
//  period is not drawn — the chart starts at the first day something
//  happened. That is visible and mild; a closed interior gap, or a
//  missing final day, is neither.
//
//  ── 2. A financial year is 366 bars ────────────────────────────
//  At the FY preset that is a sub-pixel bar per day: a grey smear
//  that reads as texture, not data. Past a month of days the series
//  is bucketed into calendar months instead.
//
//  Bucketing by SUM is only valid because every one of these five
//  metrics is a period total — metres, rupees, quantity, net kilos.
//  None is an average, a rate or a closing balance, so a month is
//  genuinely the sum of its days. A series carrying one of those
//  must not come through here.
// ══════════════════════════════════════════════════════════════

/// Past this many days, days become months.
const int _maxDailyBars = 31;

/// Roughly how many axis labels fit under a phone-width chart before
/// they collide into an illegible grey band.
const int _maxAxisLabels = 6;

/// A guard against a malformed key pair spinning the fill loop. Two
/// years of days is far past the longest preset (a financial year).
const int _maxFilledDays = 800;

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _key(DateTime utcDay) {
  final m = utcDay.month.toString().padLeft(2, '0');
  final d = utcDay.day.toString().padLeft(2, '0');
  return '${utcDay.year}-$m-$d';
}

/// Parse a "YYYY-MM-DD" key as a UTC day, or null if it is not one.
DateTime? _day(String key) {
  final parsed = DateTime.tryParse('${key}T00:00:00Z');
  return parsed?.isUtc == true ? parsed : null;
}

/// Build chart bars from a report's `series`.
///
/// [metricKey] is the field the report plots — `meters`, `amount`,
/// `quantity`, `value`, `net`. Returns an empty list when there is
/// nothing to draw, which the chart renders as a stated empty state
/// rather than an empty box.
List<MiniBar> buildReportBars(
  List<Map<String, dynamic>> series,
  String metricKey,
) {
  final byDay = <String, double>{};
  for (final point in series) {
    final date = point['date']?.toString();
    if (date == null || _day(date) == null) continue;
    // Sum rather than assign: a repeated key must not be dropped, or
    // the day would be understated by whatever the first entry held.
    byDay[date] =
        (byDay[date] ?? 0) + ((point[metricKey] as num?)?.toDouble() ?? 0);
  }
  if (byDay.isEmpty) return const [];

  final present = byDay.keys.toList()..sort();
  final first = _day(present.first)!;
  final last = _day(present.last)!;

  final days = <String>[];
  var cursor = first;
  while (!cursor.isAfter(last) && days.length < _maxFilledDays) {
    days.add(_key(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }

  if (days.length <= _maxDailyBars) {
    return _thinLabels([
      for (final d in days)
        MiniBar(label: d.substring(8), value: byDay[d] ?? 0),
    ]);
  }

  // Months, in order, summing the days that fall in each.
  final months = <String>[];
  final byMonth = <String, double>{};
  for (final d in days) {
    final m = d.substring(0, 7);
    if (!byMonth.containsKey(m)) months.add(m);
    byMonth[m] = (byMonth[m] ?? 0) + (byDay[d] ?? 0);
  }

  return _thinLabels([
    for (final m in months)
      MiniBar(
        label: _monthNames[int.parse(m.substring(5)) - 1],
        value: byMonth[m] ?? 0,
      ),
  ]);
}

/// Thin the axis labels without dropping any bars.
///
/// The bar has to stay — it is the data — but thirty-one labels under
/// a phone-width chart shrink into an illegible band, which is worse
/// than none. Every bar keeps its place; only some are named.
List<MiniBar> _thinLabels(List<MiniBar> bars) {
  if (bars.length <= _maxAxisLabels) return bars;
  final step = (bars.length / _maxAxisLabels).ceil();
  return [
    for (var i = 0; i < bars.length; i++)
      MiniBar(
        label: i % step == 0 ? bars[i].label : '',
        value: bars[i].value,
      ),
  ];
}
