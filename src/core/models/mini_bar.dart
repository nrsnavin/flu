// ══════════════════════════════════════════════════════════════
//  ONE BAR
//
//  Deliberately kept out of mini_bar_chart.dart, which imports
//  material and so drags dart:ui behind it. Deciding WHAT the bars
//  are — filling an absent day with a zero, summing days into months
//  — is arithmetic, and arithmetic that can only run inside a Flutter
//  engine is arithmetic nobody will test. Kept here, the series
//  builders and their tests run on the plain Dart VM.
//
//  mini_bar_chart.dart re-exports this, so anything that draws a
//  chart keeps importing one file.
// ══════════════════════════════════════════════════════════════

class MiniBar {
  /// Short label under the bar, e.g. "Aug". Empty means the bar is
  /// drawn but not named — see the axis thinning in
  /// features/reports/report_series.dart.
  final String label;
  final double value;

  const MiniBar({required this.label, required this.value});
}
