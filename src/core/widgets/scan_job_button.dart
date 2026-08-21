import 'package:flutter/material.dart';

import '../../features/PurchaseOrder/services/theme.dart';
import '../scan.dart';

// ══════════════════════════════════════════════════════════════
//  "SCAN LABEL" — beside a job picker, never instead of it
//
//  Packing and QC both start by finding a job in a dropdown that can
//  run to a hundred rows, while the label with that job's number is
//  taped to the trolley in front of the person doing it. This removes
//  the transcription.
//
//  ── Generic over the job type on purpose ───────────────────────
//  Packing has PackingJobModel, QC has QcJob, and they share no base
//  class. Rather than a matcher written twice — which is how the two
//  screens would drift into disagreeing about what a scan means — the
//  caller supplies two readers and this owns the whole flow.
//
//  ── The three outcomes are all reported ────────────────────────
//  1. Matched          — selected, and the row is named back so the
//                        person can see it took the right one.
//  2. Read, not in the list — the most important case. A perfectly
//                        good label for a job that is finished, not
//                        yet at this stage, or belongs elsewhere.
//                        Silence here is indistinguishable from a
//                        broken scanner, so it says which job it read
//                        and why it is not offered.
//  3. Not a job label  — handled inside the sheet; the camera keeps
//                        running rather than closing on a carton code.
// ══════════════════════════════════════════════════════════════

class ScanJobButton<T> extends StatelessWidget {
  const ScanJobButton({
    super.key,
    required this.candidates,
    required this.idOf,
    required this.jobNoOf,
    required this.onMatched,
    required this.scopeLabel,
    this.label = 'Scan label',
  });

  /// The jobs currently offered by the picker beside this button.
  final List<T> candidates;

  /// The job's Mongo id — the same id the label's QR encodes.
  final String Function(T) idOf;

  /// The job order number, printed under the code on the label.
  final int Function(T) jobNoOf;

  final void Function(T job) onMatched;

  /// What this picker is showing, for the "read it, but it is not
  /// here" message — e.g. "jobs in packing".
  final String scopeLabel;

  final String label;

  Future<void> _scan(BuildContext context) async {
    final scanned = await scanJobLabel(context);
    if (scanned == null || !context.mounted) return;

    T? hit;
    for (final job in candidates) {
      // The id is the reliable half: it is what the QR carries, and it
      // does not repeat across financial years the way a job number
      // can. The number is the fallback for a hand-typed entry or a
      // label printed before the QR existed.
      if (scanned.id != null &&
          idOf(job).toLowerCase() == scanned.id!.toLowerCase()) {
        hit = job;
        break;
      }
      if (scanned.jobNo != null && jobNoOf(job) == scanned.jobNo) {
        hit = job;
        break;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    if (hit != null) {
      onMatched(hit as T);
      messenger.showSnackBar(SnackBar(
        content: Text('Job #${jobNoOf(hit)} selected'),
        backgroundColor: ErpColors.solidSuccess,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      backgroundColor: ErpColors.solidWarning,
      behavior: SnackBarBehavior.floating,
      content: Text(
        scanned.jobNo != null
            ? 'Job #${scanned.jobNo} was read, but it is not among the '
                '$scopeLabel. It may have moved on, or not reached this '
                'stage yet.'
            : 'That label was read, but the job is not among the '
                '$scopeLabel. It may have moved on, or not reached this '
                'stage yet.',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => _scan(context),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: ErpColors.accentBlue,
          side: BorderSide(color: ErpColors.accentBlue),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        label: Text(label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700)),
      );
}
