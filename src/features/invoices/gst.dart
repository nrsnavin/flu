import 'package:intl/intl.dart';

import 'models/invoice_models.dart';

// ══════════════════════════════════════════════════════════════
//  THE INVOICE ARITHMETIC, BEFORE THE SERVER DOES IT FOR REAL
//
//  Mirrors prod_web/src/features/invoices/gst.ts, which mirrors the
//  server's services/gst.js, so the totals the raise form shows are
//  the totals the invoice comes out with. The server prices it again
//  on raising; this is only ever a preview.
// ══════════════════════════════════════════════════════════════

double round2(double n) => (n * 100).roundToDouble() / 100;

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _qty = NumberFormat('#,##,##0.###', 'en_IN');

/// ₹1,23,456.00
String inr(double v) => _inr.format(v);

/// ₹1,23,456 — for headline figures, where paise are noise.
String inr0(double v) => _inr0.format(v);

/// 1,234.5
String qty(double v) => _qty.format(v);

/// What has been typed over the line the server proposed.
class LineOverride {
  LineOverride({this.rate, this.hsn, this.gstPercent});

  double? rate;
  String? hsn;
  double? gstPercent;

  bool get isEmpty => rate == null && hsn == null && gstPercent == null;

  /// The body the server takes (InvoiceLineOverride on the web).
  Map<String, dynamic> toJson(String elastic) => {
        'elastic': elastic,
        if (rate != null) 'rate': rate,
        if (hsn != null) 'hsn': hsn,
        if (gstPercent != null) 'gstPercent': gstPercent,
      };
}

/// The lines an invoice would carry for the ticked challans: their
/// items merged per elastic, at the rate, HSN and GST % the server
/// proposed for it, or what was typed over them.
List<InvoiceDraftLine> draftLines(
  List<InvoiceDcOption> dcs,
  Set<String> selected,
  List<InvoiceDraftLine> proposed,
  Map<String, LineOverride> overrides, {
  required String defaultHsn,
  required double defaultGstPercent,
}) {
  final byElastic = {for (final l in proposed) l.elastic: l};
  final merged = <String, InvoiceDraftLine>{};
  for (final dc in dcs) {
    if (!selected.contains(dc.id)) continue;
    for (final item in dc.items) {
      if (item.elastic.isEmpty) continue;
      final base = byElastic[item.elastic];
      final row = merged.putIfAbsent(
        item.elastic,
        () => InvoiceDraftLine(
          elastic: item.elastic,
          name: (base?.name.isNotEmpty ?? false)
              ? base!.name
              : (item.elasticName.isNotEmpty ? item.elasticName : 'Elastic'),
          unit: (base?.unit.isNotEmpty ?? false)
              ? base!.unit
              : (item.unit.isNotEmpty ? item.unit : 'm'),
          rate: base?.rate ?? 0,
          hsn: base?.hsn ?? defaultHsn,
          gstPercent: base?.gstPercent ?? defaultGstPercent,
          rateSource: base?.rateSource ?? 'none',
        ),
      );
      row.quantity = (((row.quantity + item.quantity) * 1000).roundToDouble()) / 1000;
      if (!row.dcNumbers.contains(dc.dcNumber)) row.dcNumbers.add(dc.dcNumber);
    }
  }
  for (final row in merged.values) {
    final o = overrides[row.elastic];
    if (o == null) continue;
    if (o.rate != null) {
      row.rate = o.rate!;
      row.rateSource = 'entered';
    }
    if (o.hsn != null) row.hsn = o.hsn!;
    if (o.gstPercent != null) row.gstPercent = o.gstPercent!;
  }
  return merged.values.toList();
}

class PricedLine {
  const PricedLine(this.line, {required this.taxable, required this.cgst, required this.sgst, required this.igst, required this.amount});

  final InvoiceDraftLine line;
  final double taxable, cgst, sgst, igst, amount;
}

/// Price the lines and split the tax the way the server will:
/// CGST + SGST in the seller's state, IGST outside it.
({List<PricedLine> lines, InvoiceTotals totals}) priceLines(
    List<InvoiceDraftLine> lines, String supplyType) {
  final inter = supplyType != 'intra';
  final priced = [
    for (final l in lines)
      () {
        final taxable = round2(l.quantity * l.rate);
        final tax = round2(taxable * l.gstPercent / 100);
        final half = round2(tax / 2);
        return PricedLine(
          l,
          taxable: taxable,
          cgst: inter ? 0 : half,
          sgst: inter ? 0 : round2(tax - half),
          igst: inter ? tax : 0,
          amount: round2(taxable + tax),
        );
      }(),
  ];
  double sum(double Function(PricedLine) f) => round2(priced.fold(0.0, (a, l) => a + f(l)));
  final taxable = sum((l) => l.taxable);
  final cgst = sum((l) => l.cgst);
  final sgst = sum((l) => l.sgst);
  final igst = sum((l) => l.igst);
  final tax = round2(cgst + sgst + igst);
  final beforeRound = round2(taxable + tax);
  final grand = beforeRound.roundToDouble();
  return (
    lines: priced,
    totals: InvoiceTotals(
      taxable: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      tax: tax,
      roundOff: round2(grand - beforeRound),
      grand: grand,
    ),
  );
}
