// ══════════════════════════════════════════════════════════════
//  WHAT A BATCH OF PRODUCTION FIGURES CAME TO
//
//  POST /shift/bulk-enter-production takes the rows it can and hands
//  back the rest with why:
//
//      { saved: 3, skipped: [ { id, reason: "Already closed" }, … ] }
//
//  The two screens that send a batch said "N updated" from how many
//  they SENT. A shift closed meanwhile, a finalised plan or a loom
//  that was loading is skipped by the server, and the screen still
//  said all of them were saved.
// ══════════════════════════════════════════════════════════════

/// What the server did with a batch, in words for a snackbar.
class BulkSaveResult {
  final int saved;
  final List<String> reasons; // one per skipped row
  const BulkSaveResult(this.saved, this.reasons);

  int get skipped => reasons.length;
  bool get partial => reasons.isNotEmpty;

  /// Read the answer. [sent] is how many rows went up: an older server
  /// that says nothing useful is taken at its word that all were saved.
  factory BulkSaveResult.from(dynamic body, int sent) {
    if (body is! Map) return BulkSaveResult(sent, const []);
    final rawSaved = body['saved'];
    final rawSkipped = body['skipped'];
    final reasons = <String>[];
    if (rawSkipped is List) {
      for (final s in rawSkipped) {
        final why = s is Map ? (s['reason'] ?? '').toString().trim() : '';
        reasons.add(why.isEmpty ? 'Not taken' : why);
      }
    }
    final saved = rawSaved is num ? rawSaved.toInt() : sent - reasons.length;
    return BulkSaveResult(saved < 0 ? 0 : saved, reasons);
  }

  /// "3 shifts saved" / "3 shifts saved. 2 not taken: Already closed (2)."
  String message({String one = 'shift', String many = 'shifts'}) {
    final head = '$saved ${saved == 1 ? one : many} saved';
    if (!partial) return head;
    final counts = <String, int>{};
    for (final r in reasons) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final why = counts.entries
        .map((e) => e.value > 1 ? '${e.key} (${e.value})' : e.key)
        .join('; ');
    return '$head. $skipped not taken: $why.';
  }
}
