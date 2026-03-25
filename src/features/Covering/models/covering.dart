// ══════════════════════════════════════════════════════════════
//  COVERING MODELS — unified single file
// ══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  CoveringListItem  (list page row)
//
//  FIX: original CoveringModel.fromJson used json['job']['jobOrderNo']
//       with no null guard → crashes when job field is null or
//       not populated. Also stored date as DateTime but the field
//       can be null or malformed from the API.
// ─────────────────────────────────────────────────────────────

class CoveringListItem {
  final String id;
  final String status;
  final DateTime date;
  final int jobOrderNo;
  final String jobId;
  final String? customerName;
  final String? remarks;

  const CoveringListItem({
    required this.id,
    required this.status,
    required this.date,
    required this.jobOrderNo,
    required this.jobId,
    this.customerName,
    this.remarks,
  });

  factory CoveringListItem.fromJson(Map<String, dynamic> json) {
    final job = json['job'];
    return CoveringListItem(
      id:           json['_id']?.toString()    ?? '',
      status:       json['status']?.toString() ?? 'open',
      date:         DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      jobOrderNo:   (job is Map
          ? (job['jobOrderNo'] as num?)?.toInt()
          : null) ?? 0,
      jobId:        (job is Map ? job['_id']?.toString() : null) ?? '',
      customerName: (job is Map && job['customer'] is Map)
          ? job['customer']['name']?.toString()
          : null,
      remarks:      json['remarks']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CoveringDetail  (detail page)
//
//  FIX: original covering.dart imported covering_detail.dart
//       which is the CONTROLLER file containing ApiService —
//       circular import causing compile error.
//  FIX: WarpSpandex.fromJson / CoveringSpandex.fromJson both
//       used json["id"]["name"] with no null guard → crash if
//       raw material was deleted or not populated.
//  FIX: ElasticTechnical.fromJson accessed warpSpandex,
//       spandexCovering, testingParameters without null guards.
//  FIX: CoveringElasticDetail.fromJson had no null guard on
//       the elastic field.
// ─────────────────────────────────────────────────────────────

class CoveringDetail {
  final String id;
  final String status;
  final DateTime date;
  final DateTime? completedDate;
  final String? remarks;
  final JobSummary job;
  final List<CoveringElasticDetail> elasticPlanned;
  final List<BeamEntry> beamEntries;
  final double producedWeight;

  const CoveringDetail({
    required this.id,
    required this.status,
    required this.date,
    this.completedDate,
    this.remarks,
    required this.job,
    required this.elasticPlanned,
    required this.beamEntries,
    required this.producedWeight,
  });

  factory CoveringDetail.fromJson(Map<String, dynamic> json) {
    return CoveringDetail(
      id:            json['_id']?.toString()    ?? '',
      status:        json['status']?.toString() ?? 'open',
      date:          DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      completedDate: json['completedDate'] != null
          ? DateTime.tryParse(json['completedDate'].toString())
          : null,
      remarks:       json['remarks']?.toString(),
      job:           json['job'] is Map
          ? JobSummary.fromJson(json['job'] as Map<String, dynamic>)
          : JobSummary.empty(),
      elasticPlanned: (json['elasticPlanned'] as List? ?? [])
          .where((e) => e is Map && e['elastic'] != null)
          .map((e) => CoveringElasticDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      beamEntries: (json['beamEntries'] as List? ?? [])
          .map((e) => BeamEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      producedWeight: (json['producedWeight'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get isOpen       => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';

  // ── Expected produce weight ───────────────────────────────
  // Formula per elastic:
  //   (warpSpandex.weight + spandexCovering.weight) × quantity
  // Weights are in g/m, quantity in meters → raw grams ÷ 1000 = kg
  double get expectedProduceWeight {
    double totalGrams = 0;
    for (final ep in elasticPlanned) {
      final ws  = ep.elastic.warpSpandex?.weight    ?? 0.0;
      final sc  = ep.elastic.spandexCovering?.weight ?? 0.0;
      totalGrams += (ws + sc) * ep.quantity;
    }
    return totalGrams / 1000; // kg
  }
}

// ─────────────────────────────────────────────────────────────
//  JobSummary
// ─────────────────────────────────────────────────────────────

class JobSummary {
  final String id;
  final int jobOrderNo;
  final String status;
  final String? customerName;
  final String? orderNo;
  final String? po;

  const JobSummary({
    required this.id,
    required this.jobOrderNo,
    required this.status,
    this.customerName,
    this.orderNo,
    this.po,
  });

  factory JobSummary.empty() => const JobSummary(
    id: '', jobOrderNo: 0, status: '—',
  );

  factory JobSummary.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final order    = json['order'];
    return JobSummary(
      id:           json['_id']?.toString()                          ?? '',
      jobOrderNo:   (json['jobOrderNo'] as num?)?.toInt()            ?? 0,
      status:       json['status']?.toString()                       ?? '—',
      customerName: customer is Map
          ? customer['name']?.toString()
          : customer?.toString(),
      orderNo:      order is Map ? order['orderNo']?.toString()      : null,
      po:           order is Map ? order['po']?.toString()           : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CoveringElasticDetail
// ─────────────────────────────────────────────────────────────

class CoveringElasticDetail {
  final ElasticTechnical elastic;
  final int quantity;

  const CoveringElasticDetail({
    required this.elastic,
    required this.quantity,
  });

  factory CoveringElasticDetail.fromJson(Map<String, dynamic> json) {
    return CoveringElasticDetail(
      // FIX: null guard — elastic is always a populated Map at this
      // point (filtered in CoveringDetail.fromJson) but guarded anyway
      elastic:  json['elastic'] is Map
          ? ElasticTechnical.fromJson(
          json['elastic'] as Map<String, dynamic>)
          : ElasticTechnical.empty(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ElasticTechnical
// ─────────────────────────────────────────────────────────────

class ElasticTechnical {
  final String id;
  final String name;
  final int spandexEnds;
  final int yarnEnds;
  final int pick;
  final int noOfHook;
  final double weight;
  final String weaveType;
  final WarpSpandex? warpSpandex;
  final CoveringSpandex? spandexCovering;
  final TestingParams? testing;

  const ElasticTechnical({
    required this.id,
    required this.name,
    required this.spandexEnds,
    required this.yarnEnds,
    required this.pick,
    required this.noOfHook,
    required this.weight,
    required this.weaveType,
    this.warpSpandex,
    this.spandexCovering,
    this.testing,
  });

  factory ElasticTechnical.empty() => const ElasticTechnical(
    id: '', name: '—', spandexEnds: 0, yarnEnds: 0,
    pick: 0, noOfHook: 0, weight: 0, weaveType: '—',
  );

  factory ElasticTechnical.fromJson(Map<String, dynamic> json) {
    return ElasticTechnical(
      id:             json['_id']?.toString()          ?? '',
      name:           json['name']?.toString()         ?? '—',
      spandexEnds:    (json['spandexEnds']  as num?)?.toInt()    ?? 0,
      yarnEnds:       (json['yarnEnds']     as num?)?.toInt()    ?? 0,
      pick:           (json['pick']         as num?)?.toInt()    ?? 0,
      noOfHook:       (json['noOfHook']     as num?)?.toInt()    ?? 0,
      weight:         (json['weight']       as num?)?.toDouble() ?? 0.0,
      weaveType:      json['weaveType']?.toString()    ?? '—',
      // FIX: null-guard all nested objects
      warpSpandex:    json['warpSpandex'] is Map
          ? WarpSpandex.fromJson(
          json['warpSpandex'] as Map<String, dynamic>)
          : null,
      spandexCovering: json['spandexCovering'] is Map
          ? CoveringSpandex.fromJson(
          json['spandexCovering'] as Map<String, dynamic>)
          : null,
      testing:        json['testingParameters'] is Map
          ? TestingParams.fromJson(
          json['testingParameters'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WarpSpandex
//
//  FIX: original used json["id"]["name"] which crashed when the
//       "id" field (ObjectId ref to RawMaterial) wasn't populated
//       or the material was deleted. Now null-safe.
// ─────────────────────────────────────────────────────────────

class WarpSpandex {
  final String materialId;
  final String materialName;
  final int ends;
  final double weight;

  const WarpSpandex({
    required this.materialId,
    required this.materialName,
    required this.ends,
    required this.weight,
  });

  factory WarpSpandex.fromJson(Map<String, dynamic> json) {
    final idField = json['id'];
    return WarpSpandex(
      materialId:   (idField is Map ? idField['_id'] : idField)?.toString() ?? '',
      materialName: idField is Map
          ? (idField['name']?.toString() ?? '—')
          : '—',
      ends:         (json['ends']   as num?)?.toInt()    ?? 0,
      weight:       (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CoveringSpandex
//
//  FIX: same json["id"]["name"] null crash as WarpSpandex.
// ─────────────────────────────────────────────────────────────

class CoveringSpandex {
  final String materialId;
  final String materialName;
  final double weight;

  const CoveringSpandex({
    required this.materialId,
    required this.materialName,
    required this.weight,
  });

  factory CoveringSpandex.fromJson(Map<String, dynamic> json) {
    final idField = json['id'];
    return CoveringSpandex(
      materialId:   (idField is Map ? idField['_id'] : idField)?.toString() ?? '',
      materialName: idField is Map
          ? (idField['name']?.toString() ?? '—')
          : '—',
      weight:       (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TestingParams
// ─────────────────────────────────────────────────────────────

class TestingParams {
  final double? width;
  final int elongation;
  final int recovery;
  final String? strech;

  const TestingParams({
    this.width,
    required this.elongation,
    required this.recovery,
    this.strech,
  });

  factory TestingParams.fromJson(Map<String, dynamic> json) {
    return TestingParams(
      width:       (json['width']       as num?)?.toDouble(),
      elongation:  (json['elongation']  as num?)?.toInt()    ?? 120,
      recovery:    (json['recovery']    as num?)?.toInt()    ?? 90,
      strech:      json['strech']?.toString(),
    );
  }
}
// ─────────────────────────────────────────────────────────────
//  BeamEntry
// ─────────────────────────────────────────────────────────────

class BeamEntry {
  final String id;
  final int beamNo;
  final double weight;
  final String note;
  final DateTime enteredAt;

  const BeamEntry({
    required this.id,
    required this.beamNo,
    required this.weight,
    required this.note,
    required this.enteredAt,
  });

  factory BeamEntry.fromJson(Map<String, dynamic> j) => BeamEntry(
    id:        j['_id']?.toString()   ?? '',
    beamNo:    (j['beamNo'] as num?)?.toInt()    ?? 0,
    weight:    (j['weight'] as num?)?.toDouble() ?? 0,
    note:      j['note']?.toString()  ?? '',
    enteredAt: j['enteredAt'] != null
        ? DateTime.parse(j['enteredAt'] as String).toLocal()
        : DateTime.now(),
  );
}