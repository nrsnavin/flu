import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/packing_entry_controller.dart';

// ══════════════════════════════════════════════════════════════
//  PACKING ENTRY FORM — POST /packing/create-packing
//
//  Mirrors the admin app's Add Packing layout: Job header → elastic
//  picker → production data (meters, joints, stretch, size) → weights
//  (net / tare / gross) → QC (checkedBy / packedBy).
//
//  Shift-presence guard: on init we hit /wastage/job-operators?id=
//  to see if anyone has logged a shift on this job. Empty response
//  → "Shift Not Logged" dialog → pop back. Without a shift, there's
//  nothing to pack — the weaver hasn't produced anything yet.
// ══════════════════════════════════════════════════════════════
class PackingEntryFormPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final EmpPackingEntryController controller;
  const PackingEntryFormPage({
    super.key,
    required this.job,
    required this.controller,
  });

  @override
  State<PackingEntryFormPage> createState() => _PackingEntryFormPageState();
}

class _PackingEntryFormPageState extends State<PackingEntryFormPage> {
  EmpPackingEntryController get c => widget.controller;
  final _formKey = GlobalKey<FormState>();

  bool _shiftDialogShown = false;

  @override
  void initState() {
    super.initState();
    c.loadEmployees();

    final jobId = SafeJson.asString(widget.job['_id']);
    if (jobId.isNotEmpty) {
      c.fetchJobOperators(jobId).then((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _shiftDialogShown) return;
          if (!c.isLoadingJobOps.value && c.jobOperators.isEmpty) {
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
          'No shift has been logged on Job #$jobOrderNo yet. Packing can only be recorded after the weaver has produced output.\n\nAsk the weaver to log their shift production first, then come back to record packing.',
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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final jobId      = SafeJson.asString(widget.job['_id']);
    final jobOrderNo = SafeJson.asInt(widget.job['jobOrderNo']);
    final cust       = SafeJson.asMap(widget.job['customer']);
    final custName   = SafeJson.asStringOrNull(cust['name']) ??
        SafeJson.asStringOrNull(widget.job['customer']);

    final elastics = SafeJson.asMapList(widget.job['elastics'])
        .map((row) {
          final el = SafeJson.asMap(row['elastic']);
          return {
            'id':   SafeJson.asString(el['_id']),
            'name': SafeJson.asString(el['name'], 'Elastic'),
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
            Text('Pack Job #$jobOrderNo', style: ErpTextStyles.pageTitle),
            const Text('Packing  ›  New entry',
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
                    color: ErpColors.successGreen.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: ErpColors.successGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Job #$jobOrderNo',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                        if (custName != null)
                          Text(custName,
                              style: const TextStyle(
                                  color: ErpColors.textOnDarkSub,
                                  fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Shift-presence inline notice. The blocking dialog fires
            // from initState; this strip is the static fallback that's
            // visible during the brief window before the dialog mounts.
            Obx(() {
              if (c.isLoadingJobOps.value) return const SizedBox.shrink();
              if (c.jobOperators.isNotEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
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
                        'Shift not logged on this job — packing cannot be recorded',
                        style: TextStyle(
                            color: ErpColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 4),

            _SectionLabel(label: 'ELASTIC'),
            const SizedBox(height: 8),
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
                  hint: const Text('Select the elastic packed',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 12)),
                  items: elastics.map((e) {
                    return DropdownMenuItem<String>(
                      value: e['id'] as String,
                      child: Text(e['name'] as String,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (v) => c.selectedElasticId.value = v,
                  validator: (v) =>
                      v == null ? 'Pick the elastic' : null,
                )),
            const SizedBox(height: 18),

            _SectionLabel(label: 'PRODUCTION DATA'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _numField(
                  ctrl:  c.meterCtrl,
                  label: 'Meters *',
                  icon:  Icons.straighten_outlined,
                  isDouble: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numField(
                  ctrl:  c.jointsCtrl,
                  label: 'Joints',
                  icon:  Icons.link_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (int.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _textField(
                  ctrl:  c.stretchCtrl,
                  label: 'Stretch %',
                  icon:  Icons.expand_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  ctrl:  c.sizeCtrl,
                  label: 'Size',
                  icon:  Icons.aspect_ratio_outlined,
                ),
              ),
            ]),
            const SizedBox(height: 18),

            _SectionLabel(label: 'WEIGHT DETAILS'),
            const SizedBox(height: 8),
            _numField(
              ctrl:  c.netCtrl,
              label: 'Net Weight (kg) *',
              icon:  Icons.scale_outlined,
              isDouble: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _numField(
                  ctrl:  c.tareCtrl,
                  label: 'Tare (kg) *',
                  icon:  Icons.scale_outlined,
                  isDouble: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numField(
                  ctrl:  c.grossCtrl,
                  label: 'Gross (kg) *',
                  icon:  Icons.scale_outlined,
                  isDouble: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 18),

            _SectionLabel(label: 'QUALITY CONTROL'),
            const SizedBox(height: 8),
            Obx(() {
              if (c.isEmpLoading.value) {
                return _LoadingChip(label: 'Loading teammates…');
              }
              return Column(children: [
                DropdownButtonFormField<String>(
                  value: c.selectedCheckedById.value,
                  isExpanded: true,
                  style: ErpTextStyles.fieldValue,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: ErpColors.textSecondary, size: 18),
                  decoration: ErpDecorations.formInput(
                    'Checked By *',
                    prefix: const Icon(Icons.person_search_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                  hint: const Text('Select checker',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 12)),
                  items: c.checkingEmployees.map((e) {
                    final id   = SafeJson.asString(e['_id']);
                    final name = SafeJson.asString(e['name'], '—');
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(name, style: ErpTextStyles.fieldValue),
                    );
                  }).toList(),
                  onChanged: (v) => c.selectedCheckedById.value = v,
                  validator: (v) =>
                      v == null ? 'Pick the checker' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: c.selectedPackedById.value,
                  isExpanded: true,
                  style: ErpTextStyles.fieldValue,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: ErpColors.textSecondary, size: 18),
                  decoration: ErpDecorations.formInput(
                    'Packed By *',
                    prefix: const Icon(Icons.inventory_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                  hint: const Text('Select packer',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 12)),
                  items: c.packingEmployees.map((e) {
                    final id   = SafeJson.asString(e['_id']);
                    final name = SafeJson.asString(e['name'], '—');
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(name, style: ErpTextStyles.fieldValue),
                    );
                  }).toList(),
                  onChanged: (v) => c.selectedPackedById.value = v,
                  validator: (v) =>
                      v == null ? 'Pick the packer' : null,
                ),
              ]);
            }),
            const SizedBox(height: 22),

            // Submit — disabled while we're checking shift presence and
            // any time the job has no shift logged (the dialog handles
            // the latter case but the disabled state is the visible cue).
            Obx(() {
              final noShift = !c.isLoadingJobOps.value &&
                  c.jobOperators.isEmpty;
              final disabled = c.isSubmitting.value ||
                  c.isLoadingJobOps.value ||
                  noShift;
              return SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.successGreen,
                    disabledBackgroundColor:
                        ErpColors.successGreen.withValues(alpha: 0.45),
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
                      : const Icon(Icons.check_circle_outline_rounded,
                          color: Colors.white, size: 20),
                  label: Text(
                    c.isSubmitting.value
                        ? 'Saving…'
                        : (noShift
                            ? 'Shift not logged'
                            : 'Save Packing Entry'),
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

  Widget _numField({
    required TextEditingController ctrl,
    required String label,
    IconData? icon,
    bool isDouble = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            // Digits with at most one decimal point when isDouble.
            isDouble ? RegExp(r'^\d*\.?\d*$') : RegExp(r'\d')),
      ],
      style:        ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput(
        label,
        prefix: icon != null
            ? Icon(icon, size: 16, color: ErpColors.textMuted)
            : null,
      ),
      validator: validator,
    );
  }

  Widget _textField({
    required TextEditingController ctrl,
    required String label,
    IconData? icon,
  }) {
    return TextFormField(
      controller: ctrl,
      style:      ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput(
        label,
        prefix: icon != null
            ? Icon(icon, size: 16, color: ErpColors.textMuted)
            : null,
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

class _LoadingChip extends StatelessWidget {
  final String label;
  const _LoadingChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                color: ErpColors.accentBlue, strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12)),
        ]),
      );
}
