import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/pending_verification_controller.dart';

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
                  const Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 8),
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
          return const Center(
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
                const Icon(Icons.verified_outlined,
                    color: ErpColors.accentBlue),
                const SizedBox(width: 8),
                const Expanded(
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
              'Worker submitted ${submittedProd.toStringAsFixed(0)} m. Adjust if needed; the value you enter is final.',
              style: const TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: prodCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: ErpDecorations.formInput(
                'Final Production (m) *',
                prefix: const Icon(Icons.straighten_outlined,
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
                    prefix: const Icon(Icons.timer_outlined,
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
                          backgroundColor: ErpColors.errorRed,
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
              color: ErpColors.warningAmber.withOpacity(0.10),
              border: const Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded,
                    color: ErpColors.warningAmber, size: 14),
                const SizedBox(width: 6),
                Text(empName,
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                if (dept.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('· $dept',
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 11)),
                ],
                const Spacer(),
                Text(shiftType.toUpperCase(),
                    style: const TextStyle(
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
                      const Text('SUBMITTED BY WORKER',
                          style: TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.straighten_outlined,
                            size: 13, color: ErpColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${submittedProd.toStringAsFixed(submittedProd.truncateToDouble() == submittedProd ? 0 : 2)} m',
                          style: const TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.timer_outlined,
                            size: 13, color: ErpColors.textMuted),
                        const SizedBox(width: 4),
                        Text(submittedTimer.isNotEmpty ? submittedTimer : '—',
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                      if (submittedFeedback.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(submittedFeedback,
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                      ],
                      if (submittedLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Submitted $submittedLabel',
                            style: const TextStyle(
                                color: ErpColors.textMuted,
                                fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ErpPrimaryButton(
                    label: 'Verify',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: onVerify,
                  ),
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
                  style: const TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
            ]),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}
