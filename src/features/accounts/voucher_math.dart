import 'dart:math' as math;

import 'models/accounts_models.dart';

// ══════════════════════════════════════════════════════════════
//  WHAT A RECEIPT OR PAYMENT SETTLES, BEFORE THE SERVER DOES IT
//
//  The money goes to the oldest open documents first — the way the web
//  form fills it and the way a customer means it — skipping any the
//  person unticked. Whatever is left over stays with the party on
//  account (an advance). The server checks every amount again.
//
//  On a payment, a supplier's bill that carries TDS is settled for
//  less cash than it is for: the tax, worked on the bill's value net of
//  GST, is kept back and deposited. This is the server's own sum
//  (services/allocation.js: taxOn and propose), so what is shown here
//  is what the voucher will say. The phone used to turn such bills away
//  to the web.
// ══════════════════════════════════════════════════════════════

/// To paise, a half-paisa going up (away from zero): the server's sum
/// (utils/money.js toPaise). `(n * 100).roundToDouble() / 100` is not
/// that sum — 1.005 is held as 1.00499999999999989…, times 100 is
/// 100.49999999999999, and that came to 1.00. A value a hair under a
/// half-paisa, by the error one multiplication leaves, is that
/// half-paisa: it is nudged up by a billionth of a paisa before
/// rounding. A value honestly below the half (1.0049) still rounds down.
double r2(double n) {
  if (n.isNaN || n.isInfinite) return 0;
  final y = n.abs() * 100;
  final paise = (y + math.max(1e-9, y * 2e-15)).roundToDouble();
  return (n < 0 ? -paise : paise) / 100;
}

/// One open document with what a voucher settles on it: [amount] comes
/// off what it owes, of which [tds] is tax kept back (a supplier's bill
/// that carries TDS) and [cash] is the money that moves.
typedef Allocation = ({OpenDoc doc, double amount, double tds, double cash});

/// Oldest first: by document date, then due date, then number.
List<OpenDoc> oldestFirst(List<OpenDoc> docs) {
  final far = DateTime(9999);
  return [...docs]..sort((a, b) {
      final d = (a.date ?? far).compareTo(b.date ?? far);
      if (d != 0) return d;
      final due = (a.dueDate ?? far).compareTo(b.dueDate ?? far);
      return due != 0 ? due : a.docNo.compareTo(b.docNo);
    });
}

/// The rate TDS comes off [d] at when it is paid: a supplier's bill's
/// own rate, and nothing on a receipt or any other document.
double _rate(OpenDoc d, bool payment) => payment && d.docType == 'SupplierBill' && d.tdsRate > 0 ? d.tdsRate : 0;

/// [gross] settled on [d]: the TDS on it (on its share that is value
/// net of GST), and the cash that is left to pay.
Allocation settle(OpenDoc d, double gross, {bool payment = false}) {
  final rate = _rate(d, payment);
  final tds = rate > 0 ? r2(r2(gross * d.taxableRatio) * rate / 100) : 0.0;
  return (doc: d, amount: gross, tds: tds, cash: r2(gross - tds));
}

/// Each open document, oldest first, with what [amount] of money
/// settles on it. Unticked documents ([skipped] ids) take nothing. On a
/// [payment], a bill carrying TDS takes less money than it settles.
List<Allocation> allocateOldestFirst(
  double amount,
  List<OpenDoc> docs, {
  Set<String> skipped = const {},
  bool payment = false,
}) {
  var left = r2(math.max(0, amount));
  final out = <Allocation>[];
  for (final d in oldestFirst(docs)) {
    if (skipped.contains(d.id) || left <= 0.005) {
      out.add((doc: d, amount: 0.0, tds: 0.0, cash: 0.0));
      continue;
    }
    final full = settle(d, d.outstanding, payment: payment);
    if (full.cash <= left + 0.005) {
      out.add(full);
      left = r2(left - full.cash);
      continue;
    }
    // In part: the most of it whose cash, after the TDS on that part,
    // the money left can pay.
    final f = _rate(d, payment) * d.taxableRatio / 100;
    var gross = f >= 1 ? d.outstanding : math.min(d.outstanding, r2(left / (1 - f)));
    var part = settle(d, gross, payment: payment);
    while (part.cash > left + 0.005 && gross > 0.01) {
      gross = r2(gross - 0.01);
      part = settle(d, gross, payment: payment);
    }
    if (gross > 0.005) {
      out.add(part);
      left = r2(left - part.cash);
    } else {
      out.add((doc: d, amount: 0.0, tds: 0.0, cash: 0.0));
    }
  }
  return out;
}

/// The money that settles every ticked document: what they owe, less
/// the TDS kept back on a payment.
double tickedTotal(List<OpenDoc> docs, Set<String> skipped, {bool payment = false}) => r2(docs
    .where((d) => !skipped.contains(d.id))
    .fold(0.0, (s, d) => s + settle(d, d.outstanding, payment: payment).cash));

/// What the allocations settle, the TDS kept back on them, and what of
/// the money is left on account.
({double settled, double tds, double onAccount, int docs}) settlement(double amount, List<Allocation> allocations) {
  final settled = r2(allocations.fold(0.0, (s, a) => s + a.amount));
  final cash = r2(allocations.fold(0.0, (s, a) => s + a.cash));
  return (
    settled: settled,
    tds: r2(allocations.fold(0.0, (s, a) => s + a.tds)),
    onAccount: r2(math.max(0, amount - cash)),
    docs: allocations.where((a) => a.amount > 0).length,
  );
}
