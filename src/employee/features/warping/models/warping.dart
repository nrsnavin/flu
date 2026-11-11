// ══════════════════════════════════════════════════════════════
//  WARPING MODELS — Worker Portal (read-only view)
//
//  Lighter copy of the admin app's models.dart, trimmed to only
//  the fields the worker screens render. Uses SafeJson everywhere
//  so a backend deploy that flips a field type can't crash the app.
// ══════════════════════════════════════════════════════════════

import '../../../core/safe_json.dart';

class WarpingListItem {
  final String   id;
  final String   status;
  final DateTime date;
  final DateTime? completedDate;
  final int      jobOrderNo;
  final String   jobId;
  final String   jobStatus;
  final bool     hasPlan;
  final String?  customerName;

  const WarpingListItem({
    required this.id,
    required this.status,
    required this.date,
    this.completedDate,
    required this.jobOrderNo,
    required this.jobId,
    required this.jobStatus,
    required this.hasPlan,
    this.customerName,
  });

  factory WarpingListItem.fromJson(Map<String, dynamic> json) {
    final job = SafeJson.asMap(json['job']);
    final cust = SafeJson.asMap(job['customer']);
    return WarpingListItem(
      id:            SafeJson.asString(json['_id']),
      status:        SafeJson.asString(json['status'], 'open'),
      date:          SafeJson.asDateTime(json['date']) ?? DateTime.now(),
      completedDate: SafeJson.asDateTime(json['completedDate']),
      jobOrderNo:    SafeJson.asInt(job['jobOrderNo']),
      jobId:         SafeJson.asString(job['_id']),
      jobStatus:     SafeJson.asString(job['status'], '—'),
      hasPlan:       json['warpingPlan'] != null,
      customerName:  SafeJson.asStringOrNull(cust['name']),
    );
  }
}

// ─── Material + ElasticWarpDetail (read-only) ────────────────
class WarpMaterial {
  final String id;
  final String name;
  final int    ends;
  final double weight;
  const WarpMaterial({
    required this.id,
    required this.name,
    required this.ends,
    required this.weight,
  });
}

class ElasticWarpDetail {
  final String elasticId;
  final String elasticName;
  final int    plannedQty;
  final WarpMaterial?     warpSpandex;
  final List<WarpMaterial> warpYarns;
  final int    spandexEnds;
  final int    noOfHook;
  final int    pick;
  final double weight;

  const ElasticWarpDetail({
    required this.elasticId,
    required this.elasticName,
    required this.plannedQty,
    this.warpSpandex,
    required this.warpYarns,
    required this.spandexEnds,
    required this.noOfHook,
    required this.pick,
    required this.weight,
  });

  factory ElasticWarpDetail.fromJson(Map<String, dynamic> json) {
    final el = SafeJson.asMapOrNull(json['elastic']);
    if (el == null) {
      return const ElasticWarpDetail(
        elasticId: '', elasticName: '—', plannedQty: 0,
        warpYarns: [], spandexEnds: 0, noOfHook: 0, pick: 0, weight: 0,
      );
    }

    WarpMaterial? spandex;
    final ws = SafeJson.asMap(el['warpSpandex']);
    final wsId = SafeJson.asMapOrNull(ws['id']);
    if (wsId != null) {
      spandex = WarpMaterial(
        id:     SafeJson.asString(wsId['_id']),
        name:   SafeJson.asString(wsId['name'], '—'),
        ends:   SafeJson.asInt(ws['ends']),
        weight: SafeJson.asDouble(ws['weight']),
      );
    }

    final yarns = <WarpMaterial>[];
    for (final w in SafeJson.asList(el['warpYarn'])) {
      final wMap = SafeJson.asMap(w);
      final wId  = SafeJson.asMapOrNull(wMap['id']);
      if (wId == null) continue;
      yarns.add(WarpMaterial(
        id:     SafeJson.asString(wId['_id']),
        name:   SafeJson.asString(wId['name'], '—'),
        ends:   SafeJson.asInt(wMap['ends']),
        weight: SafeJson.asDouble(wMap['weight']),
      ));
    }

    return ElasticWarpDetail(
      elasticId:   SafeJson.asString(el['_id']),
      elasticName: SafeJson.asString(el['name'], '—'),
      plannedQty:  SafeJson.asInt(json['quantity']),
      warpSpandex: spandex,
      warpYarns:   yarns,
      spandexEnds: SafeJson.asInt(el['spandexEnds']),
      noOfHook:    SafeJson.asInt(el['noOfHook']),
      pick:        SafeJson.asInt(el['pick']),
      weight:      SafeJson.asDouble(el['weight']),
    );
  }
}

// ─── Plan (read-only) ────────────────────────────────────────
class WarpingPlanDetail {
  final String   id;
  final String   warpingId;
  final String   jobId;
  final int      jobOrderNo;
  final int      noOfBeams;
  final String?  remarks;
  final DateTime createdAt;
  final List<WarpingBeamDetail> beams;

  const WarpingPlanDetail({
    required this.id,
    required this.warpingId,
    required this.jobId,
    required this.jobOrderNo,
    required this.noOfBeams,
    this.remarks,
    required this.createdAt,
    required this.beams,
  });

  int get totalEnds => beams.fold(0, (s, b) => s + b.totalEnds);

  factory WarpingPlanDetail.fromJson(Map<String, dynamic> json) {
    final job  = SafeJson.asMap(json['job']);
    final wRaw = json['warping'];
    return WarpingPlanDetail(
      id:         SafeJson.asString(json['_id']),
      warpingId:  wRaw is Map
          ? SafeJson.asString(SafeJson.asMap(wRaw)['_id'])
          : SafeJson.asString(wRaw),
      jobId:      SafeJson.asString(job['_id']),
      jobOrderNo: SafeJson.asInt(job['jobOrderNo']),
      noOfBeams:  SafeJson.asInt(json['noOfBeams']),
      remarks:    SafeJson.asStringOrNull(json['remarks']),
      createdAt:  SafeJson.asDateTime(json['createdAt']) ?? DateTime.now(),
      beams: SafeJson.asMapList(json['beams'])
          .map(WarpingBeamDetail.fromJson)
          .toList(),
    );
  }
}

class WarpingBeamDetail {
  final int beamNo;
  final int totalEnds;
  final int? pairedBeamNo;
  final List<WarpingBeamSectionDetail> sections;

  const WarpingBeamDetail({
    required this.beamNo,
    required this.totalEnds,
    required this.sections,
    this.pairedBeamNo,
  });

  factory WarpingBeamDetail.fromJson(Map<String, dynamic> json) =>
      WarpingBeamDetail(
        beamNo:       SafeJson.asInt(json['beamNo']),
        totalEnds:    SafeJson.asInt(json['totalEnds']),
        pairedBeamNo: SafeJson.asNum(json['pairedBeamNo'])?.toInt(),
        sections: SafeJson.asMapList(json['sections'])
            .map(WarpingBeamSectionDetail.fromJson)
            .toList(),
      );
}

class WarpingBeamSectionDetail {
  final String warpYarnId;
  final String warpYarnName;
  final int    ends;
  final double maxMeters;

  const WarpingBeamSectionDetail({
    required this.warpYarnId,
    required this.warpYarnName,
    required this.ends,
    this.maxMeters = 0,
  });

  factory WarpingBeamSectionDetail.fromJson(Map<String, dynamic> json) {
    final wy = json['warpYarn'];
    if (wy is Map) {
      final m = SafeJson.asMap(wy);
      return WarpingBeamSectionDetail(
        warpYarnId:   SafeJson.asString(m['_id']),
        warpYarnName: SafeJson.asString(m['name'], '—'),
        ends:         SafeJson.asInt(json['ends']),
        maxMeters:    SafeJson.asDouble(json['maxMeters']),
      );
    }
    return WarpingBeamSectionDetail(
      warpYarnId:   SafeJson.asString(wy),
      warpYarnName: '—',
      ends:         SafeJson.asInt(json['ends']),
      maxMeters:    SafeJson.asDouble(json['maxMeters']),
    );
  }
}

// ─── WarpingDetail (header + elastics) ───────────────────────
class WarpingDetail {
  final String   id;
  final String   status;
  final DateTime date;
  final DateTime? completedDate;
  final int      jobOrderNo;
  final String   jobId;
  final String?  customerName;
  final String   planId;        // empty = no plan
  final bool     hasPlan;
  final WarpingPlanDetail? plan;
  final List<ElasticWarpDetail> elastics;

  const WarpingDetail({
    required this.id,
    required this.status,
    required this.date,
    this.completedDate,
    required this.jobOrderNo,
    required this.jobId,
    this.customerName,
    required this.planId,
    required this.hasPlan,
    this.plan,
    required this.elastics,
  });

  factory WarpingDetail.fromJson(Map<String, dynamic> json) {
    final job  = SafeJson.asMap(json['job']);
    final cust = SafeJson.asMap(job['customer']);

    String planId = '';
    WarpingPlanDetail? plan;
    final rawPlan = json['warpingPlan'];
    if (rawPlan is Map) {
      final pm = SafeJson.asMap(rawPlan);
      planId = SafeJson.asString(pm['_id']);
      plan   = WarpingPlanDetail.fromJson(pm);
    } else if (rawPlan is String && rawPlan.isNotEmpty) {
      planId = rawPlan;
    }

    return WarpingDetail(
      id:            SafeJson.asString(json['_id']),
      status:        SafeJson.asString(json['status'], 'open'),
      date:          SafeJson.asDateTime(json['date']) ?? DateTime.now(),
      completedDate: SafeJson.asDateTime(json['completedDate']),
      jobOrderNo:    SafeJson.asInt(job['jobOrderNo']),
      jobId:         SafeJson.asString(job['_id']),
      customerName:  SafeJson.asStringOrNull(cust['name']),
      planId:        planId,
      hasPlan:       planId.isNotEmpty,
      plan:          plan,
      elastics: SafeJson.asMapList(json['elasticOrdered'])
          .map(ElasticWarpDetail.fromJson)
          .toList(),
    );
  }
}
