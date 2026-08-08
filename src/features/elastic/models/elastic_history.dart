// ══════════════════════════════════════════════════════════════
//  WHERE AN ELASTIC HAS BEEN
//
//  Mirrors GET /elastic/:id/orders and GET /elastic/:id/jobs.
//
//  The quantities on these rows are THIS elastic's line only. An order
//  carrying four products would otherwise report the other three as
//  this one's — the server pulls the matching line out before it
//  answers, which is the whole reason these are their own endpoints
//  rather than a filter over the order list.
//
//  Both paginate, because a product that has been in the catalogue for
//  years has hundreds of each and neither list has a natural end.
// ══════════════════════════════════════════════════════════════

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class ElasticOrderRow {
  final String id;
  final int? orderNo;
  final String po;
  final DateTime? date;
  final DateTime? supplyDate;
  final String status;
  final String customerId;
  final String customerName;

  final double ordered;
  final double produced;
  final double packed;

  const ElasticOrderRow({
    required this.id,
    required this.po,
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.ordered,
    required this.produced,
    required this.packed,
    this.orderNo,
    this.date,
    this.supplyDate,
  });

  factory ElasticOrderRow.fromJson(Map<String, dynamic> j) => ElasticOrderRow(
        id:           _s(j['id']),
        orderNo:      (j['orderNo'] as num?)?.toInt(),
        po:           _s(j['po']),
        date:         _date(j['date']),
        supplyDate:   _date(j['supplyDate']),
        status:       _s(j['status']),
        customerId:   _s(j['customerId']),
        customerName: _s(j['customerName']),
        ordered:      _d(j['ordered']),
        produced:     _d(j['produced']),
        packed:       _d(j['packed']),
      );

  String get label => orderNo != null ? 'Order #$orderNo' : 'Order';

  /// How much of what was ordered has been packed, 0..1. Only meaningful
  /// when something was ordered — a zero-quantity line is not 0% done,
  /// it is a line that asked for nothing.
  double? get packedFraction {
    if (ordered <= 0) return null;
    final f = packed / ordered;
    return f > 1 ? 1 : f;
  }
}

class ElasticJobRow {
  final String id;
  final int? jobOrderNo;
  final String jobNo;
  final DateTime? date;
  final String status;
  final String orderId;
  final int? orderNo;
  final String customerName;

  final double planned;
  final double produced;
  final double packed;
  final double wastage;

  const ElasticJobRow({
    required this.id,
    required this.jobNo,
    required this.status,
    required this.orderId,
    required this.customerName,
    required this.planned,
    required this.produced,
    required this.packed,
    required this.wastage,
    this.jobOrderNo,
    this.orderNo,
    this.date,
  });

  factory ElasticJobRow.fromJson(Map<String, dynamic> j) => ElasticJobRow(
        id:           _s(j['id']),
        jobOrderNo:   (j['jobOrderNo'] as num?)?.toInt(),
        jobNo:        _s(j['jobNo']),
        date:         _date(j['date']),
        status:       _s(j['status']),
        orderId:      _s(j['orderId']),
        orderNo:      (j['orderNo'] as num?)?.toInt(),
        customerName: _s(j['customerName']),
        planned:      _d(j['planned']),
        produced:     _d(j['produced']),
        packed:       _d(j['packed']),
        wastage:      _d(j['wastage']),
      );

  String get label =>
      jobNo.isNotEmpty ? jobNo : (jobOrderNo != null ? 'J-$jobOrderNo' : 'Job');

  /// Wastage as a share of what was produced. Measured against produced
  /// rather than planned: waste comes off what actually ran, and a job
  /// that only made half its plan did not waste the half it never wove.
  double? get wastagePct {
    if (produced <= 0) return null;
    return wastage / produced * 100;
  }
}

/// One page of either list, with the paging facts the server sent.
class ElasticHistoryPage<T> {
  final List<T> rows;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  const ElasticHistoryPage({
    required this.rows,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  static ElasticHistoryPage<T> of<T>(
    Map<String, dynamic> j,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    final rows = (j[key] as List? ?? [])
        .whereType<Map>()
        .map((e) => parse(Map<String, dynamic>.from(e)))
        .toList();
    return ElasticHistoryPage<T>(
      rows: rows,
      page:  (j['page'] as num?)?.toInt() ?? 1,
      limit: (j['limit'] as num?)?.toInt() ?? 20,
      total: (j['total'] as num?)?.toInt() ?? rows.length,
      hasMore: j['hasMore'] == true,
    );
  }
}
