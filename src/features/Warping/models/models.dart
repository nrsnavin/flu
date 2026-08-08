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

  /// The dye lot this section is programmed to run off, if one was
  /// chosen. Empty is not an error — an undyed yarn has no lot, and a
  /// programme can be written before the lot is decided.
  final String yarnLotId;
  final String lotNo;
  final String shade;

  const WarpingBeamSectionDetail({
    required this.warpYarnId,
    required this.warpYarnName,
    required this.ends,
    this.maxMeters = 0,
    this.yarnLotId = '',
    this.lotNo = '',
    this.shade = '',
  });

  factory WarpingBeamSectionDetail.fromJson(Map<String, dynamic> json) {
    final wy = json['warpYarn'];
    final lot = json['yarnLot'];
    return WarpingBeamSectionDetail(
      warpYarnId:   wy is Map ? wy['_id']?.toString()  ?? '' : wy?.toString() ?? '',
      warpYarnName: wy is Map ? wy['name']?.toString() ?? '—' : '—',
      ends:        (json['ends'] as num?)?.toInt() ?? 0,
      maxMeters:   (json['maxMeters'] as num?)?.toDouble() ?? 0,
      yarnLotId:    lot is Map ? lot['_id']?.toString() ?? '' : lot?.toString() ?? '',
      // Prefer the snapshot the server stamped on the section: it is what
      // the programme sheet printed, and it outlives the lot record.
      lotNo:        json['lotNo']?.toString().isNotEmpty == true
          ? json['lotNo'].toString()
          : (lot is Map ? lot['lotNo']?.toString() ?? '' : ''),
      shade:        json['shade']?.toString().isNotEmpty == true
          ? json['shade'].toString()
          : (lot is Map ? lot['shade']?.toString() ?? '' : ''),
    );
  }

  bool get hasLot => lotNo.isNotEmpty || yarnLotId.isNotEmpty;

  String get lotLabel {
    if (!hasLot) return '';
    return shade.isEmpty ? lotNo : '$lotNo · $shade';
  }

  Map<String, dynamic> toJson() => {
    'warpYarn': warpYarnId, 'ends': ends,
    if (maxMeters > 0) 'maxMeters': maxMeters,
    if (yarnLotId.isNotEmpty) 'yarnLot': yarnLotId,
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

// ─── Lot-wise stock, for programming a beam ──────────────────
//
// Aggregate stock cannot answer the question a planner is actually
// asking. 300 kg spread over six lots of 50 is a very different thing
// from 300 kg on one lot, because two lots meeting inside a single beam
// show up as a shade band on the tape. So both numbers are carried:
// what there is altogether, and what the biggest single lot holds.

class LotOption {
  final String id;
  final String lotNo;
  final String shade;
  final double balance;

  const LotOption({
    required this.id,
    required this.lotNo,
    required this.shade,
    required this.balance,
  });

  factory LotOption.fromJson(Map<String, dynamic> json) => LotOption(
    id:      json['id']?.toString() ?? '',
    lotNo:   json['lotNo']?.toString() ?? '',
    shade:   json['shade']?.toString() ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
  );

  String get label => shade.isEmpty ? lotNo : '$lotNo · $shade';
}

class YarnLotStock {
  final String warpYarnId;
  final String warpYarnName;
  final List<LotOption> lots;
  final double totalAvailable;
  final double largestLot;

  const YarnLotStock({
    required this.warpYarnId,
    required this.warpYarnName,
    required this.lots,
    required this.totalAvailable,
    required this.largestLot,
  });

  static const empty = YarnLotStock(
    warpYarnId: '', warpYarnName: '', lots: [],
    totalAvailable: 0, largestLot: 0,
  );

  factory YarnLotStock.fromJson(Map<String, dynamic> json) => YarnLotStock(
    warpYarnId:     json['warpYarnId']?.toString() ?? '',
    warpYarnName:   json['warpYarnName']?.toString() ?? '',
    lots: (json['lots'] as List? ?? [])
        .whereType<Map>()
        .map((e) => LotOption.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    totalAvailable: (json['totalAvailable'] as num?)?.toDouble() ?? 0,
    largestLot:     (json['largestLot'] as num?)?.toDouble() ?? 0,
  );

  bool get isEmpty => lots.isEmpty;
}

// ─── Mutable plan entry models (used in create-plan UI) ───────
class EditableBeamSection {
  String? warpYarnId;
  String? warpYarnName;
  int ends;
  double maxMeters; // max length this section can run (optional)

  /// Chosen dye lot, or null for "not decided / no lot". Sent as
  /// `yarnLot`; the server refuses a lot belonging to another yarn, so
  /// this is cleared whenever the yarn on the section changes.
  String? yarnLotId;
  String? lotLabel;

  EditableBeamSection({
    this.warpYarnId,
    this.warpYarnName,
    this.ends = 0,
    this.maxMeters = 0,
    this.yarnLotId,
    this.lotLabel,
  });

  Map<String, dynamic> toJson() => {
    'warpYarn':  warpYarnId,
    'ends':      ends,
    if (maxMeters > 0) 'maxMeters': maxMeters,
    // Omitted rather than sent as "" — an empty string is not an
    // ObjectId, and the whole plan used to be rejected for it.
    if (yarnLotId != null && yarnLotId!.isNotEmpty) 'yarnLot': yarnLotId,
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
// ═════════════════════════════════════════════════════════════
//  WARPING BATCHES — what actually came off the rack
//
//  The plan says what to build; a batch says which lots were drawn to
//  build it, and when. One plan is routinely run over several sittings
//  from different lots — beams 1–4 today, beams 5–8 next week — which
//  is exactly what makes the lot worth recording separately.
//
//  Mirrors models/WarpingBatch.js.
// ═════════════════════════════════════════════════════════════

const kBatchStatuses = ['planned', 'issued', 'completed', 'cancelled'];

String batchStatusLabel(String s) {
  switch (s) {
    case 'planned':   return 'Planned';
    case 'issued':    return 'Issued';
    case 'completed': return 'Completed';
    case 'cancelled': return 'Cancelled';
    default:          return s;
  }
}

class BatchAllocation {
  final String rawMaterialId;
  final String yarnLotId;
  final String lotNo;
  final String shade;
  final String materialName;
  final double quantity;

  const BatchAllocation({
    required this.rawMaterialId,
    required this.yarnLotId,
    required this.lotNo,
    required this.shade,
    required this.materialName,
    required this.quantity,
  });

  factory BatchAllocation.fromJson(Map<String, dynamic> json) {
    final lot = json['yarnLot'];
    final mat = json['rawMaterial'];
    return BatchAllocation(
      rawMaterialId: mat is Map ? mat['_id']?.toString() ?? '' : mat?.toString() ?? '',
      yarnLotId:     lot is Map ? lot['_id']?.toString() ?? '' : lot?.toString() ?? '',
      // Snapshots first — the lot record can be renamed or archived long
      // before anyone comes asking about a shade complaint.
      lotNo: json['lotNo']?.toString().isNotEmpty == true
          ? json['lotNo'].toString()
          : (lot is Map ? lot['lotNo']?.toString() ?? '' : ''),
      shade: json['shade']?.toString().isNotEmpty == true
          ? json['shade'].toString()
          : (lot is Map ? lot['shade']?.toString() ?? '' : ''),
      materialName: json['materialName']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'rawMaterial': rawMaterialId,
    'yarnLot':     yarnLotId,
    'quantity':    quantity,
  };

  String get lotLabel => shade.isEmpty ? lotNo : '$lotNo · $shade';
}

class WarpingBatchModel {
  final String id;
  final String batchNo;
  final String status;
  final List<int> beamNos;
  final List<String> elasticNames;
  final List<BatchAllocation> allocations;
  final String machineId;
  final String remarks;
  final DateTime? issuedDate;
  final DateTime? completedDate;
  final DateTime? createdAt;

  const WarpingBatchModel({
    required this.id,
    required this.batchNo,
    required this.status,
    required this.beamNos,
    required this.elasticNames,
    required this.allocations,
    required this.machineId,
    required this.remarks,
    this.issuedDate,
    this.completedDate,
    this.createdAt,
  });

  factory WarpingBatchModel.fromJson(Map<String, dynamic> json) {
    final machine = json['machine'];
    return WarpingBatchModel(
      id:      json['_id']?.toString() ?? '',
      batchNo: json['batchNo']?.toString() ?? '',
      status:  json['status']?.toString() ?? 'planned',
      beamNos: (json['beamNos'] as List? ?? [])
          .map((e) => (e as num?)?.toInt() ?? 0)
          .toList(),
      elasticNames: (json['elastics'] as List? ?? [])
          .map((e) => e is Map ? e['name']?.toString() ?? '' : '')
          .where((n) => n.isNotEmpty)
          .toList(),
      allocations: (json['allocations'] as List? ?? [])
          .whereType<Map>()
          .map((e) => BatchAllocation.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      machineId: machine is Map ? machine['_id']?.toString() ?? '' : machine?.toString() ?? '',
      remarks:   json['remarks']?.toString() ?? '',
      issuedDate:    DateTime.tryParse(json['issuedDate']?.toString() ?? '')?.toLocal(),
      completedDate: DateTime.tryParse(json['completedDate']?.toString() ?? '')?.toLocal(),
      createdAt:     DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
    );
  }

  double get totalQty => allocations.fold(0.0, (s, a) => s + a.quantity);

  bool get canIssue    => status == 'planned';
  bool get canComplete => status == 'issued';
  bool get canCancel   => status == 'planned' || status == 'issued';

  /// "Beams 1, 2, 5" — or an honest blank when the batch names none.
  String get beamLabel =>
      beamNos.isEmpty ? 'No beams named' : 'Beam ${beamNos.join(', ')}';
}
