import 'dart:math' as math;

import 'models/accounts_models.dart';

// ══════════════════════════════════════════════════════════════
//  WHAT A RECEIPT OR PAYMENT SETTLES, BEFORE THE SERVER DOES IT
//
//  The money goes to the oldest open documents first — the way the web
//  form fills it and the way a customer means it — skipping any the
//  person unticked. Whatever is left over stays with the party on
//  account (an advance). The server checks every amount again.
// ══════════════════════════════════════════════════════════════

double r2(double n) => (n * 100).roundToDouble() / 100;

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

/// Each open document, oldest first, with what [amount] settles on it.
/// Unticked documents ([skipped] ids) take nothing.
List<({OpenDoc doc, double amount})> allocateOldestFirst(
  double amount,
  List<OpenDoc> docs, {
  Set<String> skipped = const {},
}) {
  var left = r2(math.max(0, amount));
  return [
    for (final d in oldestFirst(docs))
      () {
        if (skipped.contains(d.id) || left <= 0) return (doc: d, amount: 0.0);
        final take = r2(math.min(left, d.outstanding));
        left = r2(left - take);
        return (doc: d, amount: take);
      }(),
  ];
}

/// What the ticked documents add up to: the amount that settles them all.
double tickedTotal(List<OpenDoc> docs, Set<String> skipped) =>
    r2(docs.where((d) => !skipped.contains(d.id)).fold(0.0, (s, d) => s + d.outstanding));

/// What the allocations settle, and what is left on account.
({double settled, double onAccount, int docs}) settlement(
    double amount, List<({OpenDoc doc, double amount})> allocations) {
  final settled = r2(allocations.fold(0.0, (s, a) => s + a.amount));
  return (
    settled: settled,
    onAccount: r2(math.max(0, amount - settled)),
    docs: allocations.where((a) => a.amount > 0).length,
  );
}

/// The bills a phone payment cannot settle: those that carry TDS, which
/// the web works out and deducts when they are paid.
List<OpenDoc> tdsBlockers(List<({OpenDoc doc, double amount})> allocations) =>
    [for (final a in allocations) if (a.amount > 0 && a.doc.tdsSection.isNotEmpty) a.doc];
