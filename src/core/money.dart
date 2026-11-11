import 'package:intl/intl.dart';

// Rupees and quantities the way the web prints them (en-IN grouping:
// 1,23,456.00), for every money screen on the phone.

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _qty = NumberFormat('#,##,##0.###', 'en_IN');

/// ₹1,23,456.00
String inr(double v) => _inr.format(v);

/// ₹1,23,456 — for headline figures, where paise are noise.
String inr0(double v) => _inr0.format(v);

/// 1,234.5
String qty(double v) => _qty.format(v);
