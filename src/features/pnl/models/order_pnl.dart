// ══════════════════════════════════════════════════════════════
//  ORDER P&L
//
//  Mirrors /api/v2/pnl (prod/api/pnl.js) and the service behind it,
//  services/orderPnl.js.
//
//  One rule runs through all of it: a figure that is not known is null,
//  never zero. A margin on zero revenue is not 0% and not -100%, it is
//  UNKNOWN — and an unpriced order showing "-100%" in a list is exactly
//  how a real loss gets lost among the noise. The server is careful
//  about this; these models keep the nulls rather than defaulting them
//  away, and the screens print "—".
// ══════════════════════════════════════════════════════════════

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Keeps null as null. Used for every figure the server may not know.
double? _dn(dynamic v) => (v as num?)?.toDouble();

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// The seven buckets an order's cost is split into, plus the total.
class PnlCosts {
  final double material;
  final double labour;
  final double jobWork;
  final double finishing;
  final double checking;
  final double packing;
  final double overhead;
  final double total;

  const PnlCosts({
    this.material = 0,
    this.labour = 0,
    this.jobWork = 0,
    this.finishing = 0,
    this.checking = 0,
    this.packing = 0,
    this.overhead = 0,
    this.total = 0,
  });

  factory PnlCosts.fromJson(Map<String, dynamic> j) => PnlCosts(
        material:  _d(j['material']),
        labour:    _d(j['labour']),
        jobWork:   _d(j['jobWork']),
        finishing: _d(j['finishing']),
        checking:  _d(j['checking']),
        packing:   _d(j['packing']),
        overhead:  _d(j['overhead']),
        total:     _d(j['total']),
      );

  /// In the order the P&L page reads them: what was bought, what was
  /// paid, what was paid out, then the four rate-card conversions.
  List<MapEntry<String, double>> get breakdown => [
        MapEntry('Material', material),
        MapEntry('Labour', labour),
        MapEntry('Job work', jobWork),
        MapEntry('Finishing', finishing),
        MapEntry('Checking', checking),
        MapEntry('Packing', packing),
        MapEntry('Overhead', overhead),
      ];
}

/// A conversion charge, and where its number came from: the rate card,
/// or a figure somebody entered for this job. Worth distinguishing —
/// one is an estimate applied to everything, the other is a measurement.
class PnlConversion {
  final double amount;

  /// rate · override
  final String basis;

  const PnlConversion({required this.amount, required this.basis});

  factory PnlConversion.fromJson(dynamic v) {
    if (v is Map) {
      return PnlConversion(
        amount: _d(v['amount']),
        basis: _s(v['basis']).isEmpty ? 'rate' : _s(v['basis']),
      );
    }
    return PnlConversion(amount: _d(v), basis: 'rate');
  }

  bool get isOverride => basis == 'override';
}

/// One line of what was sold.
class PnlRevenueLine {
  final String elasticId;
  final String name;
  final double quantity;
  final double rate;
  final double amount;

  const PnlRevenueLine({
    required this.elasticId,
    required this.name,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  factory PnlRevenueLine.fromJson(Map<String, dynamic> j) => PnlRevenueLine(
        elasticId: _s(j['elasticId']),
        name:      _s(j['name']),
        quantity:  _d(j['quantity']),
        rate:      _d(j['rate']),
        amount:    _d(j['amount']),
      );

  /// A line that asks for something but names no price. The single
  /// biggest way revenue gets understated, so it is flagged, not hidden.
  bool get unpriced => quantity > 0 && rate <= 0;
}

/// One raw-material issue charged against the order.
class PnlMaterialLine {
  final String name;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String type;

  const PnlMaterialLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.type,
  });

  factory PnlMaterialLine.fromJson(Map<String, dynamic> j) => PnlMaterialLine(
        name:      _s(j['name']),
        quantity:  _d(j['quantity']),
        unitPrice: _d(j['unitPrice']),
        amount:    _d(j['amount']),
        type:      _s(j['type']),
      );

  /// Yarn issued at a zero price — the single biggest way this P&L can
  /// flatter an order.
  bool get unpriced => quantity > 0 && unitPrice <= 0;
}

/// What one job cost. Note there is no material figure here: yarn is
/// drawn against the ORDER at approval, not the job, so there is no
/// honest per-job split of it. See the order total instead.
class PnlJobRow {
  final String id;
  final int? jobOrderNo;
  final String jobNo;
  final String status;

  /// in_house · outsource
  final String productionMode;
  final String outsourceVendor;

  final double producedMeters;

  final double labourAmount;
  final int labourShifts;
  final double labourHours;

  /// Shifts planned but never worked. They cost nothing and are said so
  /// rather than quietly excluded.
  final int openShifts;

  final double jobWork;
  final PnlConversion finishing;
  final PnlConversion checking;
  final PnlConversion packing;
  final PnlConversion overhead;

  final double total;
  final double? costPerMeter;

  const PnlJobRow({
    required this.id,
    required this.jobNo,
    required this.status,
    required this.productionMode,
    required this.outsourceVendor,
    required this.producedMeters,
    required this.labourAmount,
    required this.labourShifts,
    required this.labourHours,
    required this.openShifts,
    required this.jobWork,
    required this.finishing,
    required this.checking,
    required this.packing,
    required this.overhead,
    required this.total,
    this.jobOrderNo,
    this.costPerMeter,
  });

  factory PnlJobRow.fromJson(Map<String, dynamic> j) {
    final lab = j['labour'] is Map
        ? Map<String, dynamic>.from(j['labour'] as Map)
        : <String, dynamic>{};
    return PnlJobRow(
      id:              _s(j['id']),
      jobOrderNo:      (j['jobOrderNo'] as num?)?.toInt(),
      jobNo:           _s(j['jobNo']).isEmpty ? '—' : _s(j['jobNo']),
      status:          _s(j['status']),
      productionMode:  _s(j['productionMode']).isEmpty
          ? 'in_house'
          : _s(j['productionMode']),
      outsourceVendor: _s(j['outsourceVendor']),
      producedMeters:  _d(j['producedMeters']),
      labourAmount:    _d(lab['amount']),
      labourShifts:    _i(lab['shifts']),
      labourHours:     _d(lab['hours']),
      openShifts:      _i(lab['openShifts']),
      jobWork:         _d(j['jobWork']),
      finishing:       PnlConversion.fromJson(j['finishing']),
      checking:        PnlConversion.fromJson(j['checking']),
      packing:         PnlConversion.fromJson(j['packing']),
      overhead:        PnlConversion.fromJson(j['overhead']),
      total:           _d(j['total']),
      costPerMeter:    _dn(j['costPerMeter']),
    );
  }

  bool get isOutsourced => productionMode == 'outsource';

  /// Any conversion charge on this job that came from a hand-entered
  /// figure rather than the rate card.
  bool get hasOverride =>
      finishing.isOverride ||
      checking.isOverride ||
      packing.isOverride ||
      overhead.isOverride;
}

/// The identity of the order the P&L is about.
class PnlOrderRef {
  final String id;
  final int? orderNo;
  final String po;
  final String status;
  final DateTime? date;
  final DateTime? supplyDate;
  final String customerName;

  const PnlOrderRef({
    required this.id,
    required this.po,
    required this.status,
    required this.customerName,
    this.orderNo,
    this.date,
    this.supplyDate,
  });

  factory PnlOrderRef.fromJson(Map<String, dynamic> j) => PnlOrderRef(
        id:           _s(j['id']),
        orderNo:      (j['orderNo'] as num?)?.toInt(),
        po:           _s(j['po']),
        status:       _s(j['status']),
        date:         _date(j['date']),
        supplyDate:   _date(j['supplyDate']),
        customerName: _s(j['customerName']),
      );

  String get label => orderNo != null ? 'Order #$orderNo' : 'Order';
}

/// One row of the P&L list.
class PnlListRow {
  final PnlOrderRef order;
  final double orderValue;
  final double invoiced;
  final double cost;
  final PnlCosts costs;
  final double profit;

  /// Null means UNKNOWN, not zero. See the note at the top of this file.
  final double? marginPct;

  final double producedMeters;
  final int jobs;
  final int warnings;

  const PnlListRow({
    required this.order,
    required this.orderValue,
    required this.invoiced,
    required this.cost,
    required this.costs,
    required this.profit,
    required this.producedMeters,
    required this.jobs,
    required this.warnings,
    this.marginPct,
  });

  factory PnlListRow.fromJson(Map<String, dynamic> j) => PnlListRow(
        // The list flattens the order's own fields onto the row rather
        // than nesting them, so the ref is parsed from the row itself.
        order:          PnlOrderRef.fromJson(j),
        orderValue:     _d(j['orderValue']),
        invoiced:       _d(j['invoiced']),
        cost:           _d(j['cost']),
        costs:          j['costs'] is Map
            ? PnlCosts.fromJson(Map<String, dynamic>.from(j['costs'] as Map))
            : const PnlCosts(),
        profit:         _d(j['profit']),
        marginPct:      _dn(j['marginPct']),
        producedMeters: _d(j['producedMeters']),
        jobs:           _i(j['jobs']),
        warnings:       _i(j['warnings']),
      );

  bool get priced => marginPct != null;
  bool get losing => marginPct != null && profit < 0;
}

/// One page of the list, with what the server said about its own sort.
class PnlListPage {
  final List<PnlListRow> rows;
  final int page;
  final int pages;
  final int total;
  final String sort;

  /// 'all' or 'page'. Sorting by margin cannot be pushed down to the
  /// database — margin does not exist until the P&L is built — so
  /// anything but `recent` orders the PAGE, not the result set. The
  /// server says which, and the screen has to repeat it: a "top margin"
  /// heading that quietly meant "of these 25" is a lie worth avoiding.
  final String sortScope;

  final double totalOrderValue;
  final double totalCost;
  final double totalProfit;

  const PnlListPage({
    required this.rows,
    required this.page,
    required this.pages,
    required this.total,
    required this.sort,
    required this.sortScope,
    required this.totalOrderValue,
    required this.totalCost,
    required this.totalProfit,
  });

  static const empty = PnlListPage(
    rows: [], page: 1, pages: 1, total: 0,
    sort: 'recent', sortScope: 'all',
    totalOrderValue: 0, totalCost: 0, totalProfit: 0,
  );

  factory PnlListPage.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'] is Map
        ? Map<String, dynamic>.from(j['totals'] as Map)
        : <String, dynamic>{};
    return PnlListPage(
      rows: (j['rows'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PnlListRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      page:  _i(j['page']) == 0 ? 1 : _i(j['page']),
      pages: _i(j['pages']) == 0 ? 1 : _i(j['pages']),
      total: _i(j['total']),
      sort:  _s(j['sort']).isEmpty ? 'recent' : _s(j['sort']),
      sortScope: _s(j['sortScope']).isEmpty ? 'all' : _s(j['sortScope']),
      totalOrderValue: _d(totals['orderValue']),
      totalCost:       _d(totals['cost']),
      totalProfit:     _d(totals['profit']),
    );
  }

  /// The margin of this page's totals. Computed from the page's own
  /// sums, so it is the margin OF THE PAGE and is labelled as such.
  double? get marginPct =>
      totalOrderValue > 0 ? totalProfit / totalOrderValue * 100 : null;
}

/// What has actually been invoiced, reported beside the order value
/// rather than as a substitute for it.
class PnlInvoiced {
  final double amount;
  final double quantity;
  final int challans;

  const PnlInvoiced({
    this.amount = 0,
    this.quantity = 0,
    this.challans = 0,
  });

  factory PnlInvoiced.fromJson(Map<String, dynamic> j) => PnlInvoiced(
        amount:   _d(j['amount']),
        quantity: _d(j['quantity']),
        challans: _i(j['challans']),
      );
}

class PnlRateCard {
  final double finishing;
  final double checking;
  final double packing;
  final double overhead;

  /// False means the rate card has never been set, so all four
  /// conversions are ₹0 — which flatters every order in the factory.
  final bool configured;

  const PnlRateCard({
    this.finishing = 0,
    this.checking = 0,
    this.packing = 0,
    this.overhead = 0,
    this.configured = false,
  });

  factory PnlRateCard.fromJson(Map<String, dynamic> j) => PnlRateCard(
        finishing:  _d(j['finishingRatePerMeter']),
        checking:   _d(j['checkingRatePerMeter']),
        packing:    _d(j['packingRatePerMeter']),
        overhead:   _d(j['overheadRatePerMeter']),
        configured: j['configured'] == true,
      );

  List<MapEntry<String, double>> get rows => [
        MapEntry('Finishing', finishing),
        MapEntry('Checking', checking),
        MapEntry('Packing', packing),
        MapEntry('Overhead', overhead),
      ];
}

class PnlTotals {
  final double producedMeters;
  final double orderedQuantity;
  final double profit;
  final double? marginPct;
  final double? costPerMeter;
  final double? revenuePerMeter;

  const PnlTotals({
    this.producedMeters = 0,
    this.orderedQuantity = 0,
    this.profit = 0,
    this.marginPct,
    this.costPerMeter,
    this.revenuePerMeter,
  });

  factory PnlTotals.fromJson(Map<String, dynamic> j) => PnlTotals(
        producedMeters:  _d(j['producedMeters']),
        orderedQuantity: _d(j['orderedQuantity']),
        profit:          _d(j['profit']),
        marginPct:       _dn(j['marginPct']),
        costPerMeter:    _dn(j['costPerMeter']),
        revenuePerMeter: _dn(j['revenuePerMeter']),
      );
}

/// The whole breakdown for one order.
class OrderPnl {
  final PnlOrderRef order;
  final List<PnlRevenueLine> lines;
  final double orderValue;
  final PnlInvoiced invoiced;
  final PnlCosts costs;
  final List<PnlJobRow> jobs;
  final PnlTotals totals;
  final PnlRateCard rateCard;
  final List<PnlMaterialLine> materialLines;

  /// Everything the server thinks is wrong or missing about this P&L,
  /// in its own words. Shown, not summarised — each one names something
  /// specific that is making a figure wrong.
  final List<String> warnings;

  const OrderPnl({
    required this.order,
    required this.lines,
    required this.orderValue,
    required this.invoiced,
    required this.costs,
    required this.jobs,
    required this.totals,
    required this.rateCard,
    required this.materialLines,
    required this.warnings,
  });

  factory OrderPnl.fromJson(Map<String, dynamic> j) {
    final revenue = j['revenue'] is Map
        ? Map<String, dynamic>.from(j['revenue'] as Map)
        : <String, dynamic>{};
    return OrderPnl(
      order: PnlOrderRef.fromJson(
        j['order'] is Map
            ? Map<String, dynamic>.from(j['order'] as Map)
            : <String, dynamic>{},
      ),
      lines: (revenue['lines'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PnlRevenueLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      orderValue: _d(revenue['orderValue']),
      invoiced: revenue['invoiced'] is Map
          ? PnlInvoiced.fromJson(
              Map<String, dynamic>.from(revenue['invoiced'] as Map))
          : const PnlInvoiced(),
      costs: j['costs'] is Map
          ? PnlCosts.fromJson(Map<String, dynamic>.from(j['costs'] as Map))
          : const PnlCosts(),
      jobs: (j['jobs'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PnlJobRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totals: j['totals'] is Map
          ? PnlTotals.fromJson(Map<String, dynamic>.from(j['totals'] as Map))
          : const PnlTotals(),
      rateCard: j['rateCard'] is Map
          ? PnlRateCard.fromJson(
              Map<String, dynamic>.from(j['rateCard'] as Map))
          : const PnlRateCard(),
      materialLines: (j['materialLines'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PnlMaterialLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      warnings: (j['warnings'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  bool get priced => totals.marginPct != null;

  /// How much of the order value has been invoiced, 0..1, or null when
  /// there is no order value to measure against.
  double? get invoicedFraction {
    if (orderValue <= 0) return null;
    final f = invoiced.amount / orderValue;
    return f > 1 ? 1 : f;
  }
}
