// ══════════════════════════════════════════════════════════════
//  A PRICE QUOTED TO A CUSTOMER
//
//  Mirrors models/Quote.js. The costing behind each rate is stored
//  alongside it on the server rather than recomputed, so a quote can
//  still answer "why were they charged that" after the rate card has
//  moved on. This carries the stored figures and never recomputes
//  them for the same reason.
//
//  ── Totals are READ, not summed ────────────────────────────────
//  The first version of this file computed the quote total by adding
//  up valueInclTax across the lines. That was wrong twice: a line
//  quoted as a rate only (quantityMetres = 0) contributes nothing to
//  the sum but is still a real part of the quotation, and GST is
//  applied at the QUOTE level from gstPercent, not line by line. So a
//  quote with one priced line and two rate-only lines showed a total
//  that matched nothing on the PDF the customer was holding.
//
//  subTotal / gstAmount / grandTotal now come from the server, which
//  is the same arithmetic the PDF and the web page print.
// ══════════════════════════════════════════════════════════════

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// One material in a line's frozen costing.
class QuoteMaterial {
  final String label;
  final double weightGrams;
  final double ratePerKg;
  final double cost;

  const QuoteMaterial({
    required this.label,
    required this.weightGrams,
    required this.ratePerKg,
    required this.cost,
  });

  factory QuoteMaterial.fromJson(Map<String, dynamic> j) => QuoteMaterial(
        label: j['label']?.toString() ?? '—',
        weightGrams: _num(j['weightGrams']),
        ratePerKg: _num(j['ratePerKg']),
        cost: _num(j['cost']),
      );
}

class QuoteLine {
  final String productName;
  final String productSpec;
  final List<QuoteMaterial> materials;

  final double totalWeightGrams;
  final double materialCost;
  final double conversionCost;
  final double totalCost;
  final double marginPercent;
  final double marginAmount;

  final double rateBeforeTax;
  final double rateInclTax;
  final double quantityMetres;
  final double valueBeforeTax;
  final double valueInclTax;

  const QuoteLine({
    required this.productName,
    required this.productSpec,
    required this.materials,
    required this.totalWeightGrams,
    required this.materialCost,
    required this.conversionCost,
    required this.totalCost,
    required this.marginPercent,
    required this.marginAmount,
    required this.rateBeforeTax,
    required this.rateInclTax,
    required this.quantityMetres,
    required this.valueBeforeTax,
    required this.valueInclTax,
  });

  /// A line with no quantity is a rate card entry, not a sale. The
  /// screen has to say so rather than printing ₹0, which reads as
  /// "free".
  bool get isRateOnly => quantityMetres <= 0;

  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
        productName: j['productName']?.toString() ?? '—',
        productSpec: j['productSpec']?.toString() ?? '',
        materials: (j['materials'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => QuoteMaterial.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        totalWeightGrams: _num(j['totalWeightGrams']),
        materialCost: _num(j['materialCost']),
        conversionCost: _num(j['conversionCost']),
        totalCost: _num(j['totalCost']),
        marginPercent: _num(j['marginPercent']),
        marginAmount: _num(j['marginAmount']),
        rateBeforeTax: _num(j['rateBeforeTax']),
        rateInclTax: _num(j['rateInclTax']),
        quantityMetres: _num(j['quantityMetres']),
        valueBeforeTax: _num(j['valueBeforeTax']),
        valueInclTax: _num(j['valueInclTax']),
      );
}

/// draft · sent · accepted · declined · expired · cancelled
class Quote {
  final String id;
  final String quoteNo;
  final DateTime? date;
  final DateTime? validTill;
  final String customerName;
  final String customerRef;
  final String customerGstin;
  final String status;
  final String remarks;

  final double gstPercent;
  final double subTotal;
  final double gstAmount;
  final double grandTotal;
  final double totalQuantityMetres;

  final List<QuoteLine> lines;

  const Quote({
    required this.id,
    required this.quoteNo,
    required this.date,
    required this.validTill,
    required this.customerName,
    required this.customerRef,
    required this.customerGstin,
    required this.status,
    required this.remarks,
    required this.gstPercent,
    required this.subTotal,
    required this.gstAmount,
    required this.grandTotal,
    required this.totalQuantityMetres,
    required this.lines,
  });

  /// Expiry is a fact about the quote, not a status somebody sets, so
  /// it is derived rather than trusted from a field that would need a
  /// nightly job to stay true.
  ///
  /// An ACCEPTED quote is never shown as expired: the customer said
  /// yes inside the window, and the price is owed regardless of what
  /// the calendar has done since.
  bool get isExpired =>
      status != 'accepted' &&
      validTill != null &&
      validTill!.isBefore(DateTime.now());

  /// Nothing more can be decided on it.
  bool get isSettled =>
      status == 'accepted' || status == 'cancelled' || status == 'declined';

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        id: j['_id']?.toString() ?? '',
        quoteNo: j['quoteNo']?.toString() ?? '—',
        date: DateTime.tryParse(j['date']?.toString() ?? ''),
        validTill: DateTime.tryParse(j['validTill']?.toString() ?? ''),
        customerName: j['customerName']?.toString() ?? '—',
        customerRef: j['customerRef']?.toString() ?? '',
        customerGstin: j['customerGstin']?.toString() ?? '',
        status: j['status']?.toString() ?? 'draft',
        remarks: j['remarks']?.toString() ?? '',
        gstPercent: _num(j['gstPercent']),
        subTotal: _num(j['subTotal']),
        gstAmount: _num(j['gstAmount']),
        grandTotal: _num(j['grandTotal']),
        totalQuantityMetres: _num(j['totalQuantityMetres']),
        lines: (j['lines'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => QuoteLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class QuotePage {
  final List<Quote> quotes;
  final int total;
  final int page;
  final int pages;

  const QuotePage({
    required this.quotes,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory QuotePage.fromJson(Map<String, dynamic> j) => QuotePage(
        quotes: (j['quotes'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Quote.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pages: (j['pages'] as num?)?.toInt() ?? 1,
      );
}
