import 'package:flutter/material.dart';

import '../models/mini_bar.dart';

export '../models/mini_bar.dart';

// ══════════════════════════════════════════════════════════════
//  A CHART SMALL ENOUGH TO BE WORTH DRAWING BY HAND
//
//  The web draws every series with recharts. This app has no charting
//  dependency, and adding one to render a dozen monthly bars would be
//  a large package for a small job — Production Analytics already
//  makes the same call and hand-rolls its trend line in CustomPaint.
//
//  So this is the shared version of that: one bar chart, used by the
//  five report screens and by the machine spend/production panels,
//  instead of each screen inventing its own.
//
//  ── Why bars and not a line ────────────────────────────────────
//  Every series here is a MONTHLY TOTAL — spend, metres, dispatches.
//  A line implies the value moved continuously between two months,
//  which it did not; a bar says "this is what happened in August" and
//  nothing more. It also makes an empty month readable as zero rather
//  than as a segment sloping through it.
//
//  ── Empty periods are drawn ────────────────────────────────────
//  A chart drawn only from periods WITH output closes the gaps and
//  makes three idle months look like three busy ones. This never
//  filters them out — but it can only draw what it is handed, and
//  not every caller is handed a complete window. The machine trend
//  endpoint gap-fills server-side; the five report endpoints
//  aggregate over rows and omit an empty day entirely, so those
//  callers fill the window first (see reports/report_series.dart).
//
//  ── The signed variant ─────────────────────────────────────────
//  A net figure goes both ways, and a bar below the axis means stock
//  LEAVING. Drawing that through the unsigned path would clamp it to
//  a hairline — visually identical to a month of no movement at all,
//  which is the opposite reading. So signed is a named mode, and the
//  two halves share one scale so a +100 and a -100 are the same
//  length.
//
//  ── It says the numbers too ────────────────────────────────────
//  A bar chart on a 6-inch screen is a shape, not a reading. The
//  highest value is labelled and the axis carries the range, so the
//  chart is a summary and the figures underneath stay authoritative.
// ══════════════════════════════════════════════════════════════

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.bars,
    required this.barColor,
    this.height = 120,
    this.format,
    this.emptyLabel = 'Nothing in this period.',
    this.signed = false,
    this.negativeColor,
  });

  final List<MiniBar> bars;
  final Color barColor;
  final double height;

  /// How a value reads to a person — rupees, metres, a count.
  final String Function(double)? format;
  final String emptyLabel;

  /// Draw a zero line and let bars fall below it. For a net figure
  /// where below the axis means something — stock leaving, not a
  /// small positive.
  final bool signed;

  /// Colour for bars below the zero line. Defaults to [barColor].
  final Color? negativeColor;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    if (signed && bars.any((b) => b.value < 0)) {
      return _buildSigned(context);
    }

    final maxValue = bars.map((b) => b.value).fold<double>(0, (a, b) => a > b ? a : b);
    final fmt = format ?? (v) => v.toStringAsFixed(0);

    // Everything at zero is a real answer — no spend, no output — and
    // must not divide by zero or draw full-height bars.
    final scale = maxValue <= 0 ? 0.0 : 1 / maxValue;

    return Semantics(
      // A bar chart is invisible to a screen reader, and this is the
      // only place the shape is stated in words.
      label: 'Chart: ${bars.length} periods, highest ${fmt(maxValue)}',
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (maxValue > 0 && b.value == maxValue)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: FittedBox(
                                  child: Text(
                                    fmt(b.value),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: barColor,
                                    ),
                                  ),
                                ),
                              ),
                            // A zero month still gets a hairline, so the
                            // month is visibly present and empty rather
                            // than missing from the chart.
                            FractionallySizedBox(
                              heightFactor: b.value <= 0
                                  ? 0.01
                                  : (b.value * scale).clamp(0.02, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: b.value <= 0
                                      ? barColor.withValues(alpha: 0.25)
                                      : barColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _axisLabels(),
          ],
        ),
      ),
    );
  }

  /// Bars above and below a zero line.
  ///
  /// The two halves are sized in proportion to how far the series
  /// actually reaches each way, and each bar is then drawn as a
  /// fraction of its own half. That gives both halves the SAME
  /// pixels-per-unit — sizing each half to its own extent instead
  /// would draw a -10 as tall as a +100.
  Widget _buildSigned(BuildContext context) {
    final fmt = format ?? (v) => v.toStringAsFixed(0);
    final down = negativeColor ?? barColor;

    var maxPos = 0.0;
    var maxNeg = 0.0; // magnitude, kept positive
    for (final b in bars) {
      if (b.value > maxPos) maxPos = b.value;
      if (-b.value > maxNeg) maxNeg = -b.value;
    }

    // Flex must be a positive integer, and a series that only ever
    // went one way should not be given an empty half to sit in.
    final span = maxPos + maxNeg;
    final posFlex = span <= 0 ? 1 : (maxPos / span * 1000).round().clamp(1, 999);
    final negFlex = 1000 - posFlex;

    final biggest = maxPos >= maxNeg ? maxPos : -maxNeg;

    return Semantics(
      label: 'Chart: ${bars.length} periods, '
          'highest ${fmt(maxPos)}, lowest ${fmt(-maxNeg)}',
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Expanded(
              flex: posFlex,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in bars)
                    Expanded(
                      child: _halfBar(
                        // Only the single most extreme value is
                        // labelled, and it may be a negative one.
                        label: b.value == biggest && span > 0 ? fmt(b.value) : null,
                        fraction: b.value > 0 && maxPos > 0 ? b.value / maxPos : 0,
                        color: barColor,
                        up: true,
                      ),
                    ),
                ],
              ),
            ),
            // The zero line. In signed mode this is what makes a
            // no-movement period readable — it needs no hairline bar
            // of its own, because the axis already sits where its
            // value is.
            Container(height: 1, color: Colors.grey.shade400),
            Expanded(
              flex: negFlex,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in bars)
                    Expanded(
                      child: _halfBar(
                        label: b.value == biggest && span > 0 ? fmt(b.value) : null,
                        fraction: b.value < 0 && maxNeg > 0 ? -b.value / maxNeg : 0,
                        color: down,
                        up: false,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _axisLabels(),
          ],
        ),
      ),
    );
  }

  Widget _halfBar({
    required String? label,
    required double fraction,
    required Color color,
    required bool up,
  }) {
    final bar = fraction <= 0
        ? const SizedBox.shrink()
        : FractionallySizedBox(
            heightFactor: fraction.clamp(0.02, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(up ? 3 : 0),
                  bottom: Radius.circular(up ? 0 : 3),
                ),
              ),
            ),
          );

    final text = label == null
        ? null
        : FittedBox(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: up ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: up
            ? [if (text != null) text, bar]
            : [bar, if (text != null) text],
      ),
    );
  }

  Widget _axisLabels() => Row(
        children: [
          for (final b in bars)
            Expanded(
              child: FittedBox(
                child: Text(
                  b.label,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                ),
              ),
            ),
        ],
      );
}
