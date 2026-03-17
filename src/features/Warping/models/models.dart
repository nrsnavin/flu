// WARPING MODELS — unified, null-safe

// ─── WarpingListItem ──────────────────────────────────────────
class WarpingListItem {
  final String id;
  final String status;
  final DateTime date;
  final DateTime? completedDate;
  final int jobOrderNo;
  final String jobId;
  final String jobStatus;
  final bool hasPlan;

  const WarpingListItem({required this.id, required this.status, required this.date,
    this.completedDate, required this.jobOrderNo, required this.jobId,
    required this.jobStatus, required this.hasPlan});

  factory WarpingListItem.fromJson(Map<String, dynamic> json) {
    final job = json['job'];
    return WarpingListItem(
      id:           json['_id']?.toString() ?? '',
      status:       json['status']?.toString() ?? 'open',
      date:         DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      completedDate: DateTime.tryParse(json['completedDate']?.toString() ?? ''),
      jobOrderNo:  (job is Map ? job['jobOrderNo'] as num? : null)?.toInt() ?? 0,
      jobId:        job is Map ? job['_id']?.toString() ?? '' : '',
      jobStatus:    job is Map ? job['status']?.toString() ?? '—' : '—',
      hasPlan:      json['warpingPlan'] != null,
    );
  }
}

// ─── WarpMaterial ─────────────────────────────────────────────
class WarpMaterial {
  final String id;
  final String name;
  final int ends;
  final double weight;
  const WarpMaterial({required this.id, required this.name, required this.ends, required this.weight});
}

// ─── ElasticWarpDetail ───────────────────────────────────────
// BUGS FIXED:
// 1. WarpMaterialModel read json['id']['name'] with no null guard → crash if not populated
// 2. After populate, warpYarn entries where id is not populated crashed the entire model
class ElasticWarpDetail {
  final String elasticId;
  final String elasticName;
  final int plannedQty;
  final WarpMaterial? warpSpandex;
  final List<WarpMaterial> warpYarns;
  final int spandexEnds;
  final int noOfHook;
  final int pick;
  final double weight;

  const ElasticWarpDetail({required this.elasticId, required this.elasticName,
    required this.plannedQty, this.warpSpandex, required this.warpYarns,
    required this.spandexEnds, required this.noOfHook, required this.pick, required this.weight});

  factory ElasticWarpDetail.fromJson(Map<String, dynamic> json) {
    final el = json['elastic'];
    if (el == null || el is! Map<String, dynamic>) {
      return const ElasticWarpDetail(elasticId:'', elasticName:'—', plannedQty:0,
          warpYarns:[], spandexEnds:0, noOfHook:0, pick:0, weight:0.0);
    }
    WarpMaterial? spandex;
    final ws = el['warpSpandex'];
    if (ws is Map && ws['id'] is Map) {
      spandex = WarpMaterial(
        id:     (ws['id'] as Map)['_id']?.toString()  ?? '',
        name:   (ws['id'] as Map)['name']?.toString() ?? '—',
        ends:  (ws['ends']   as num?)?.toInt()    ?? 0,
        weight:(ws['weight'] as num?)?.toDouble() ?? 0.0,
      );
    }
    final yarns = (el['warpYarn'] as List? ?? [])
        .where((w) => w is Map && w['id'] is Map)
        .map<WarpMaterial>((w) => WarpMaterial(
      id:    (w['id'] as Map)['_id']?.toString()  ?? '',
      name:  (w['id'] as Map)['name']?.toString() ?? '—',
      ends: (w['ends']   as num?)?.toInt()    ?? 0,
      weight:(w['weight'] as num?)?.toDouble() ?? 0.0,
    ))
        .toList();
    return ElasticWarpDetail(
      elasticId:  el['_id']?.toString()        ?? '',
      elasticName:el['name']?.toString()       ?? '—',
      plannedQty: (json['quantity'] as num?)?.toInt()    ?? 0,
      warpSpandex: spandex,
      warpYarns:  yarns,
      spandexEnds:(el['spandexEnds'] as num?)?.toInt()    ?? 0,
      noOfHook:   (el['noOfHook']   as num?)?.toInt()     ?? 0,
      pick:       (el['pick']       as num?)?.toInt()     ?? 0,
      weight:     (el['weight']     as num?)?.toDouble()  ?? 0.0,
    );
  }
}

// ─── WarpingPlanDetail (read-only) ───────────────────────────
class WarpingPlanDetail {
  final String id;
  final String warpingId;
  final String jobId;
  final int jobOrderNo;
  final int noOfBeams;
  final String? remarks;
  final DateTime createdAt;
  final List<WarpingBeamDetail> beams;

  const WarpingPlanDetail({required this.id, required this.warpingId, required this.jobId,
    required this.jobOrderNo, required this.noOfBeams, this.remarks,
    required this.createdAt, required this.beams});

  int get totalEnds => beams.fold(0, (s, b) => s + b.totalEnds);

  factory WarpingPlanDetail.fromJson(Map<String, dynamic> json) {
    final job = json['job'];
    return WarpingPlanDetail(
      id:         json['_id']?.toString() ?? '',
      warpingId:  json['warping'] is Map
          ? (json['warping'] as Map)['_id']?.toString() ?? ''
          : json['warping']?.toString() ?? '',
      jobId:      job is Map ? job['_id']?.toString() ?? '' : job?.toString() ?? '',
      jobOrderNo: job is Map ? (job['jobOrderNo'] as num?)?.toInt() ?? 0 : 0,
      noOfBeams:  (json['noOfBeams'] as num?)?.toInt() ?? 0,
      remarks:    json['remarks']?.toString(),
      createdAt:  DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      beams: (json['beams'] as List? ?? [])
          .map((e) => WarpingBeamDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WarpingBeamDetail {
  final int beamNo;
  final int totalEnds;
  final List<WarpingBeamSectionDetail> sections;
  final int? pairedBeamNo;

  const WarpingBeamDetail({required this.beamNo, required this.totalEnds, required this.sections, this.pairedBeamNo});

  factory WarpingBeamDetail.fromJson(Map<String, dynamic> json) => WarpingBeamDetail(
    beamNo:       (json['beamNo']       as num?)?.toInt() ?? 0,
    totalEnds:    (json['totalEnds']    as num?)?.toInt() ?? 0,
    pairedBeamNo: (json['pairedBeamNo'] as num?)?.toInt(),
    sections: (json['sections'] as List? ?? [])
        .map((e) => WarpingBeamSectionDetail.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'beamNo': beamNo, 'totalEnds': totalEnds,
    'sections': sections.map((s) => s.toJson()).toList(),
    if (pairedBeamNo != null) 'pairedBeamNo': pairedBeamNo,
  };
}

class WarpingBeamSectionDetail {
  final String warpYarnId;
  final String warpYarnName;
  final int ends;
  final double maxMeters;

  const WarpingBeamSectionDetail({required this.warpYarnId, required this.warpYarnName, required this.ends, this.maxMeters = 0});

  factory WarpingBeamSectionDetail.fromJson(Map<String, dynamic> json) {
    final wy = json['warpYarn'];
    return WarpingBeamSectionDetail(
      warpYarnId:   wy is Map ? wy['_id']?.toString()  ?? '' : wy?.toString() ?? '',
      warpYarnName: wy is Map ? wy['name']?.toString() ?? '—' : '—',
      ends:        (json['ends'] as num?)?.toInt() ?? 0,
      maxMeters:   (json['maxMeters'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'warpYarn': warpYarnId, 'ends': ends,
    if (maxMeters > 0) 'maxMeters': maxMeters,
  };
}

// ─── WarpingDetail ────────────────────────────────────────────
// BUG FIXED:
// WarpingDetailModel.fromJson: `plan: json['warpingPlan'] ?? ""`
// After full populate, warpingPlan is a Map. Map ?? "" never evaluates
// to "" since Map is not null. So `plan` always became the Map's .toString()
// "[Instance of ...]" — corrupted planId used for navigation.
class WarpingDetail {
  final String id;
  final String status;
  final DateTime date;
  final DateTime? completedDate;
  final int jobOrderNo;
  final String jobId;
  final String planId;       // empty = no plan
  final bool hasPlan;
  final WarpingPlanDetail? plan;
  final List<ElasticWarpDetail> elastics;

  const WarpingDetail({required this.id, required this.status, required this.date,
    this.completedDate, required this.jobOrderNo, required this.jobId,
    required this.planId, required this.hasPlan, this.plan, required this.elastics});

  factory WarpingDetail.fromJson(Map<String, dynamic> json) {
    final job     = json['job'];
    final rawPlan = json['warpingPlan'];

    // FIX: handle populated Map, bare ObjectId string, or null
    String planId = '';
    WarpingPlanDetail? plan;
    if (rawPlan is Map<String, dynamic>) {
      planId = rawPlan['_id']?.toString() ?? '';
      plan   = WarpingPlanDetail.fromJson(rawPlan);
    } else if (rawPlan is String && rawPlan.isNotEmpty) {
      planId = rawPlan;
    }

    return WarpingDetail(
      id:           json['_id']?.toString()    ?? '',
      status:       json['status']?.toString() ?? 'open',
      date:         DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      completedDate: DateTime.tryParse(json['completedDate']?.toString() ?? ''),
      jobOrderNo:  (job is Map ? job['jobOrderNo'] as num? : null)?.toInt() ?? 0,
      jobId:        job is Map ? job['_id']?.toString() ?? '' : '',
      planId:       planId,
      hasPlan:      planId.isNotEmpty,
      plan:         plan,
      elastics: (json['elasticOrdered'] as List? ?? [])
          .map((e) => ElasticWarpDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── WarpYarnOption (plan creation dropdown) ─────────────────
// BUG FIXED:
// WarpYarnModel.fromJson read json['id'] as ObjectId object → "[object Object]"
// Backend now returns id as String. fromJson handles both.
class WarpYarnOption {
  final String id;
  final String name;
  const WarpYarnOption({required this.id, required this.name});
  factory WarpYarnOption.fromJson(Map<String, dynamic> json) => WarpYarnOption(
    id:   json['id']?.toString()   ?? '',
    name: json['name']?.toString() ?? '—',
  );
}

// ─── Mutable plan entry models (used in create-plan UI) ───────
class EditableBeamSection {
  String? warpYarnId;
  String? warpYarnName;
  int ends;
  double maxMeters; // max length this section can run (optional)
  EditableBeamSection({this.warpYarnId, this.warpYarnName, this.ends = 0, this.maxMeters = 0});
  Map<String, dynamic> toJson() => {
    'warpYarn':  warpYarnId,
    'ends':      ends,
    if (maxMeters > 0) 'maxMeters': maxMeters,
  };
}

class EditableBeam {
  final int beamNo;
  final List<EditableBeamSection> sections;
  int? pairedBeamNo; // set after combine — beamNo of the partner beam
  EditableBeam({required this.beamNo, List<EditableBeamSection>? sections, this.pairedBeamNo})
      : sections = sections ?? [EditableBeamSection()];
  int get totalEnds => sections.fold(0, (s, sec) => s + sec.ends);
  Map<String, dynamic> toJson() => {
    'beamNo': beamNo, 'totalEnds': totalEnds,
    'sections': sections.map((s) => s.toJson()).toList(),
    if (pairedBeamNo != null) 'pairedBeamNo': pairedBeamNo,
  };
}