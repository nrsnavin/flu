import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/pending_verification_controller.dart';
import '../widgets/timer_photos.dart';

// ══════════════════════════════════════════════════════════════
//  PendingVerificationPage
//  Admin reviews each worker's submitted shift and types the FINAL
//  production values. Per the user's rule there is no "reject" — the
//  admin's numbers always win and cascade on save.
// ══════════════════════════════════════════════════════════════
class PendingVerificationPage extends StatelessWidget {
  const PendingVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PendingVerificationController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Pending Verifications',
        subtitle: 'Workers waiting on admin sign-off',
      ),
      body: Obx(() {
        if (c.loading.value && c.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null && c.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 8),
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 12),
                  ErpPrimaryButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: c.fetch,
                  ),
                ],
              ),
            ),
          );
        }
        if (c.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 48, color: ErpColors.successGreen),
                SizedBox(height: 10),
                Text('All caught up',
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: c.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final shift = c.items[i];
              return _ShiftCard(
                shift: shift,
                onVerify: () => _openVerifySheet(context, c, shift),
              );
            },
          ),
        );
      }),
    );
  }

  void _openVerifySheet(BuildContext ctx,
      PendingVerificationController c, Map<String, dynamic> shift) {
    final shiftId = shift['_id']?.toString() ?? '';
    final submittedProd =
        (shift['submittedProductionMeters'] as num?)?.toDouble() ?? 0;
    final submittedTimer =
        shift['submittedTimer'] as String? ?? '';
    final submittedFeedback =
        shift['submittedFeedback'] as String? ?? '';

    final prodCtrl     = TextEditingController(text: submittedProd > 0
        ? (submittedProd == submittedProd.truncateToDouble()
            ? submittedProd.toInt().toString()
            : submittedProd.toStringAsFixed(2))
        : '');
    final timerCtrl    = TextEditingController(text: submittedTimer);
    final feedbackCtrl = TextEditingController(text: submittedFeedback);
    final noteCtrl     = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 14,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined,
                    color: ErpColors.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Verify Shift Production',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ErpColors.textPrimary)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${(shift['submittedByName']?.toString() ?? '').trim().isNotEmpty ? '${shift['submittedByName'].toString().trim()} entered' : 'Worker submitted'} '
              '${submittedProd.toStringAsFixed(0)} m. Adjust if needed; the value you enter is final.',
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: prodCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: ErpDecorations.formInput(
                'Final Production (m) *',
                prefix: Icon(Icons.straighten_outlined,
                    size: 16, color: ErpColors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: timerCtrl,
                  decoration: ErpDecorations.formInput(
                    'Timer (HH:MM:SS)',
                    prefix: Icon(Icons.timer_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: feedbackCtrl,
                  decoration: ErpDecorations.formInput('Feedback'),
                ),
              ),
            ]),
            // Check the run time against the display itself.
            Align(
              alignment: Alignment.centerLeft,
              child: TimerPhotosButton(
                shiftId: shiftId,
                subtitle: 'Check the run time against the display',
                compact: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: ErpDecorations.formInput(
                'Verify Note (optional)',
                hint: 'Why was the production value changed?',
              ),
            ),
            const SizedBox(height: 18),
            Obx(() => ErpPrimaryButton(
                  label: c.verifying.value
                      ? 'Verifying…'
                      : 'Verify & Cascade',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: c.verifying.value,
                  onPressed: () async {
                    final prod = double.tryParse(prodCtrl.text.trim());
                    if (prod == null || prod < 0) {
                      Get.snackbar('Validation',
                          'Enter a valid production value',
                          backgroundColor: ErpColors.solidError,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM);
                      return;
                    }
                    final ok = await c.verify(
                      shiftId: shiftId,
                      productionMeters: prod,
                      timer: timerCtrl.text.trim(),
                      feedback: feedbackCtrl.text.trim(),
                      note: noteCtrl.text.trim(),
                    );
                    if (ok) Navigator.of(ctx).pop();
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final Map<String, dynamic> shift;
  final VoidCallback onVerify;
  const _ShiftCard({required this.shift, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    final emp = shift['employee'] is Map
        ? shift['employee'] as Map<String, dynamic>
        : <String, dynamic>{};
    final machine = shift['machine'] is Map
        ? shift['machine'] as Map<String, dynamic>
        : <String, dynamic>{};
    final job = shift['job'] is Map
        ? shift['job'] as Map<String, dynamic>
        : <String, dynamic>{};

    final empName = emp['name'] as String? ?? 'Worker';
    final dept    = emp['department'] as String? ?? '';
    final machId  = machine['ID']?.toString() ??
        machine['machineID']?.toString() ?? '—';
    final jobNo   = job['jobOrderNo']?.toString() ?? '—';

    final shiftType = shift['shift']?.toString() ?? '';
    final dateRaw   = shift['date'] as String?;
    String dateLabel = '';
    if (dateRaw != null) {
      try {
        dateLabel = DateFormat('dd MMM, hh:mm a')
            .format(DateTime.parse(dateRaw).toLocal());
      } catch (_) {}
    }

    final submittedProd =
        (shift['submittedProductionMeters'] as num?)?.toDouble() ?? 0;
    final submittedTimer = shift['submittedTimer']?.toString() ?? '';
    final submittedFeedback = shift['submittedFeedback']?.toString() ?? '';
    final submittedAtRaw = shift['submittedAt'] as String?;
    String submittedLabel = '';
    if (submittedAtRaw != null) {
      try {
        submittedLabel = DateFormat('dd MMM, hh:mm a').format(
            DateTime.parse(submittedAtRaw).toLocal());
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ErpColors.warningAmber.withValues(alpha: 0.10),
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top_rounded,
                    color: ErpColors.warningAmber, size: 14),
                const SizedBox(width: 6),
                Text(empName,
                    style: TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                if (dept.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('· $dept',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 11)),
                ],
                const Spacer(),
                Text(shiftType.toUpperCase(),
                    style: TextStyle(
                        color: ErpColors.warningAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MetaCell(
                      icon: Icons.precision_manufacturing_outlined,
                      label: 'Machine',
                      value: machId,
                    ),
                    _MetaCell(
                      icon: Icons.work_outline,
                      label: 'Job',
                      value: '#$jobNo',
                    ),
                    _MetaCell(
                      icon: Icons.calendar_today_outlined,
                      label: 'Shift Date',
                      value: dateLabel.isNotEmpty ? dateLabel : '—',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ErpColors.bgMuted,
                    border: Border.all(color: ErpColors.borderLight),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Who typed it: a floor entry carries the floor
                      // supervisor's name (opened with the shift PIN);
                      // the employee screens' entries do not.
                      Text(
                          (shift['submittedByName']?.toString() ?? '').trim().isNotEmpty
                              ? 'ENTERED ON THE FLOOR BY ${shift['submittedByName'].toString().trim().toUpperCase()}'
                              : 'SUBMITTED BY WORKER',
                          style: TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.straighten_outlined,
                            size: 13, color: ErpColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${submittedProd.toStringAsFixed(submittedProd.truncateToDouble() == submittedProd ? 0 : 2)} m',
                          style: TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.timer_outlined,
                            size: 13, color: ErpColors.textMuted),
                        const SizedBox(width: 4),
                        Text(submittedTimer.isNotEmpty ? submittedTimer : '—',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                      if (submittedFeedback.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(submittedFeedback,
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                      ],
                      if (submittedLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Submitted $submittedLabel',
                            style: TextStyle(
                                color: ErpColors.textMuted,
                                fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                if (shift['previous'] is Map) ...[
                  const SizedBox(height: 8),
                  _ShiftBefore(
                      Map<String, dynamic>.from(shift['previous'] as Map)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    // The photos of the timer taken for this entry:
                    // fetched only when tapped, not with the list.
                    TimerPhotosButton(
                      shiftId: shift['_id']?.toString() ?? '',
                      subtitle: [
                        if (machId != '—') machId,
                        if (shiftType.isNotEmpty) '${shiftType.toLowerCase()} shift',
                        empName,
                      ].join(' · '),
                      compact: true,
                    ),
                    const Spacer(),
                    ErpPrimaryButton(
                      label: 'Verify',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: onVerify,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaCell(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 12, color: ErpColors.textMuted),
              const SizedBox(width: 4),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
            ]),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

/// What the same loom's timer read the shift before (the server's
/// `previous`, from services/floorEntry.js previousReadingFor), so the run
/// time entered now can be checked against where the display started.
/// Verified, or still as the floor submitted it. The web shows the same
/// beside each entry (PreviousShiftReading.tsx). Its photo, like this
/// entry's, is fetched only when "View photo" is tapped.
class _ShiftBefore extends StatelessWidget {
  final Map<String, dynamic> previous;
  const _ShiftBefore(this.previous);

  @override
  Widget build(BuildContext context) {
    final shift = previous['shift'] is Map
        ? Map<String, dynamic>.from(previous['shift'] as Map)
        : const <String, dynamic>{};
    final photo = previous['photo'] is Map
        ? Map<String, dynamic>.from(previous['photo'] as Map)
        : null;
    String? text(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final label = text(shift['label']);
    final operator = text(previous['operator']);
    final runTime = text(previous['runTime']);
    // The run time as it stands, else what the photo read.
    final figure =
        runTime ?? text(photo?['runTimeUsed']) ?? text(photo?['readText']);
    final verified = previous['verified'] == true;
    final entryId = text(previous['entryId']) ?? '';

    final line = figure != null
        ? 'Timer read $figure${operator != null ? ' · $operator' : ''}'
        : operator != null
            ? 'No run time was entered · $operator'
            : 'This loom was not on that shift.';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 15, color: ErpColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'SHIFT BEFORE${label != null ? ' · ${label.toUpperCase()}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(line,
                    style: TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                if (runTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                      verified
                          ? 'Verified by the office'
                          : 'Not verified yet: as the floor submitted it',
                      style: TextStyle(
                          color: verified
                              ? ErpColors.successGreen
                              : ErpColors.warningAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ] else if (operator != null && photo == null) ...[
                  const SizedBox(height: 2),
                  Text('No timer photo was taken.',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 10)),
                ],
              ],
            ),
          ),
          if (photo != null && entryId.isNotEmpty)
            TextButton.icon(
              onPressed: () => openTimerPhotos(
                context,
                shiftId: entryId,
                subtitle: 'Shift before${label != null ? ' · $label' : ''}',
              ),
              style: TextButton.styleFrom(
                foregroundColor: ErpColors.accentBlue,
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 40),
              ),
              icon: const Icon(Icons.photo_camera_outlined, size: 16),
              label: const Text('View photo'),
            ),
        ],
      ),
    );
  }
}
