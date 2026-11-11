import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/wastage_entry_controller.dart';

// ══════════════════════════════════════════════════════════════
//  WASTAGE ENTRY FORM — POST /wastage/add-wastage
//
//  Mirrors the admin app's Add Wastage layout (Job header → elastic
//  → operator → quantity → penalty → reason). The operator dropdown
//  is sourced from /wastage/job-operators?id=<jobId> — distinct list
//  of employees who logged shifts on the job.
//
//  Behaviour: if the operator fetch returns an empty list (no shift
//  has been logged on the job yet), a blocking dialog pops up
//  explaining "Shift not logged" and the form navigates back to the
//  jobs picker. Wastage cannot be recorded without an attributable
//  operator — the backend rejects it, and the audit trail would be
//  meaningless.
//
//  Field names match backend contract (api/wastage.js add-wastage):
//    job, elastic, employee, quantity, reason  (penalty optional).
// ══════════════════════════════════════════════════════════════
class WastageEntryFormPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final EmpWastageEntryController controller;
  const WastageEntryFormPage({
    super.key,
    required this.job,
    required this.controller,
  });

  @override
  State<WastageEntryFormPage> createState() => _WastageEntryFormPageState();
}

class _WastageEntryFormPageState extends State<WastageEntryFormPage> {
  EmpWastageEntryController get c => widget.controller;
  final _formKey = GlobalKey<FormState>();

  // Guard so the dialog only shows once even if the page rebuilds.
  bool _shiftDialogShown = false;

  @override
  void initState() {
    super.initState();
    final jobId = SafeJson.asString(widget.job['_id']);
    if (jobId.isNotEmpty) {
      c.fetchOperators(jobId).then((_) {
        if (!mounted) return;
        // Defer the dialog so it fires after the first frame is mounted
        // and the BuildContext is safe to use.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _shiftDialogShown) return;
          if (!c.isLoadingOps.value && c.operators.isEmpty) {
            _shiftDialogShown = true;
            _showShiftNotLoggedDialog();
          }
        });
      });
    }
  }

  Future<void> _showShiftNotLoggedDialog() async {
    final jobOrderNo = SafeJson.asInt(widget.job['jobOrderNo']);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.warning_amber_rounded,
            color: ErpColors.warningAmber, size: 36),
        title: const Text(
          'Shift Not Logged',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ErpColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'No operator has logged a shift on Job #$jobOrderNo yet. Wastage can only be recorded against an operator who actually produced the work.\n\nAsk the weaver to log their shift first, then come back to record the wastage.',
          style: const TextStyle(
            color: ErpColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: 140,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    // Bounce back to the jobs picker — there's nothing to do on this
    // form without an operator to attribute the wastage to.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final jobId      = SafeJson.asString(widget.job['_id']);
    final jobOrderNo = SafeJson.asInt(widget.job['jobOrderNo']);
    final status     = SafeJson.asString(widget.job['status'], '—');
    final cust       = SafeJson.asMap(widget.job['customer']);
    final custName   = SafeJson.asStringOrNull(cust['name']) ??
        SafeJson.asStringOrNull(widget.job['customer']);

    // Job.elastics is a list of { elastic: { _id, name }, quantity }.
    final elastics = SafeJson.asMapList(widget.job['elastics'])
        .map((row) {
          final el = SafeJson.asMap(row['elastic']);
          return {
            'id':       SafeJson.asString(el['_id']),
            'name':     SafeJson.asString(el['name'], 'Elastic'),
            'planned':  SafeJson.asDouble(row['quantity']),
          };
        })
        .where((e) => (e['id'] as String).isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Record Wastage  ·  #$jobOrderNo',
                style: ErpTextStyles.pageTitle),
            const Text('Wastage  ›  New entry',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Job header card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ErpColors.navyDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: ErpColors.errorRed.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_outlined,
                      color: ErpColors.errorRed, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Job #$jobOrderNo',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5)),
                          ),
                        ]),
                        if (custName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(custName,
                                style: const TextStyle(
                                    color: ErpColors.textOnDarkSub,
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Elastic picker ───────────────────────────────
            _SectionLabel(label: 'ELASTIC'),
            const SizedBox(height: 8),
            if (elastics.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                child: const Text('No elastics on this job',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 12)),
              )
            else
              Obx(() => DropdownButtonFormField<String>(
                    value: c.selectedElasticId.value,
                    isExpanded: true,
                    style: ErpTextStyles.fieldValue,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: ErpColors.textSecondary, size: 18),
                    decoration: ErpDecorations.formInput(
                      'Elastic *',
                      prefix: const Icon(Icons.fiber_manual_record_outlined,
                          size: 16, color: ErpColors.textMuted),
                    ),
                    hint: const Text('Select the wasted elastic',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 12)),
                    items: elastics.map((e) {
                      final planned = e['planned'] as double;
                      return DropdownMenuItem<String>(
                        value: e['id'] as String,
                        child: Text(
                          planned > 0
                              ? '${e['name']}  (${planned.toStringAsFixed(0)} m planned)'
                              : e['name'] as String,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => c.selectedElasticId.value = v,
                    validator: (v) =>
                        v == null ? 'Pick the elastic' : null,
                  )),
            const SizedBox(height: 18),

            // ── Operator picker ───────────────────────────────
            _SectionLabel(label: 'OPERATOR'),
            const SizedBox(height: 8),
            Obx(() {
              if (c.isLoadingOps.value) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: ErpColors.bgMuted,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ErpColors.borderLight),
                  ),
                  child: Row(children: const [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: ErpColors.accentBlue, strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Loading operators…',
                        style: TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 12)),
                  ]),
                );
              }

              if (c.operators.isEmpty) {
                // The blocking dialog has already fired from initState's
                // post-frame callback; this static notice covers the brief
                // moment before the dialog actually paints, and any case
                // where the user dismissed the dialog without the auto-pop
                // (shouldn't happen — barrierDismissible:false — but kept
                // as a visible safety net).
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ErpColors.warningAmber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: ErpColors.warningAmber.withValues(alpha: 0.45)),
                  ),
                  child: Row(children: const [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: ErpColors.warningAmber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Shift not logged on this job — wastage cannot be recorded',
                          style: TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                );
              }

              return DropdownButtonFormField<String>(
                value: c.selectedEmployeeId.value,
                isExpanded: true,
                style: ErpTextStyles.fieldValue,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: ErpColors.textSecondary, size: 18),
                decoration: ErpDecorations.formInput(
                  'Operator *',
                  prefix: const Icon(Icons.person_outline,
                      size: 16, color: ErpColors.textMuted),
                ),
                hint: const Text('Attribute wastage to operator',
                    style: TextStyle(
                        color: ErpColors.textMuted, fontSize: 12)),
                items: c.operators.map((op) {
                  final id   = SafeJson.asString(op['_id']);
                  final name = SafeJson.asString(op['name'], '—');
                  final dept = SafeJson.asStringOrNull(op['department']);
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      dept != null && dept.isNotEmpty
                          ? '$name  ·  $dept'
                          : name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ErpColors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (v) => c.selectedEmployeeId.value = v,
                validator: (v) => v == null ? 'Pick the operator' : null,
              );
            }),
            const SizedBox(height: 18),

            // ── Wastage details ──────────────────────────────
            _SectionLabel(label: 'WASTAGE DETAILS'),
            const SizedBox(height: 8),
            TextFormField(
              controller: c.quantityCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // Allow only digits with at most one decimal point so
                // double.tryParse on submit doesn't silently fail on
                // strings like "1.2.3".
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput(
                'Wastage Quantity (m) *',
                prefix: const Icon(Icons.straighten_outlined,
                    size: 16, color: ErpColors.textMuted),
              ).copyWith(
                suffixText: 'm',
                suffixStyle: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final q = double.tryParse(v.trim());
                if (q == null || q <= 0) return 'Enter a valid quantity';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: c.penaltyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // Allow only digits with at most one decimal point so
                // double.tryParse on submit doesn't silently fail on
                // strings like "1.2.3".
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput(
                'Penalty (₹)',
                prefix: const Icon(Icons.currency_rupee_outlined,
                    size: 16, color: ErpColors.textMuted),
              ).copyWith(
                hintText: '0 (optional)',
                hintStyle: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: c.reasonCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput('Reason *').copyWith(
                alignLabelWithHint: true,
                hintText: 'Why was this elastic wasted?',
                hintStyle: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Reason is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),

            // ── Submit ────────────────────────────────────────────
            //
            // Submit is disabled (in addition to client-side validation)
            // whenever no operator is available — belt-and-braces with
            // the blocking dialog.
            Obx(() {
              final disabled = c.isSubmitting.value ||
                  (c.isLoadingOps.value) ||
                  c.operators.isEmpty;
              return SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.errorRed,
                    disabledBackgroundColor:
                        ErpColors.errorRed.withValues(alpha: 0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: disabled
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          FocusScope.of(context).unfocus();
                          final ok = await c.submit(jobId: jobId);
                          if (ok && mounted) Get.back();
                        },
                  icon: c.isSubmitting.value
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 20),
                  label: Text(
                    c.isSubmitting.value
                        ? 'Saving…'
                        : (c.operators.isEmpty
                            ? 'Shift not logged'
                            : 'Record Wastage'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(label,
            style: const TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
      );
}
