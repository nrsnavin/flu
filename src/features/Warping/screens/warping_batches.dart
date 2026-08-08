import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/controllers.dart';
import '../models/models.dart';

// ══════════════════════════════════════════════════════════════
//  WARPING BATCHES
//
//  The plan says what to build. A batch says which dye lots were
//  actually drawn to build which beams, and when. They are kept apart
//  because one plan is routinely run over several sittings — beams 1–4
//  today off lot D-4471, beams 5–8 next week off whatever is open then
//  — and that difference is the whole reason lots are tracked.
//
//  Issuing a batch moves lot balances and deliberately leaves the raw
//  material's aggregate stock alone; that was debited at order
//  approval. So the sum of lot balances is a floor on the yarn present,
//  never the whole of it, and the two are not expected to agree.
// ══════════════════════════════════════════════════════════════

const _purple = Color(0xFF7C3AED);

/// Whole numbers stay whole — "40 kg", not "40.0 kg".
String _qty(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

Color _batchColor(String status) {
  switch (status) {
    case 'planned':   return ErpColors.accentBlue;
    case 'issued':    return _purple;
    case 'completed': return ErpColors.successGreen;
    case 'cancelled': return ErpColors.errorRed;
    default:          return ErpColors.textSecondary;
  }
}

void _snack(String msg, {required bool isError}) => Get.snackbar(
      isError ? 'Error' : 'Success',
      msg,
      backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );

// ══════════════════════════════════════════════════════════════
//  BATCHES TAB
// ══════════════════════════════════════════════════════════════
class WarpingBatchesTab extends StatefulWidget {
  final String warpingId;
  final String jobId;

  /// open · in_progress · completed · cancelled — a batch can only be
  /// raised while the beams are still on the machine.
  final String warpingStatus;

  const WarpingBatchesTab({
    super.key,
    required this.warpingId,
    required this.jobId,
    required this.warpingStatus,
  });

  @override
  State<WarpingBatchesTab> createState() => _WarpingBatchesTabState();
}

class _WarpingBatchesTabState extends State<WarpingBatchesTab> {
  late final WarpingBatchController c;

  bool get _canRaise =>
      widget.warpingStatus == 'open' || widget.warpingStatus == 'in_progress';

  @override
  void initState() {
    super.initState();
    // Tagged by warping so two detail pages in the back stack do not
    // share one controller — Get.put in build() was the original sin
    // on this screen and is not repeated here.
    Get.delete<WarpingBatchController>(tag: widget.warpingId, force: true);
    c = Get.put(
      WarpingBatchController(warpingId: widget.warpingId, jobId: widget.jobId),
      tag: widget.warpingId,
    );
  }

  @override
  void dispose() {
    Get.delete<WarpingBatchController>(tag: widget.warpingId, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value && c.batches.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }

      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
          children: [
            if (c.errorMsg.value != null) ...[
              _Banner(c.errorMsg.value!, ErpColors.errorRed, Icons.error_outline),
              const SizedBox(height: 10),
            ],

            if (_canRaise) ...[
              _RaiseButton(c: c, onDone: () => setState(() {})),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Banner(
                  'Warping is ${widget.warpingStatus.replaceAll('_', ' ')} — '
                  'no further batches can be raised against it',
                  ErpColors.textMuted,
                  Icons.lock_outline,
                ),
              ),

            if (c.batches.isEmpty)
              const _EmptyBatches()
            else
              ...c.batches.map((b) => _BatchCard(c: c, batch: b)),
          ],
        ),
      );
    });
  }
}

class _RaiseButton extends StatelessWidget {
  final WarpingBatchController c;
  final VoidCallback onDone;
  const _RaiseButton({required this.c, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final free = c.freeBeamNos;
    final noPlan = c.planBeamNos.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              disabledBackgroundColor: _purple.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: (noPlan || c.isActing.value)
                ? null
                : () async {
                    final created = await Get.bottomSheet<bool>(
                      _RaiseBatchSheet(c: c),
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                    );
                    if (created == true) onDone();
                  },
            icon: const Icon(Icons.playlist_add_rounded,
                size: 18, color: Colors.white),
            label: const Text('Raise a batch',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          noPlan
              ? 'Create a warping plan first — a batch is raised against its beams.'
              : free.isEmpty
                  ? 'Every beam in the plan is already on a batch.'
                  : 'Beam ${free.join(', ')} still free.',
          style: const TextStyle(fontSize: 10.5, color: ErpColors.textMuted),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  BATCH CARD
// ══════════════════════════════════════════════════════════════
class _BatchCard extends StatelessWidget {
  final WarpingBatchController c;
  final WarpingBatchModel batch;
  const _BatchCard({required this.c, required this.batch});

  @override
  Widget build(BuildContext context) {
    final color = _batchColor(batch.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(batch.batchNo,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: ErpColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(batch.beamLabel,
                      style: const TextStyle(
                          fontSize: 11, color: ErpColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.45)),
              ),
              child: Text(batchStatusLabel(batch.status),
                  style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),

        // ── Which lots were drawn ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LOTS DRAWN',
                  style: TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              ...batch.allocations.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: _purple, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.lotLabel.isEmpty ? '—' : a.lotLabel,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ErpColors.textPrimary)),
                            if (a.materialName.isNotEmpty)
                              Text(a.materialName,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: ErpColors.textMuted)),
                          ],
                        ),
                      ),
                      Text('${_qty(a.quantity)} kg',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: ErpColors.accentBlue)),
                    ]),
                  )),
              if (batch.allocations.isEmpty)
                const Text('No lots recorded',
                    style:
                        TextStyle(fontSize: 11, color: ErpColors.textMuted)),
            ],
          ),
        ),

        // ── Facts worth carrying ───────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Wrap(spacing: 14, runSpacing: 4, children: [
            _Fact(Icons.scale_outlined, 'Total ${_qty(batch.totalQty)} kg'),
            if (batch.elasticNames.isNotEmpty)
              _Fact(Icons.local_offer_outlined,
                  batch.elasticNames.join(', ')),
            if (batch.issuedDate != null)
              _Fact(Icons.output_rounded,
                  'Issued ${DateFormat('dd MMM').format(batch.issuedDate!)}'),
            if (batch.completedDate != null)
              _Fact(Icons.check_circle_outline,
                  'Done ${DateFormat('dd MMM').format(batch.completedDate!)}'),
          ]),
        ),

        if (batch.remarks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(batch.remarks,
                style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: ErpColors.textSecondary)),
          ),

        // ── Actions ────────────────────────────────────────
        if (batch.canIssue || batch.canComplete || batch.canCancel)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              if (batch.canIssue)
                Expanded(
                  child: _SmallButton(
                    label: 'Issue yarn',
                    icon: Icons.output_rounded,
                    color: _purple,
                    busy: c.isActing.value,
                    onTap: () => _confirm(
                      context,
                      'Issue ${batch.batchNo}',
                      'Draws ${_qty(batch.totalQty)} kg off the named lots and '
                          'moves their balances. This is recorded against the job.',
                      () => c.issue(batch.id),
                    ),
                  ),
                ),
              if (batch.canComplete)
                Expanded(
                  child: _SmallButton(
                    label: 'Complete',
                    icon: Icons.check_rounded,
                    color: ErpColors.successGreen,
                    busy: c.isActing.value,
                    onTap: () => _confirm(
                      context,
                      'Complete ${batch.batchNo}',
                      'Mark these beams as warped?',
                      () => c.complete(batch.id),
                    ),
                  ),
                ),
              if (batch.canCancel) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallButton(
                    label: 'Cancel',
                    icon: Icons.undo_rounded,
                    color: ErpColors.errorRed,
                    outlined: true,
                    busy: c.isActing.value,
                    onTap: () => _confirm(
                      context,
                      'Cancel ${batch.batchNo}',
                      batch.status == 'issued'
                          ? 'The yarn already drawn goes back onto the lots it '
                              'came from, and the beams are released.'
                          : 'Releases the beams so another batch can claim them.',
                      () => c.cancel(batch.id),
                    ),
                  ),
                ),
              ],
            ]),
          ),
      ]),
    );
  }

  Future<void> _confirm(BuildContext ctx, String title, String msg,
      Future<String?> Function() action) async {
    // Await the choice and let the dialog close before the action runs,
    // so the snackbar has a single overlay to land on instead of racing
    // the dialog teardown.
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Get.back<bool>(result: false),
              child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Confirm'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
    if (ok != true) return;
    final err = await action();
    _snack(err ?? 'Batch updated', isError: err != null);
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Fact(this.icon, this.label);

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: ErpColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600)),
      ]);
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final bool outlined;
  final VoidCallback onTap;
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: outlined ? color : Colors.white))
        : Icon(icon, size: 14, color: outlined ? color : Colors.white);

    final text = Text(label,
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: outlined ? color : Colors.white));

    return SizedBox(
      height: 36,
      child: outlined
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: busy ? null : onTap,
              icon: child,
              label: text,
            )
          : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: busy ? null : onTap,
              icon: child,
              label: text,
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  RAISE A BATCH
//
//  Three questions, in the order they are actually answered on the
//  floor: which beams, off which lots, and how much of each.
// ══════════════════════════════════════════════════════════════
class _RaiseBatchSheet extends StatefulWidget {
  final WarpingBatchController c;
  const _RaiseBatchSheet({required this.c});

  @override
  State<_RaiseBatchSheet> createState() => _RaiseBatchSheetState();
}

class _AllocRow {
  String? yarnId;
  String? lotId;
  final qty = TextEditingController();

  void dispose() => qty.dispose();

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;
  bool get filled =>
      (yarnId ?? '').isNotEmpty && (lotId ?? '').isNotEmpty && quantity > 0;
}

class _RaiseBatchSheetState extends State<_RaiseBatchSheet> {
  final _selected = <int>{};
  final _rows = <_AllocRow>[_AllocRow()];
  final _remarks = TextEditingController();
  bool _saving = false;

  WarpingBatchController get c => widget.c;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _remarks.dispose();
    super.dispose();
  }

  /// The same lot twice in one batch would draw it down twice for a
  /// single physical issue. The server refuses it; saying so here saves
  /// the round trip and names the line at fault.
  String? get _problem {
    final filled = _rows.where((r) => r.filled).toList();
    if (filled.isEmpty) return 'Add at least one lot';
    final seen = <String>{};
    for (final r in filled) {
      if (!seen.add(r.lotId!)) {
        return 'The same lot is on two lines — combine them';
      }
    }
    for (final r in filled) {
      final stock = c.lotsFor(r.yarnId!);
      final lot = stock.lots.firstWhereOrNull((l) => l.id == r.lotId);
      if (lot != null && r.quantity > lot.balance) {
        return 'Lot ${lot.lotNo} has only ${_qty(lot.balance)} kg left';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _problem;
    if (problem != null) {
      _snack(problem, isError: true);
      return;
    }
    setState(() => _saving = true);
    final err = await c.create(
      beamNos: _selected.toList()..sort(),
      allocations: _rows
          .where((r) => r.filled)
          .map((r) => BatchAllocation(
                rawMaterialId: r.yarnId!,
                yarnLotId: r.lotId!,
                lotNo: '',
                shade: '',
                materialName: '',
                quantity: r.quantity,
              ))
          .toList(),
      remarks: _remarks.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      _snack(err, isError: true);
      return;
    }
    _snack('Batch raised', isError: false);
    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final free = c.freeBeamNos;
    final claimed = c.claimedBeams;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: ErpColors.bgBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Grab handle + title
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: ErpColors.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 10),
            Row(children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raise a warping batch',
                        style: ErpTextStyles.pageTitle),
                    Text('Which beams, off which lots',
                        style: TextStyle(
                            color: ErpColors.textOnDarkSub, fontSize: 10)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => Get.back(result: false),
              ),
            ]),
          ]),
        ),

        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: [
              // ── Beams ─────────────────────────────────
              ErpSectionCard(
                title: 'BEAMS ON THIS BATCH',
                icon: Icons.table_rows_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.planBeamNos.isEmpty)
                      const Text('The plan defines no beams.',
                          style: TextStyle(
                              fontSize: 11, color: ErpColors.textMuted))
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: c.planBeamNos.map((n) {
                          final taken = claimed[n];
                          final on = _selected.contains(n);
                          return ChoiceChip(
                            label: Text(
                              taken == null ? 'Beam $n' : 'Beam $n · $taken',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: taken != null
                                    ? ErpColors.textMuted
                                    : on
                                        ? _purple
                                        : ErpColors.textSecondary,
                              ),
                            ),
                            selected: on,
                            // A beam already on a live batch cannot be
                            // claimed again: that would issue the yarn
                            // twice for it, and put two lots inside one
                            // beam — the exact thing lots exist to rule out.
                            onSelected: taken != null
                                ? null
                                : (v) => setState(() {
                                      v ? _selected.add(n) : _selected.remove(n);
                                    }),
                            backgroundColor: ErpColors.bgMuted,
                            selectedColor: _purple.withOpacity(0.12),
                            side: BorderSide(
                                color: on ? _purple : ErpColors.borderLight),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      free.isEmpty
                          ? 'Every beam is already on a batch. A batch with no beams is still allowed — it records the draw without claiming any.'
                          : 'Leaving this empty records the draw without claiming a beam.',
                      style: const TextStyle(
                          fontSize: 10, color: ErpColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Allocations ───────────────────────────
              ErpSectionCard(
                title: 'LOTS DRAWN',
                icon: Icons.science_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // True whether the context failed or is still in
                    // flight — either way there is nothing to pick from,
                    // and saying "could not load" would be a guess.
                    if (c.warpYarns.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No warp yarns loaded for this job yet. Close this sheet, pull to refresh, and try again.',
                          style: TextStyle(
                              fontSize: 11, color: ErpColors.warningAmber),
                        ),
                      ),
                    ..._rows.asMap().entries.map((e) => _allocRow(e.key)),
                    TextButton.icon(
                      onPressed: () => setState(() => _rows.add(_AllocRow())),
                      icon: const Icon(Icons.add_circle_outline,
                          size: 14, color: ErpColors.accentBlue),
                      label: const Text('Add another lot',
                          style: TextStyle(
                              color: ErpColors.accentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Remarks ───────────────────────────────
              ErpSectionCard(
                title: 'REMARKS',
                icon: Icons.notes_rounded,
                child: TextField(
                  controller: _remarks,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                      fontSize: 12.5, color: ErpColors.textPrimary),
                  decoration: ErpDecorations.formInput('Optional').copyWith(
                    hintText: 'Anything the next shift should know',
                    hintStyle: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Footer ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
          decoration: const BoxDecoration(
            color: ErpColors.bgSurface,
            border: Border(top: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                _problem ??
                    '${_rows.where((r) => r.filled).length} lot(s) · '
                        '${_qty(_rows.where((r) => r.filled).fold(0.0, (s, r) => s + r.quantity))} kg',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _problem == null
                      ? ErpColors.textSecondary
                      : ErpColors.warningAmber,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  disabledBackgroundColor: _purple.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: (_saving || _problem != null) ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 16, color: Colors.white),
                label: Text(_saving ? 'Raising…' : 'Raise batch',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _allocRow(int i) {
    final row = _rows[i];
    final stock = row.yarnId == null
        ? YarnLotStock.empty
        : c.lotsFor(row.yarnId!);
    // A lot chosen and then orphaned by a yarn change would be sent
    // against the wrong material, which the server refuses outright.
    final lotValue =
        stock.lots.any((l) => l.id == row.lotId) ? row.lotId : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: row.yarnId,
                decoration: ErpDecorations.formInput('Yarn *'),
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textPrimary),
                dropdownColor: ErpColors.bgSurface,
                isExpanded: true,
                items: c.warpYarns
                    .map((y) => DropdownMenuItem<String>(
                          value: y.id,
                          child: Text(y.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  row.yarnId = v;
                  row.lotId = null;
                }),
              ),
            ),
            if (_rows.length > 1) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: ErpColors.textMuted),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => setState(() {
                  _rows.removeAt(i).dispose();
                }),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: lotValue,
                decoration: ErpDecorations.formInput('Lot *'),
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textPrimary),
                dropdownColor: ErpColors.bgSurface,
                isExpanded: true,
                items: stock.lots
                    .map((l) => DropdownMenuItem<String>(
                          value: l.id,
                          child: Row(children: [
                            Expanded(
                              child: Text(l.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            Text('${_qty(l.balance)} kg',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: ErpColors.accentBlue)),
                          ]),
                        ))
                    .toList(),
                onChanged: stock.isEmpty
                    ? null
                    : (v) => setState(() => row.lotId = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: row.qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textPrimary),
                decoration: ErpDecorations.formInput('Qty *').copyWith(
                  suffixText: 'kg',
                  suffixStyle: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          if (row.yarnId != null && stock.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No open lots for this yarn',
                  style: TextStyle(
                      fontSize: 10.5, color: ErpColors.warningAmber)),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ODDS AND ENDS
// ══════════════════════════════════════════════════════════════
class _EmptyBatches extends StatelessWidget {
  const _EmptyBatches();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 32, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 14),
          const Text('No batches yet',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Raise one when the cones come off the rack, so the beams can '
              'be traced back to the lot they were warped from.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
            ),
          ),
        ]),
      );
}

class _Banner extends StatelessWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const _Banner(this.msg, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: color, fontSize: 11)),
          ),
        ]),
      );
}
