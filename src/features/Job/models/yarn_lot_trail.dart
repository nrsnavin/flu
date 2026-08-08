// ══════════════════════════════════════════════════════════════
//  THE DYE LOTS A JOB IS COMMITTED TO
//
//  Mirrors GET /job/:jobId/yarn-lots (prod/api/job.js) and the service
//  behind it, services/yarnLotTrail.js.
//
//  A lot enters the record at two different moments, and the difference
//  between them matters more than it looks:
//
//    • PLANNED — the warping programme names the lot each beam section
//      will run off. Written days before anything moves. It can still
//      change, and it carries no quantity: programming names the lot,
//      it does not weigh it.
//    • ISSUED — a warping batch was issued, the cones came off the rack,
//      and the lot's balance moved. This one cannot change.
//
//  They are never folded into a single number here, for that reason.
// ══════════════════════════════════════════════════════════════

double? _dOrNull(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class JobLotRow {
  /// planned · issued
  final String source;

  final String yarnLotId;
  final String lotNo;
  final String shade;
  final String materialName;

  /// open · exhausted · quarantined · closed — only known on a planned
  /// row, where the lot record was populated. A lot quarantined AFTER
  /// programming is exactly the thing the floor needs told.
  final String lotStatus;

  final String batchNo;
  final String batchStatus;
  final List<int> beamNos;

  /// Kg drawn. Null on a planned row, and that null is meaningful —
  /// showing 0 there would claim a measurement nobody made.
  final double? quantity;

  /// Sections of the programme running off this lot (planned rows).
  final int sections;

  /// How many elastics one issued draw is answering for. A batch
  /// covering two elastics drew its yarn once, not twice, so the
  /// quantity is left whole rather than silently divided.
  final int sharedAcross;

  final DateTime? issuedDate;

  const JobLotRow({
    required this.source,
    required this.yarnLotId,
    required this.lotNo,
    required this.shade,
    required this.materialName,
    required this.lotStatus,
    required this.batchNo,
    required this.batchStatus,
    required this.beamNos,
    required this.sections,
    required this.sharedAcross,
    this.quantity,
    this.issuedDate,
  });

  factory JobLotRow.fromJson(Map<String, dynamic> j) => JobLotRow(
        source:       _s(j['source']).isEmpty ? 'planned' : _s(j['source']),
        yarnLotId:    _s(j['yarnLot']),
        lotNo:        _s(j['lotNo']),
        shade:        _s(j['shade']),
        materialName: _s(j['materialName']),
        lotStatus:    _s(j['lotStatus']),
        batchNo:      _s(j['batchNo']),
        batchStatus:  _s(j['batchStatus']),
        beamNos: (j['beamNos'] as List? ?? [])
            .map((e) => (e as num?)?.toInt() ?? 0)
            .toList(),
        quantity:     _dOrNull(j['quantity']),
        sections:     (j['sections'] as num?)?.toInt() ?? 0,
        sharedAcross: (j['sharedAcross'] as num?)?.toInt() ?? 1,
        issuedDate:   _date(j['issuedDate']),
      );

  bool get isIssued => source == 'issued';
  bool get isQuarantined => lotStatus == 'quarantined';

  String get lotLabel => shade.isEmpty ? lotNo : '$lotNo · $shade';

  String get beamLabel =>
      beamNos.isEmpty ? 'No beam named' : 'Beam ${beamNos.join(', ')}';
}

class JobLotGroup {
  /// Null when the batches behind these rows never said which elastic
  /// they were for — reported as job-wide rather than guessed at.
  final String? elasticId;
  final String elasticName;
  final List<JobLotRow> lots;

  const JobLotGroup({
    required this.elasticId,
    required this.elasticName,
    required this.lots,
  });

  factory JobLotGroup.fromJson(Map<String, dynamic> j) => JobLotGroup(
        elasticId: j['elasticId']?.toString(),
        elasticName: _s(j['elasticName']).isEmpty
            ? 'Unknown'
            : _s(j['elasticName']),
        lots: (j['lots'] as List? ?? [])
            .whereType<Map>()
            .map((e) => JobLotRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  List<JobLotRow> get planned => lots.where((l) => !l.isIssued).toList();
  List<JobLotRow> get issued => lots.where((l) => l.isIssued).toList();
}

/// A lot folded down to itself, across every beam and batch it appears
/// in — what somebody chasing a shade complaint wants first.
class DistinctLot {
  final String yarnLotId;
  final String lotNo;
  final String shade;
  final String materialName;

  /// A lot both programmed and issued reports as issued: the yarn is
  /// off the rack, which is the stronger fact.
  final String source;

  const DistinctLot({
    required this.yarnLotId,
    required this.lotNo,
    required this.shade,
    required this.materialName,
    required this.source,
  });

  factory DistinctLot.fromJson(Map<String, dynamic> j) => DistinctLot(
        yarnLotId:    _s(j['yarnLot']),
        lotNo:        _s(j['lotNo']),
        shade:        _s(j['shade']),
        materialName: _s(j['materialName']),
        source:       _s(j['source']).isEmpty ? 'issued' : _s(j['source']),
      );

  String get label => shade.isEmpty ? lotNo : '$lotNo · $shade';
}

class JobLotSections {
  final int total;
  final int withLot;

  /// Sections the programme has left open. Not a fault — an undyed yarn
  /// has no lot, and a plan can be written before the lot is decided —
  /// but it is the difference between "no lot chosen" and "no
  /// programme", which a blank list cannot express.
  final int open;

  const JobLotSections({this.total = 0, this.withLot = 0, this.open = 0});

  factory JobLotSections.fromJson(Map<String, dynamic> j) => JobLotSections(
        total:   (j['total'] as num?)?.toInt() ?? 0,
        withLot: (j['withLot'] as num?)?.toInt() ?? 0,
        open:    (j['open'] as num?)?.toInt() ?? 0,
      );

  bool get hasProgramme => total > 0;
}

class JobYarnLots {
  final List<JobLotGroup> byElastic;
  final List<DistinctLot> lots;
  final JobLotSections sections;
  final List<int> openBeamNos;

  /// Batches exist but none say which elastic they were for, so the
  /// trail is job-wide. Said out loud rather than left to be inferred.
  final bool hasUnattributed;

  const JobYarnLots({
    required this.byElastic,
    required this.lots,
    required this.sections,
    required this.openBeamNos,
    required this.hasUnattributed,
  });

  static const empty = JobYarnLots(
    byElastic: [],
    lots: [],
    sections: JobLotSections(),
    openBeamNos: [],
    hasUnattributed: false,
  );

  factory JobYarnLots.fromJson(Map<String, dynamic> j) => JobYarnLots(
        byElastic: (j['byElastic'] as List? ?? [])
            .whereType<Map>()
            .map((e) => JobLotGroup.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        lots: (j['lots'] as List? ?? [])
            .whereType<Map>()
            .map((e) => DistinctLot.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        sections: j['sections'] is Map
            ? JobLotSections.fromJson(
                Map<String, dynamic>.from(j['sections'] as Map))
            : const JobLotSections(),
        openBeamNos: (j['openBeamNos'] as List? ?? [])
            .map((e) => (e as num?)?.toInt() ?? 0)
            .toList(),
        hasUnattributed: j['hasUnattributed'] == true,
      );

  bool get isEmpty => lots.isEmpty && !sections.hasProgramme;
}
