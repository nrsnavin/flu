// ══════════════════════════════════════════════════════════════
//  A PRICE QUOTED TO A CUSTOMER
//
//  Mirrors models/Quote.js. The costing behind each rate is stored
//  alongside it on the server rather than recomputed, so a quote can
//  still answer "why were they charged that" after the rate card has
//  moved on. This carries the stored figures and never recomputes
//  them for the same reason.
// ══════════════════════════════════════════════════════════════

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

class QuoteLine {
  final String productName;
  final String productSpec;
  final double quantityMetres;
  final double rateBeforeTax;
  final double rateInclTax;
  final double valueInclTax;
  final double marginPercent;

  const QuoteLine({
    required this.productName,
    required this.productSpec,
    required this.quantityMetres,
    required this.rateBeforeTax,
    required this.rateInclTax,
    required this.valueInclTax,
    required this.marginPercent,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
        productName: j['productName']?.toString() ?? '—',
        productSpec: j['productSpec']?.toString() ?? '',
        quantityMetres: _num(j['quantityMetres']),
        rateBeforeTax: _num(j['rateBeforeTax']),
        rateInclTax: _num(j['rateInclTax']),
        valueInclTax: _num(j['valueInclTax']),
        marginPercent: _num(j['marginPercent']),
      );
}

class Quote {
  final String id;
  final String quoteNo;
  final DateTime? date;
  final DateTime? validTill;
  final String customerName;
  final String status;
  final List<QuoteLine> lines;

  const Quote({
    required this.id,
    required this.quoteNo,
    required this.date,
    required this.validTill,
    required this.customerName,
    required this.status,
    required this.lines,
  });

  /// Expiry is a fact about the quote, not a status somebody sets, so
  /// it is derived rather than trusted from a field that would need a
  /// nightly job to stay true.
  bool get isExpired =>
      validTill != null && validTill!.isBefore(DateTime.now());

  double get total =>
      lines.fold<double>(0, (s, l) => s + l.valueInclTax);

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        id: j['_id']?.toString() ?? '',
        quoteNo: j['quoteNo']?.toString() ?? '—',
        date: DateTime.tryParse(j['date']?.toString() ?? ''),
        validTill: DateTime.tryParse(j['validTill']?.toString() ?? ''),
        customerName: j['customerName']?.toString() ?? '—',
        status: j['status']?.toString() ?? 'draft',
        lines: (j['lines'] as List? ?? const [])
            .map((e) => QuoteLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class QuotePage {
  final List<Quote> quotes;
  final int total;
  final int page;

  const QuotePage({
    required this.quotes,
    required this.total,
    required this.page,
  });

  factory QuotePage.fromJson(Map<String, dynamic> j) => QuotePage(
        quotes: (j['quotes'] as List? ?? const [])
            .map((e) => Quote.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
      );
}
