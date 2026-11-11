// Trailing-zero stripper for kg weights. Kept in its own file so a stray
// escape sequence inside a raw-string RegExp can't break compilation of
// the much larger covering_detail.dart screen.
//
// Examples:
//   _wt(1.0)    → '1'
//   _wt(1.234)  → '1.234'
//   _wt(1.2300) → '1.23'
String wt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(3);
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}
