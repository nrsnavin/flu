import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/add_wastage_controller.dart';
import '../models/checkingJobModel.dart';

// ══════════════════════════════════════════════════════════════
//  ADD WASTAGE PAGE
//
//  BUGS FIXED:
//  1. StatelessWidget with Get.put() at class field → stale controller.
//  2. fetchJobs() called /job/jobs-checking → ONLY "checking" jobs returned.
//     Changed to /wastage/jobs-for-wastage → weaving/finishing/checking.
//  3. JobElasticModel.fromJson reads json["elastic"] as plain String.
//     After .populate("elastics.elastic","name") it's a Map {_id, name}.
//     elasticId always became "[object Object]". Elastic dropdown showed
//     "Elastic ID: [object Object]" for every item.
//  4. submitWastage() called /create-wastage (wrong endpoint and router).
//     Correct endpoint is /wastage/add-wastage.
//  5. int.parse(quantityController.text) crashed on decimal input
//     and on empty string — FormatException, no try/catch.
//  6. double.parse(penaltyController.text) crashed on empty penalty field.
//  7. No try/catch on ANY API call — unhandled DioException crashed widget tree.
//  8. No loading state on submit button.
//  9. No error feedback when API calls failed.
//  10. fetchOperators called /job/job-operators?id=... but no null check
//      on response — if operators was empty, null cast crashed on list map.
//  11. "quantity" was sent as int — backend requires Number (accepts decimal).
// ══════════════════════════════════════════════════════════════

class AddWastagePage extends StatefulWidget {
  const AddWastagePage({super.key});

  @override
  State<AddWastagePage> createState() => _AddWastagePageState();
}

class _AddWastagePageState extends State<AddWastagePage> {
  late final AddWastageController c;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    Get.delete<AddWastageController>(force: true);
    c = Get.put(AddWastageController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Form(
        key: _formKey,
        child: Obx(() {
          if (c.isLoadingJobs.value) {
            return const Center(
                child: CircularProgressIndicator(color: ErpColors.accentBlue));
          }
          if (c.errorMsg.value != null && c.jobs.isEmpty) {
            return _ErrorState(
                msg: c.errorMsg.value!, retry: c.reload);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
            child: Column(children: [
              // ── Job Selection ─────────────────────────────
              ErpSectionCard(
                title: 'JOB',
                icon: Icons.work_outline_rounded,
                child: Column(children: [
                  // FIX: was /jobs-checking only. Now shows weaving/finishing/checking
                  _buildJobDropdown(),
                  if (c.selectedJob.value != null) ...[
                    const SizedBox(height: 6),
                    _JobStatusBadge(c.selectedJob.value!.status),
                  ],
                ]),
              ),
              const SizedBox(height: 12),

              // ── Elastic Selection ─────────────────────────
              ErpSectionCard(
                title: 'ELASTIC',
                icon: Icons.grid_on_rounded,
                child: _buildElasticDropdown(),
              ),
              const SizedBox(height: 12),

              // ── Operator Selection ────────────────────────
              ErpSectionCard(
                title: 'OPERATOR',
                icon: Icons.person_outline_rounded,
                child: _buildEmployeeDropdown(),
              ),
              const SizedBox(height: 12),

              // ── Wastage Details ───────────────────────────
              ErpSectionCard(
                title: 'WASTAGE DETAILS',
                icon: Icons.warning_amber_rounded,
                child: Column(children: [
                  // Quantity
                  TextFormField(
                    controller: c.quantityCtrl,
                    style: ErpTextStyles.fieldValue,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    // FIX: was int.parse — crashes on decimal/empty
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: ErpDecorations.formInput('Wastage Quantity (m) *')
                        .copyWith(
                      suffixText: 'm',
                      suffixStyle: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Quantity is required';
                      }
                      final q = double.tryParse(v.trim());
                      if (q == null || q <= 0) return 'Enter a valid quantity';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Penalty
                  TextFormField(
                    controller: c.penaltyCtrl,
                    style: ErpTextStyles.fieldValue,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    // FIX: was double.parse — crashes on empty
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: ErpDecorations.formInput('Penalty (₹)')
                        .copyWith(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 12),
                      hintText: '0.00 (optional)',
                      hintStyle: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Reason
                  TextFormField(
                    controller: c.reasonCtrl,
                    style: ErpTextStyles.fieldValue,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: ErpDecorations.formInput('Reason *')
                        .copyWith(
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Reason is required';
                      }
                      return null;
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Submit ────────────────────────────────────
              Obx(() => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.errorRed,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: c.isSaving.value ? null : _submit,
                  icon: c.isSaving.value
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 18),
                  label: Text(
                      c.isSaving.value ? 'Saving…' : 'Record Wastage',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              )),
            ]),
          );
        }),
      ),
    );
  }

  // ── Job dropdown ─────────────────────────────────────────
  Widget _buildJobDropdown() {
    if (c.jobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 14, color: ErpColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No jobs in weaving / finishing / checking',
              style: const TextStyle(
                  color: ErpColors.textSecondary, fontSize: 11),
            ),
          ),
        ]),
      );
    }

    return DropdownButtonFormField<WastageJobOption>(
      value: c.selectedJob.value,
      decoration: ErpDecorations.formInput('Select Job *'),
      style: ErpTextStyles.fieldValue,
      dropdownColor: ErpColors.bgSurface,
      isExpanded: true,
      items: c.jobs
          .map((job) => DropdownMenuItem(
        value: job,
        child: Text(
          'Job #${job.jobOrderNo}  —  ${_cap(job.status)}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ))
          .toList(),
      onChanged: (job) {
        if (job == null) return;
        c.onJobSelected(job);
      },
      validator: (_) =>
      c.selectedJob.value == null ? 'Select a job' : null,
    );
  }

  // ── Elastic dropdown ──────────────────────────────────────
  Widget _buildElasticDropdown() {
    if (c.selectedJob.value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: const Text('Select a job first',
            style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
      );
    }

    final elastics = c.selectedJob.value!.elastics;
    if (elastics.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: const Text('No elastics in this job',
            style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
      );
    }

    return Obx(() => DropdownButtonFormField<WastageElasticOption>(
      value: c.selectedElastic.value,
      decoration: ErpDecorations.formInput('Select Elastic *'),
      style: ErpTextStyles.fieldValue,
      dropdownColor: ErpColors.bgSurface,
      isExpanded: true,
      items: elastics
          .map((e) => DropdownMenuItem(
        value: e,
        // FIX: was "Elastic ID: <ObjectId>" because elastic field
        //      was parsed as String after populate returns a Map.
        //      Now shows the actual elastic name.
        child: Text(
          '${e.displayName}  (${e.quantity} m planned)',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ))
          .toList(),
      onChanged: (e) => c.selectedElastic.value = e,
      validator: (_) =>
      c.selectedElastic.value == null ? 'Select an elastic' : null,
    ));
  }

  // ── Employee dropdown ─────────────────────────────────────
  Widget _buildEmployeeDropdown() {
    return Obx(() {
      if (c.isLoadingOps.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ErpColors.accentBlue),
            ),
            SizedBox(width: 10),
            Text('Loading operators…',
                style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
          ]),
        );
      }

      if (c.selectedJob.value == null) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: const Text('Select a job first',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        );
      }

      if (c.operators.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: const Text('No operators assigned to this job',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        );
      }

      return DropdownButtonFormField<EmployeeOption>(
        value: c.selectedEmployee.value,
        decoration: ErpDecorations.formInput('Select Operator *'),
        style: ErpTextStyles.fieldValue,
        dropdownColor: ErpColors.bgSurface,
        isExpanded: true,
        items: c.operators
            .map((e) => DropdownMenuItem(
          value: e,
          child: Row(children: [
            const Icon(Icons.person_outline,
                size: 13, color: ErpColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                e.department != null
                    ? '${e.name}  ·  ${e.department}'
                    : e.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ]),
        ))
            .toList(),
        onChanged: (e) => c.selectedEmployee.value = e,
        validator: (_) =>
        c.selectedEmployee.value == null ? 'Select an operator' : null,
      );
    });
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new,
          size: 16, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    ),
    titleSpacing: 4,
    title: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Record Wastage', style: ErpTextStyles.pageTitle),
        Text('Wastage  ›  Add',
            style: TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 10)),
      ],
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    c.submit();
  }

  String _cap(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

// ── Job status badge ───────────────────────────────────────
class _JobStatusBadge extends StatelessWidget {
  final String status;
  const _JobStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'weaving':   color = const Color(0xFF7C3AED); break;
      case 'finishing': color = const Color(0xFF0891B2); break;
      case 'checking':  color = ErpColors.warningAmber;  break;
      default:          color = ErpColors.accentBlue;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ]),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorState({required this.msg, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 40, color: ErpColors.textMuted),
      const SizedBox(height: 12),
      const Text('Failed to load',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      Text(msg,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: retry,
        style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue, elevation: 0),
        icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
        label: const Text('Retry',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}