// ══════════════════════════════════════════════════════════════
//  ONE TAPE'S BUILD, REPEATED
//
//  A warping template describes how ONE tape is built: which beams,
//  which yarns, how many ends. A programme usually runs that same
//  build several times over — eight tapes of the same elastic is an
//  ordinary day — so the beams repeat.
//
//  The phone has had no way to say how many. It filled the template
//  once and left the operator to press "repeat beam" once per beam
//  per tape: for a four-beam template over eight tapes that is
//  twenty-eight taps, each one a chance to lose count. The web has
//  had a tapes field since the template builder was written.
//
//  ── Beam numbers run straight through ──────────────────────────
//  Not restarting per tape. The beam number is how the floor
//  identifies a beam on the rack, and two beam 1s would be two
//  things with one name. Tape 2 of a four-beam template starts at
//  beam 5.
//
//  ── The tape number is not decoration ──────────────────────────
//  Without it the operator sees a flat list of thirty-two beams and
//  cannot tell where one tape ends and the next begins. It is
//  stamped on every beam and stored — models/WarpingPlan.js has
//  carried `tapeNo` since the web gained this, and the phone has
//  been sending plans without it.
//
//  ── What a repeat does NOT carry ───────────────────────────────
//  The lot, and the pairing. A template says how the elastic is
//  built, not which dye lot this run comes off — that is decided
//  against what is actually in stock, per section, later. And a
//  pairing names a specific other beam; copied into tape 2 it would
//  point back at a beam in tape 1.
//
//  ── Kept free of Flutter on purpose ────────────────────────────
//  This is arithmetic over lists, and arithmetic that can only run
//  inside a Flutter engine is arithmetic nobody tests. See
//  tape_repeat_check.dart, which runs on a bare Dart VM.
//
//  Mirrors prod_web WarpingPlanForm.tsx `templateToBeams`.
// ══════════════════════════════════════════════════════════════

/// The most tapes a plan may be repeated to.
///
/// Matches the web's clamp. It is a guard against a typed digit
/// running away — 900 tapes of a four-beam template is 3,600 beams,
/// which is not a programme anybody meant to build.
const int kMaxTapes = 99;

/// One section of a template beam: a yarn, and how much of it.
class TemplateSectionSpec {
  final String? warpYarnId;
  final String warpYarnName;
  final int ends;
  final double maxMeters;

  const TemplateSectionSpec({
    this.warpYarnId,
    this.warpYarnName = '',
    this.ends = 0,
    this.maxMeters = 0,
  });

  factory TemplateSectionSpec.fromJson(Map<String, dynamic> s) =>
      TemplateSectionSpec(
        warpYarnId: s['warpYarnId']?.toString(),
        warpYarnName: s['warpYarnName']?.toString() ?? '',
        ends: (s['ends'] as num?)?.toInt() ?? 0,
        maxMeters: (s['maxMeters'] as num?)?.toDouble() ?? 0,
      );
}

/// One beam of the template — the build for one beam of one tape.
class TemplateBeamSpec {
  /// Which elastic this beam warps, when the template names one.
  ///
  /// The server sends it per beam because a job's merged template
  /// spans several elastics, and a beam belongs to exactly one. The
  /// phone was dropping it, so every beam it planned was filed
  /// against no elastic at all.
  final String? elasticId;
  final String elasticName;
  final List<TemplateSectionSpec> sections;

  const TemplateBeamSpec({
    this.elasticId,
    this.elasticName = '',
    this.sections = const [],
  });

  factory TemplateBeamSpec.fromJson(Map<String, dynamic> b) => TemplateBeamSpec(
        elasticId: b['elasticId']?.toString(),
        elasticName: b['elasticName']?.toString() ?? '',
        sections: (b['sections'] as List? ?? [])
            .whereType<Map>()
            .map((s) =>
                TemplateSectionSpec.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
      );
}

/// One beam of the programme: a template beam, placed in a tape.
class PlannedBeamSpec {
  final int beamNo;
  final int tapeNo;
  final String? elasticId;
  final String elasticName;
  final List<TemplateSectionSpec> sections;

  const PlannedBeamSpec({
    required this.beamNo,
    required this.tapeNo,
    this.elasticId,
    this.elasticName = '',
    this.sections = const [],
  });

  @override
  String toString() => 'Beam $beamNo (tape $tapeNo, ${sections.length} sec)';
}

/// Clamp a requested tape count to something buildable.
///
/// Zero, negative and non-numeric all mean one tape rather than none:
/// a programme with no beams is not a thing the form can show, and
/// silently emptying it while somebody clears the field to retype is
/// how work gets lost.
int clampTapes(int? tapes) {
  final n = tapes ?? 1;
  if (n < 1) return 1;
  if (n > kMaxTapes) return kMaxTapes;
  return n;
}

/// Repeat [template] once per tape, numbering beams straight through.
///
/// Returns an empty list for an empty template rather than inventing a
/// blank beam — the caller knows whether it is prefilling (in which
/// case there is nothing to fill from) or rebuilding.
List<PlannedBeamSpec> repeatTemplatePerTape(
  List<TemplateBeamSpec> template,
  int tapes,
) {
  if (template.isEmpty) return const [];
  final count = clampTapes(tapes);

  final out = <PlannedBeamSpec>[];
  for (var tape = 1; tape <= count; tape++) {
    for (final b in template) {
      out.add(PlannedBeamSpec(
        // Straight through the whole programme, not restarting per
        // tape. See the header.
        beamNo: out.length + 1,
        tapeNo: tape,
        elasticId: b.elasticId,
        elasticName: b.elasticName,
        // Each tape gets its OWN section objects. Sharing them would
        // make editing the ends on tape 3 silently edit tape 1, which
        // is the kind of fault that only shows up on the rack.
        sections: b.sections
            .map((s) => TemplateSectionSpec(
                  warpYarnId: s.warpYarnId,
                  warpYarnName: s.warpYarnName,
                  ends: s.ends,
                  maxMeters: s.maxMeters,
                ))
            .toList(),
      ));
    }
  }
  return out;
}

/// How many beams [tapes] tapes of [template] would come to.
///
/// For the "8 tapes × 4 beams = 32 beams" line on the form, so the
/// operator sees the size of what they are about to build before it
/// is built.
int beamsForTapes(int templateBeamCount, int tapes) =>
    templateBeamCount * clampTapes(tapes);
