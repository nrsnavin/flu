// ══════════════════════════════════════════════════════════════
//  PHYSICAL INVENTORY — THE SHEET
//
//  Mirrors the shape the API returns from api/stockCount.js. Every
//  field here exists on the wire; nothing is computed twice, because
//  the variance arithmetic is the whole point of the feature and two
//  implementations of it would eventually disagree.
//
//  ── Why counted is nullable and variance is too ────────────────
//  "Counted zero" and "not counted yet" are different facts and the
//  difference is expensive: posting applies every non-zero variance as
//  a stock adjustment, and an uncounted line treated as a zero would
//  write the entire stock of that material off. So the API sends null
//  for uncounted, and this keeps it null the whole way to the screen
//  rather than defaulting it to 0 for convenience.
// ══════════════════════════════════════════════════════════════

double? _numOrNull(dynamic v) => v == null ? null : (v as num).toDouble();
double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

class StockCountLine {
  final String id;
  final String rawMaterial;
  final String name;
  final String category;

  /// What the system believed when the sheet was frozen.
  final double systemQty;
  final double unitCost;

  /// What somebody actually found. Null means nobody has looked yet.
  final double? countedQty;

  /// counted − system. Null while uncounted, for the same reason.
  final double? variance;
  final double? varianceValue;

  final String reason;

  /// The API decides this — a variance big enough to need explaining.
  final bool needsReason;

  final DateTime? countedAt;

  /// Set only once the sheet is posted.
  final double? stockAtPost;
  final double? appliedDelta;

  /// How much of this line's gap another count already corrected. The
  /// server subtracts it so two sheets over one rack cannot both post
  /// the same −10 and destroy real stock.
  final double correctedElsewhere;

  /// Null until posted: before that, whether stock moved is not part of
  /// what the sheet claims.
  final bool? movedSinceFreeze;

  const StockCountLine({
    required this.id,
    required this.rawMaterial,
    required this.name,
    required this.category,
    required this.systemQty,
    required this.unitCost,
    required this.countedQty,
    required this.variance,
    required this.varianceValue,
    required this.reason,
    required this.needsReason,
    required this.countedAt,
    required this.stockAtPost,
    required this.appliedDelta,
    required this.correctedElsewhere,
    required this.movedSinceFreeze,
  });

  bool get isCounted => variance != null;
  bool get isVaried => variance != null && variance != 0;

  factory StockCountLine.fromJson(Map<String, dynamic> j) => StockCountLine(
        id: j['_id']?.toString() ?? '',
        rawMaterial: j['rawMaterial']?.toString() ?? '',
        name: j['name']?.toString() ?? '—',
        category: j['category']?.toString() ?? '',
        systemQty: _num(j['systemQty']),
        unitCost: _num(j['unitCost']),
        countedQty: _numOrNull(j['countedQty']),
        variance: _numOrNull(j['variance']),
        varianceValue: _numOrNull(j['varianceValue']),
        reason: j['reason']?.toString() ?? '',
        needsReason: j['needsReason'] == true,
        countedAt: DateTime.tryParse(j['countedAt']?.toString() ?? ''),
        stockAtPost: _numOrNull(j['stockAtPost']),
        appliedDelta: _numOrNull(j['appliedDelta']),
        correctedElsewhere: _num(j['correctedElsewhere']),
        movedSinceFreeze: j['movedSinceFreeze'] as bool?,
      );

  StockCountLine copyWith({double? countedQty, String? reason}) => StockCountLine(
        id: id,
        rawMaterial: rawMaterial,
        name: name,
        category: category,
        systemQty: systemQty,
        unitCost: unitCost,
        countedQty: countedQty ?? this.countedQty,
        variance: countedQty == null ? variance : countedQty - systemQty,
        varianceValue:
            countedQty == null ? varianceValue : (countedQty - systemQty) * unitCost,
        reason: reason ?? this.reason,
        needsReason: needsReason,
        countedAt: countedAt,
        stockAtPost: stockAtPost,
        appliedDelta: appliedDelta,
        correctedElsewhere: correctedElsewhere,
        movedSinceFreeze: movedSinceFreeze,
      );
}

class CountTotals {
  final int lines;
  final int counted;
  final int uncounted;
  final int varied;
  final int needingReason;
  final double gainQuantity;
  final double lossQuantity;
  final double gainValue;
  final double lossValue;
  final double netValue;

  const CountTotals({
    required this.lines,
    required this.counted,
    required this.uncounted,
    required this.varied,
    required this.needingReason,
    required this.gainQuantity,
    required this.lossQuantity,
    required this.gainValue,
    required this.lossValue,
    required this.netValue,
  });

  factory CountTotals.fromJson(Map<String, dynamic> j) => CountTotals(
        lines: (j['lines'] as num?)?.toInt() ?? 0,
        counted: (j['counted'] as num?)?.toInt() ?? 0,
        uncounted: (j['uncounted'] as num?)?.toInt() ?? 0,
        varied: (j['varied'] as num?)?.toInt() ?? 0,
        needingReason: (j['needingReason'] as num?)?.toInt() ?? 0,
        gainQuantity: _num(j['gainQuantity']),
        lossQuantity: _num(j['lossQuantity']),
        gainValue: _num(j['gainValue']),
        lossValue: _num(j['lossValue']),
        netValue: _num(j['netValue']),
      );

  static const empty = CountTotals(
    lines: 0, counted: 0, uncounted: 0, varied: 0, needingReason: 0,
    gainQuantity: 0, lossQuantity: 0, gainValue: 0, lossValue: 0, netValue: 0,
  );
}

class StockCount {
  final String id;
  final int? countNo;
  final String label;

  /// open | posted | cancelled
  final String status;
  final DateTime? frozenAt;
  final DateTime? postedAt;
  final DateTime? cancelledAt;
  final String cancelledReason;
  final List<StockCountLine> lines;
  final CountTotals totals;

  const StockCount({
    required this.id,
    required this.countNo,
    required this.label,
    required this.status,
    required this.frozenAt,
    required this.postedAt,
    required this.cancelledAt,
    required this.cancelledReason,
    required this.lines,
    required this.totals,
  });

  bool get isOpen => status == 'open';
  bool get isPosted => status == 'posted';

  String get title =>
      label.isNotEmpty ? label : (countNo == null ? 'Count' : 'Count #$countNo');

  factory StockCount.fromJson(Map<String, dynamic> j) => StockCount(
        id: j['_id']?.toString() ?? '',
        countNo: (j['countNo'] as num?)?.toInt(),
        label: j['label']?.toString() ?? '',
        status: j['status']?.toString() ?? 'open',
        frozenAt: DateTime.tryParse(j['frozenAt']?.toString() ?? ''),
        postedAt: DateTime.tryParse(j['postedAt']?.toString() ?? ''),
        cancelledAt: DateTime.tryParse(j['cancelledAt']?.toString() ?? ''),
        cancelledReason: j['cancelledReason']?.toString() ?? '',
        lines: (j['lines'] as List? ?? const [])
            .map((e) => StockCountLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        totals: j['totals'] == null
            ? CountTotals.empty
            : CountTotals.fromJson(Map<String, dynamic>.from(j['totals'] as Map)),
      );
}

class StockCountListPage {
  final List<StockCount> counts;
  final int page;
  final int pages;
  final int total;

  const StockCountListPage({
    required this.counts,
    required this.page,
    required this.pages,
    required this.total,
  });

  factory StockCountListPage.fromJson(Map<String, dynamic> j) => StockCountListPage(
        counts: (j['counts'] as List? ?? const [])
            .map((e) => StockCount.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        page: (j['page'] as num?)?.toInt() ?? 1,
        pages: (j['pages'] as num?)?.toInt() ?? 1,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}
