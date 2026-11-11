// ══════════════════════════════════════════════════════════════
//  COVERING MODELS — Worker Portal
// ══════════════════════════════════════════════════════════════

import '../../../core/safe_json.dart';

class CoveringListItem {
  final String   id;
  final String   status;
  final DateTime date;
  final int      jobOrderNo;
  final String   jobId;
  final String?  customerName;
  final String?  remarks;

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
    final job  = SafeJson.asMap(json['job']);
    final cust = SafeJson.asMap(job['customer']);
    return CoveringListItem(
      id:           SafeJson.asString(json['_id']),
      status:       SafeJson.asString(json['status'], 'open'),
      date:         SafeJson.asDateTime(json['date']) ?? DateTime.now(),
      jobOrderNo:   SafeJson.asInt(job['jobOrderNo']),
      jobId:        SafeJson.asString(job['_id']),
      customerName: SafeJson.asStringOrNull(cust['name']),
      remarks:      SafeJson.asStringOrNull(json['remarks']),
    );
  }
}

class JobSummary {
  final String  id;
  final int     jobOrderNo;
  final String  status;
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

  factory JobSummary.empty() =>
      const JobSummary(id: '', jobOrderNo: 0, status: '—');

  factory JobSummary.fromJson(Map<String, dynamic> json) {
    final cust  = SafeJson.asMap(json['customer']);
    final order = SafeJson.asMap(json['order']);
    return JobSummary(
      id:           SafeJson.asString(json['_id']),
      jobOrderNo:   SafeJson.asInt(json['jobOrderNo']),
      status:       SafeJson.asString(json['status'], '—'),
      customerName: SafeJson.asStringOrNull(cust['name']) ??
          SafeJson.asStringOrNull(json['customer']),
      orderNo:      SafeJson.asStringOrNull(order['orderNo']),
      po:           SafeJson.asStringOrNull(order['po']),
    );
  }
}

class WarpSpandex {
  final String materialName;
  final int    ends;
  final double weight;
  const WarpSpandex({
    required this.materialName,
    required this.ends,
    required this.weight,
  });

  factory WarpSpandex.fromJson(Map<String, dynamic> json) {
    final idField = json['id'];
    return WarpSpandex(
      materialName: idField is Map
          ? SafeJson.asString(SafeJson.asMap(idField)['name'], '—')
          : '—',
      ends:   SafeJson.asInt(json['ends']),
      weight: SafeJson.asDouble(json['weight']),
    );
  }
}

class CoveringSpandex {
  final String materialName;
  final double weight;
  const CoveringSpandex({
    required this.materialName,
    required this.weight,
  });

  factory CoveringSpandex.fromJson(Map<String, dynamic> json) {
    final idField = json['id'];
    return CoveringSpandex(
      materialName: idField is Map
          ? SafeJson.asString(SafeJson.asMap(idField)['name'], '—')
          : '—',
      weight: SafeJson.asDouble(json['weight']),
    );
  }
}

class TestingParams {
  final double? width;
  final int     elongation;
  final int     recovery;
  final String? strech;

  const TestingParams({
    this.width,
    required this.elongation,
    required this.recovery,
    this.strech,
  });

  factory TestingParams.fromJson(Map<String, dynamic> json) =>
      TestingParams(
        width:      SafeJson.asNum(json['width'])?.toDouble(),
        elongation: SafeJson.asInt(json['elongation'], 120),
        recovery:   SafeJson.asInt(json['recovery'], 90),
        strech:     SafeJson.asStringOrNull(json['strech']),
      );
}

class ElasticTechnical {
  final String  id;
  final String  name;
  final int     spandexEnds;
  final int     yarnEnds;
  final int     pick;
  final int     noOfHook;
  final double  weight;
  final String  weaveType;
  final WarpSpandex?     warpSpandex;
  final CoveringSpandex? spandexCovering;
  final TestingParams?   testing;

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
        id: '', name: '—',
        spandexEnds: 0, yarnEnds: 0, pick: 0,
        noOfHook: 0, weight: 0, weaveType: '—',
      );

  factory ElasticTechnical.fromJson(Map<String, dynamic> json) =>
      ElasticTechnical(
        id:           SafeJson.asString(json['_id']),
        name:         SafeJson.asString(json['name'], '—'),
        spandexEnds:  SafeJson.asInt(json['spandexEnds']),
        yarnEnds:     SafeJson.asInt(json['yarnEnds']),
        pick:         SafeJson.asInt(json['pick']),
        noOfHook:     SafeJson.asInt(json['noOfHook']),
        weight:       SafeJson.asDouble(json['weight']),
        weaveType:    SafeJson.asString(json['weaveType'], '—'),
        warpSpandex:  json['warpSpandex'] is Map
            ? WarpSpandex.fromJson(SafeJson.asMap(json['warpSpandex']))
            : null,
        spandexCovering: json['spandexCovering'] is Map
            ? CoveringSpandex.fromJson(
                SafeJson.asMap(json['spandexCovering']))
            : null,
        testing: json['testingParameters'] is Map
            ? TestingParams.fromJson(
                SafeJson.asMap(json['testingParameters']))
            : null,
      );
}

class CoveringElasticDetail {
  final ElasticTechnical elastic;
  final int quantity;

  const CoveringElasticDetail({
    required this.elastic,
    required this.quantity,
  });

  factory CoveringElasticDetail.fromJson(Map<String, dynamic> json) =>
      CoveringElasticDetail(
        elastic: json['elastic'] is Map
            ? ElasticTechnical.fromJson(SafeJson.asMap(json['elastic']))
            : ElasticTechnical.empty(),
        quantity: SafeJson.asInt(json['quantity']),
      );
}

class BeamEntry {
  final String  id;
  final int     beamNo;
  final double  weight;
  final String  note;
  final DateTime enteredAt;
  final String? enteredById;
  final String? enteredByName;

  const BeamEntry({
    required this.id,
    required this.beamNo,
    required this.weight,
    required this.note,
    required this.enteredAt,
    this.enteredById,
    this.enteredByName,
  });

  factory BeamEntry.fromJson(Map<String, dynamic> json) {
    final eb = json['enteredBy'];
    final ebMap = eb is Map ? SafeJson.asMap(eb) : null;
    return BeamEntry(
      id:        SafeJson.asString(json['_id']),
      beamNo:    SafeJson.asInt(json['beamNo']),
      weight:    SafeJson.asDouble(json['weight']),
      note:      SafeJson.asString(json['note']),
      enteredAt: SafeJson.asLocalDateTime(json['enteredAt']) ??
          DateTime.now(),
      enteredById:   ebMap != null
          ? SafeJson.asStringOrNull(ebMap['_id'])
          : SafeJson.asStringOrNull(eb),
      enteredByName: ebMap != null
          ? SafeJson.asStringOrNull(ebMap['name'])
          : null,
    );
  }
}

class CoveringDetail {
  final String   id;
  final String   status;
  final DateTime date;
  final DateTime? completedDate;
  final String?  remarks;
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

  factory CoveringDetail.fromJson(Map<String, dynamic> json) =>
      CoveringDetail(
        id:            SafeJson.asString(json['_id']),
        status:        SafeJson.asString(json['status'], 'open'),
        date:          SafeJson.asDateTime(json['date']) ?? DateTime.now(),
        completedDate: SafeJson.asDateTime(json['completedDate']),
        remarks:       SafeJson.asStringOrNull(json['remarks']),
        job: json['job'] is Map
            ? JobSummary.fromJson(SafeJson.asMap(json['job']))
            : JobSummary.empty(),
        elasticPlanned: SafeJson.asMapList(json['elasticPlanned'])
            .where((e) => e['elastic'] != null)
            .map(CoveringElasticDetail.fromJson)
            .toList(),
        beamEntries: SafeJson.asMapList(json['beamEntries'])
            .map(BeamEntry.fromJson)
            .toList(),
        producedWeight: SafeJson.asDouble(json['producedWeight']),
      );

  bool get isOpen       => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';
}
