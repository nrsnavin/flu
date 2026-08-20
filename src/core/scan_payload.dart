// ══════════════════════════════════════════════════════════════
//  WHAT CAME OFF THE LABEL
//
//  The job label printed from the web carries a URL:
//
//      https://<host>/jobs/<mongo id>
//
//  …and, printed underneath it in 13pt, the job NUMBER — put there on
//  purpose as the thing that survives a smudged code, a flat battery
//  or a camera that will not focus in mill light.
//
//  So a scanner in this app has to cope with more than one string:
//
//    * the label URL, with or without a query or a fragment
//    * a bare Mongo id, if somebody re-encodes one
//    * a bare job number, from a hand-typed fallback or an older
//      label — printed labels predate the QR
//
//  Getting this wrong is quiet. A parser that only understands the
//  URL, handed a bare number, returns nothing and the operator
//  concludes the scanner is broken. One that treats the whole URL as
//  an id matches no job and reports "job not found" for a label that
//  is perfectly good.
//
//  ── Kept free of Flutter on purpose ────────────────────────────
//  This is string handling, and string handling that can only run
//  inside a Flutter engine is string handling nobody tests. See
//  scan_payload_check.dart, which runs on a bare Dart VM.
// ══════════════════════════════════════════════════════════════

/// What a scanned string turned out to be.
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

/// Read whatever the camera saw.
///
/// Returns an empty [ScannedJob] rather than throwing, because a
/// scanner sweeping a shed WILL pick up a stray barcode off a carton
/// and that is not an error worth a dialog — it is a frame to ignore.
ScannedJob parseScannedJob(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return const ScannedJob();

  // The label's own format, first.
  final m = _jobsPath.firstMatch(s);
  if (m != null) return ScannedJob(id: m.group(1));

  if (_objectId.hasMatch(s)) return ScannedJob(id: s);

  // A bare job number. Anchored, so a random 6-digit barcode off a
  // yarn carton does not silently select job 482910 — the caller
  // still has to find a job with that number, and will not.
  final digits = RegExp(r'^#?(\d{1,9})$').firstMatch(s);
  if (digits != null) {
    final n = int.tryParse(digits.group(1)!);
    if (n != null && n > 0) return ScannedJob(jobNo: n);
  }

  // A URL that is not a job label, or anything else at all.
  return const ScannedJob();
}

/// Say why a scan did not select anything, in words an operator can
/// act on rather than "invalid code".
String scanRejectionMessage(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return 'Nothing was read from that code.';
  if (s.startsWith('http')) {
    return 'That is a link, but not a job label. Scan the square code on '
        'the job label.';
  }
  return 'That code is not a job label.';
}
