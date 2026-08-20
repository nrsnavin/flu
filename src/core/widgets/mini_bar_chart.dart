import 'package:flutter/material.dart';

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
//  ── Empty months are drawn ─────────────────────────────────────
//  The API deliberately returns every month in the window including
//  the empty ones — a chart drawn only from months with output closes
//  the gaps and makes three idle months look like three busy ones.
//  This never filters them out.
//
//  ── It says the numbers too ────────────────────────────────────
//  A bar chart on a 6-inch screen is a shape, not a reading. The
//  highest value is labelled and the axis carries the range, so the
//  chart is a summary and the figures underneath stay authoritative.
// ══════════════════════════════════════════════════════════════

class MiniBar {
  /// Short label under the bar, e.g. "Aug".
  final String label;
  final double value;

  const MiniBar({required this.label, required this.value});
}

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.bars,
    required this.barColor,
    this.height = 120,
    this.format,
    this.emptyLabel = 'Nothing in this period.',
  });

  final List<MiniBar> bars;
  final Color barColor;
  final double height;

  /// How a value reads to a person — rupees, metres, a count.
  final String Function(double)? format;
  final String emptyLabel;

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
            Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
