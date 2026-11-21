// ══════════════════════════════════════════════════════════════
//  GST ON A PURCHASE ORDER
//
//  What the server says a PO comes to with its GST (the detail
//  route), and the same sum done here for the form's preview before
//  the PO exists. Mirrors prod/services/purchaseTax.js:
//
//    • a line's rate is its own, else its material's, else the
//      default rate in Settings → Invoice;
//    • the supplier is the seller and we are the buyer, so the
//      supplier's state against ours decides CGST + SGST or IGST;
//    • a composition dealer or an unregistered supplier charges none.
// ══════════════════════════════════════════════════════════════

/// To the paisa, a half-paisa going up — the server's rounding
/// (utils/money.js). A value a hair under a half-paisa by the error one
/// multiplication leaves is taken as the half-paisa.
double r2(num n) {
  final v = n.toDouble();
  final y = v.abs() * 100;
  final paise = (y + (y * 2e-15 > 1e-9 ? y * 2e-15 : 1e-9)).round();
  return (v < 0 ? -paise : paise) / 100;
}

final RegExp _gstin = RegExp(r'^(\d{2})[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

/// "33AAECB1234F1Z5" → "33"; anything that is not a GSTIN → "".
String stateCodeFromGstin(String? gstin) {
  final m = _gstin.firstMatch((gstin ?? '').trim().toUpperCase());
  return m?.group(1) ?? '';
}

/// A rate as typed: null when blank (not stated), else the number.
double? rateOf(String? text) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

final RegExp hsnPattern = RegExp(r'^\d{4,8}$');

/// Why a supplier charges no GST, or "" when it does.
String noGstReason(String? name, String? registration) {
  final who = (name == null || name.isEmpty) ? 'This supplier' : name;
  if (registration == 'composition') return '$who is a composition dealer, so no GST is charged';
  if (registration == 'unregistered') return '$who is not registered for GST, so no GST is charged';
  return '';
}

/// "5%", "2.5%".
String pct(double n) {
  final s = n.toStringAsFixed(2);
  return '${s.replaceFirst(RegExp(r'\.?0+$'), '')}%';
}

class PoTaxTotals {
  final double taxable, cgst, sgst, igst, tax, roundOff, grand;
  const PoTaxTotals({
    this.taxable = 0, this.cgst = 0, this.sgst = 0, this.igst = 0,
    this.tax = 0, this.roundOff = 0, this.grand = 0,
  });

  factory PoTaxTotals.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PoTaxTotals(
      taxable: n('taxable'), cgst: n('cgst'), sgst: n('sgst'), igst: n('igst'),
      tax: n('tax'), roundOff: n('roundOff'), grand: n('grand'),
    );
  }
}

class PoTax {
  /// "intra" (CGST + SGST) or "inter" (IGST).
  final String supplyType;
  /// Why no GST is charged; "" when it is.
  final String noGst;
  final PoTaxTotals totals;
  /// The one rate every taxed line carries, or null when they differ —
  /// printed in the labels when there is one.
  final double? rate;

  const PoTax({required this.supplyType, this.noGst = '', required this.totals, this.rate});

  bool get isInter => supplyType == 'inter';

  factory PoTax.fromJson(Map<String, dynamic> j, {double? rate}) => PoTax(
    supplyType: j['supplyType']?.toString() ?? 'intra',
    noGst: j['noGst']?.toString() ?? '',
    totals: PoTaxTotals.fromJson((j['totals'] as Map?)?.cast<String, dynamic>() ?? const {}),
    rate: rate,
  );

  /// The label/amount rows under the taxable value.
  List<MapEntry<String, double>> get taxRows {
    if (noGst.isNotEmpty) return const [];
    if (isInter) return [MapEntry('IGST${rate != null ? ' @ ${pct(rate!)}' : ''}', totals.igst)];
    final half = rate != null ? ' @ ${pct(rate! / 2)}' : '';
    return [MapEntry('CGST$half', totals.cgst), MapEntry('SGST$half', totals.sgst)];
  }
}

class PoTaxLine {
  final double quantity, rate, gstPercent;
  const PoTaxLine({required this.quantity, required this.rate, required this.gstPercent});
}

/// Price the lines as the server will: per line to the paisa, the grand
/// total to the rupee with the round-off shown.
PoTax pricePoLines(List<PoTaxLine> lines, {String? supplierGstin, String ourState = '', String noGst = ''}) {
  final seller = stateCodeFromGstin(supplierGstin);
  final buyer = ourState.isNotEmpty ? ourState : seller;
  final inter = seller.isNotEmpty && buyer.isNotEmpty && seller != buyer;
  double taxable = 0, cgst = 0, sgst = 0, igst = 0;
  final rates = <double>{};
  for (final l in lines) {
    final t = r2(l.quantity * l.rate);
    final tax = noGst.isNotEmpty ? 0.0 : r2(t * l.gstPercent / 100);
    final half = r2(tax / 2);
    taxable += t;
    if (inter) {
      igst += tax;
    } else {
      cgst += half;
      sgst += r2(tax - half);
    }
    if (t > 0) rates.add(l.gstPercent);
  }
  taxable = r2(taxable); cgst = r2(cgst); sgst = r2(sgst); igst = r2(igst);
  final tax = r2(cgst + sgst + igst);
  final before = r2(taxable + tax);
  final grand = before.roundToDouble();
  return PoTax(
    supplyType: inter ? 'inter' : 'intra',
    noGst: noGst,
    totals: PoTaxTotals(taxable: taxable, cgst: cgst, sgst: sgst, igst: igst, tax: tax, roundOff: r2(grand - before), grand: grand),
    rate: rates.length == 1 ? rates.first : null,
  );
}
