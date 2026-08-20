// ══════════════════════════════════════════════════════════════
//  WHAT CAME OFF THE LABEL
//
//  The mill prints five kinds of label, and they do not share a
//  format. These are the exact strings the system encodes — four from
//  the web (prod_web JobQrPrint.tsx, PackingSlip.tsx,
//  CoveringLabels.tsx, WarpingPrints.tsx) and one from the server's
//  own PDF renderer (prod utils/shiftSheetPdf.js):
//
//    job       https://<host>/jobs/<mongo id>
//    box       BOX|<packing id>|J:<job no>
//    covering  COVB|J:<job no>|C:<covering id>|B:<beam>|E:<entry id>
//    warping   WARP|J:<job no>|B:<beam>[|T:<tape>]|W:<warping id>
//    shift     SHIFTROW|<shift detail id>|M:<machine>|J:<job no>
//
//  ── `J:` does not mean the same thing twice ────────────────────
//  On the beam labels it is a bare number, `J:1042`. On the shift
//  row it is the printed job LABEL, `J:J-1042`, because that column
//  is meant to be read. Only the beam labels parse it.
//
//  …plus, printed under the job code in 13pt, the job NUMBER — put
//  there on purpose as the thing that survives a smudged code, a flat
//  battery or a camera that will not focus in mill light.
//
//  ── The em-dash ────────────────────────────────────────────────
//  The three pipe formats build `J:` from `warping.job?.jobOrderNo ??
//  "—"`. When the job is not populated the label really does carry
//  `J:—`. That is not a number and must not be coerced into one:
//  int.tryParse returns null, so a naive `int.parse` would throw and
//  a naive `?? 0` would send the operator to job zero. It is read as
//  "this label names no job", which is the truth.
//
//  ── Getting this wrong is quiet ────────────────────────────────
//  A parser that only understands the job URL, handed a box label,
//  returns nothing and the operator concludes the scanner is broken.
//  One that treats a whole URL as an id matches no job and reports
//  "not found" for a label that is perfectly good.
//
//  ── Kept free of Flutter on purpose ────────────────────────────
//  This is string handling, and string handling that can only run
//  inside a Flutter engine is string handling nobody tests. See
//  scan_payload_check.dart, which runs on a bare Dart VM.
// ══════════════════════════════════════════════════════════════

/// Which screen a scanned code wants to open.
enum ScanTarget {
  /// A job label, or a beam label that names its job.
  job,

  /// A packing box label.
  packing,

  /// One row of a printed shift sheet — a machine, an operator and a
  /// job for one shift.
  shift,

  /// Read cleanly, but not one of ours.
  unknown,
}

/// What a scanned string turned out to be.
///
/// [id] is the id of the TARGET — a job id for [ScanTarget.job], a
/// packing record id for [ScanTarget.packing]. When it is null the
/// caller has to resolve [jobNo] into one, which is a round trip; the
/// two are deliberately separate so a caller can tell the cheap case
/// from the expensive one instead of always paying for the lookup.
class ScannedCode {
  final ScanTarget target;

  /// The target's Mongo ObjectId, when the payload carried one.
  final String? id;

  /// A job order number, when the payload named a job by number.
  /// Set alongside [id] on the beam labels, which carry both.
  final int? jobNo;

  /// What kind of label this was, for the message shown after a scan
  /// that leads somewhere unexpected. One of `job`, `box`, `covering`,
  /// `warping`, or null when nothing matched.
  final String? label;

  const ScannedCode({
    this.target = ScanTarget.unknown,
    this.id,
    this.jobNo,
    this.label,
  });

  /// Nothing usable came off the label.
  bool get isEmpty => id == null && jobNo == null;

  /// Enough to open a screen without asking the server anything.
  bool get isDirect => id != null;

  @override
  String toString() =>
      'ScannedCode(${target.name}, id: $id, jobNo: $jobNo, label: $label)';
}

/// What a scanned string turned out to be, when only jobs mattered.
///
/// Kept because the packing, QC and delivery-challan job pickers were
/// written against it and have their own tests. It is now a narrowed
/// view of [ScannedCode] rather than a second parser — two parsers
/// reading the same labels is how the two drift apart.
class ScannedJob {
  /// A Mongo ObjectId, when the payload carried one.
  final String? id;

  /// A job order number, when the payload was one.
  final int? jobNo;

  const ScannedJob({this.id, this.jobNo});

  bool get isEmpty => id == null && jobNo == null;

  @override
  String toString() => 'ScannedJob(id: $id, jobNo: $jobNo)';
}

final _objectId = RegExp(r'^[0-9a-fA-F]{24}$');

/// A URL path segment that looks like an id, after `/jobs/`.
final _jobsPath = RegExp(r'/jobs/([0-9a-fA-F]{24})(?:[/?#]|$)');

/// A bare job number, with or without a leading hash.
final _bareNumber = RegExp(r'^#?(\d{1,9})$');

/// The shift sheet's human-readable row code, `SD-A3F291`.
/// See utils/shiftSheetPdf.js `shortCode`.
final _shortCode = RegExp(r'^SD-[0-9A-Fa-f]{1,6}$');

/// Pull `K:value` out of a pipe-delimited label.
///
/// Returns null when the key is absent, when its value is empty, or
/// when the value is the em-dash the web writes for an unpopulated
/// job. Callers must not distinguish those three: all mean "the label
/// does not tell us".
String? _field(List<String> parts, String key) {
  final prefix = '$key:';
  for (final p in parts) {
    if (!p.startsWith(prefix)) continue;
    final v = p.substring(prefix.length).trim();
    if (v.isEmpty || v == '—' || v == '-') return null;
    return v;
  }
  return null;
}

/// The same, parsed as a positive integer, or null if it is not one.
int? _fieldNo(List<String> parts, String key) {
  final v = _field(parts, key);
  if (v == null) return null;
  final n = int.tryParse(v);
  return (n != null && n > 0) ? n : null;
}

/// Read whatever the camera saw.
///
/// Returns an empty [ScannedCode] rather than throwing, because a
/// scanner sweeping a shed WILL pick up a stray barcode off a carton
/// and that is not an error worth a dialog — it is a frame to ignore.
ScannedCode parseScannedCode(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return const ScannedCode();

  // ── The pipe formats ─────────────────────────────────────────
  if (s.contains('|')) {
    final parts = s.split('|').map((p) => p.trim()).toList();
    final head = parts.first.toUpperCase();

    switch (head) {
      case 'BOX':
        // BOX|<packing id>|J:<job no>. The packing id is positional —
        // it is the only field on any of these labels that is not
        // K:value — so it is read by position, and only accepted when
        // it actually looks like an id.
        final boxId = parts.length > 1 && _objectId.hasMatch(parts[1])
            ? parts[1]
            : null;
        final jobNo = _fieldNo(parts, 'J');
        if (boxId == null && jobNo == null) {
          // A BOX label with neither is a corrupt label, not a box.
          return const ScannedCode(label: 'box');
        }
        return ScannedCode(
          target: ScanTarget.packing,
          id: boxId,
          jobNo: jobNo,
          label: 'box',
        );

      case 'SHIFTROW':
        // One row of the printed shift sheet:
        //   SHIFTROW|<shift detail id>|M:<machine ID>|J:<job no>
        // …written by utils/shiftSheetPdf.js, whose own comment says
        // it encodes the full id "for a future scanner". This is it.
        //
        // The id is positional, like BOX. `M:` and `J:` are on the
        // label so a person can read the row without the system, and
        // are deliberately NOT parsed: `J:` here carries a PREFIXED
        // number ("J-1042", not "1042"), unlike the beam labels, so
        // running it through _fieldNo would quietly yield nothing and
        // invite somebody to "fix" it later.
        final sdId = parts.length > 1 && _objectId.hasMatch(parts[1])
            ? parts[1]
            : null;
        if (sdId == null) return const ScannedCode(label: 'shift');
        return ScannedCode(
          target: ScanTarget.shift,
          id: sdId,
          label: 'shift',
        );

      case 'COVB':
        // A covering beam. It names its job by NUMBER only, so there
        // is nothing to open without a lookup.
        return ScannedCode(
          target: ScanTarget.job,
          jobNo: _fieldNo(parts, 'J'),
          label: 'covering',
        );

      case 'WARP':
        return ScannedCode(
          target: ScanTarget.job,
          jobNo: _fieldNo(parts, 'J'),
          label: 'warping',
        );
    }

    // Some other pipe-delimited code. Not ours.
    return const ScannedCode();
  }

  // ── The job label's own format ───────────────────────────────
  final m = _jobsPath.firstMatch(s);
  if (m != null) {
    return ScannedCode(
      target: ScanTarget.job,
      id: m.group(1),
      label: 'job',
    );
  }

  // A bare id. No printed label carries one — every label this system
  // prints is either the job URL or a pipe format — so this exists
  // only for a re-encoded code or a hand-built one. It is read as a
  // job because that is the only thing anyone has ever encoded this
  // way; a bare id is genuinely ambiguous between collections and
  // there is nothing in the string to settle it.
  if (_objectId.hasMatch(s)) {
    return ScannedCode(target: ScanTarget.job, id: s, label: 'job');
  }

  // A bare job number. Anchored, so a random 6-digit barcode off a
  // yarn carton does not silently select job 482910 — the caller
  // still has to find a job with that number, and will not.
  final digits = _bareNumber.firstMatch(s);
  if (digits != null) {
    final n = int.tryParse(digits.group(1)!);
    if (n != null && n > 0) {
      return ScannedCode(target: ScanTarget.job, jobNo: n, label: 'job');
    }
  }

  // The short code printed in the Code column of the shift sheet —
  // `SD-A3F291`, the last six hex of the row's id, upper-cased. It is
  // there for a person to read out, NOT to identify a row: six hex
  // characters is 16 million values against an id space where
  // collisions are ordinary, so resolving it would eventually open
  // somebody else's shift. Recognised only so it can say so.
  if (_shortCode.hasMatch(s)) {
    return const ScannedCode(label: 'shift-code');
  }

  // A URL that is not a job label, or anything else at all.
  return const ScannedCode();
}

/// Read a scanned string, keeping only what names a job.
///
/// A box label names its job by number, so it resolves here too — the
/// operator holding a carton at the packing bench has scanned a real
/// job, and refusing it because the label says BOX would be pedantry.
ScannedJob parseScannedJob(String? raw) {
  final c = parseScannedCode(raw);
  if (c.target == ScanTarget.job) {
    return ScannedJob(id: c.id, jobNo: c.jobNo);
  }
  if (c.target == ScanTarget.packing && c.jobNo != null) {
    // The box's own id is not a job id and must not be passed off as
    // one; only the job number crosses over.
    return ScannedJob(jobNo: c.jobNo);
  }
  return const ScannedJob();
}

/// Say why a parsed code leads nowhere, in words an operator can act
/// on rather than "invalid code".
///
/// Takes the PARSED code rather than the raw string, so a caller that
/// has already parsed does not parse again — and, more to the point,
/// so the two callers cannot drift into giving different reasons for
/// the same label. [wasLink] covers the one case the parsed form
/// throws away: whether the raw text was a URL.
String scanCodeMessage(ScannedCode c, {bool wasLink = false}) {
  // A label we recognise that carries nothing usable is a different
  // problem from a label we do not recognise, and saying so is the
  // difference between "reprint this" and "you scanned the wrong
  // thing".
  switch (c.label) {
    case 'box':
      return 'That is a packing label, but it does not name a box or a job. '
          'It needs reprinting.';
    case 'shift':
      return 'That is a shift sheet row, but its code is damaged. Scan '
          'another row, or open the shift from the list.';
    case 'shift-code':
      return 'That is the short code printed for reading aloud, not for '
          'scanning. Scan the square code in the QR column beside it.';
    case 'covering':
    case 'warping':
      return 'That ${c.label} label was printed before its job was linked, '
          'so it does not name one. Pick the job from the list.';
  }
  if (wasLink) {
    return 'That is a link, but not a job label. Scan the square code on '
        'the job label.';
  }
  return 'That code is not one of ours.';
}

/// The same, from the raw string the camera read.
String scanRejectionMessage(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return 'Nothing was read from that code.';
  return scanCodeMessage(parseScannedCode(s), wasLink: s.startsWith('http'));
}
