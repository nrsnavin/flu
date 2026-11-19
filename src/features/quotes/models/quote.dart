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

/// Quotations to a page: the server's own default for GET /quote/list,
/// which this app does not override.
const kQuotePageSize = 20;

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
  bool get isExpired => lapsedOn(DateTime.now());

  /// Has the price run out, as of [now] on this phone's clock?
  ///
  /// By the DAY. "Valid until 30 November" is good THROUGH 30
  /// November. The server keeps that date as the day itself (its UTC
  /// midnight), which as a moment is 05:30 that morning in India —
  /// compared with the clock, a quote read "Lapsed" for the whole of
  /// its last day, in front of the customer it was still good for.
  ///
  /// And only of a price still on offer. One the customer declined, or
  /// that was withdrawn, has nothing left to lapse. The server lists by
  /// the same rule (GET /quote/list?status=expired), so the Expired
  /// chip shows exactly the rows this marks.
  bool lapsedOn(DateTime now) {
    if (status == 'expired') return true;
    if (status != 'draft' && status != 'sent') return false;
    final till = validTill?.toUtc();
    if (till == null) return false;
    final lastDay = DateTime.utc(till.year, till.month, till.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return lastDay.isBefore(today);
  }

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

  factory QuotePage.fromJson(Map<String, dynamic> j) {
    final total = (j['total'] as num?)?.toInt() ?? 0;
    // The route sent no `pages` for a long time, and "none" was read
    // as one: the pager never appeared, and nothing past the first
    // twenty quotations could be reached from the phone. Worked out
    // from the total when a server does not say.
    final worked = total <= 0 ? 1 : (total + kQuotePageSize - 1) ~/ kQuotePageSize;
    return QuotePage(
      quotes: (j['quotes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Quote.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: total,
      page: (j['page'] as num?)?.toInt() ?? 1,
      pages: (j['pages'] as num?)?.toInt() ?? worked,
    );
  }
}
