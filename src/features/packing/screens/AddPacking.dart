import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/packing_controller.dart';
import '../models/PackingModel.dart';


// ══════════════════════════════════════════════════════════════
//  ADD PACKING PAGE
//
//  BUGS FIXED:
//  1. Get.put inside StatelessWidget → now StatefulWidget w/ initState
//  2. No form validation → all fields required before submit
//  3. No loading indicator on submit button
//  4. int.parse(meterController.text) in controller with no error
//     handling → crash on empty / non-numeric input
//  5. No try/catch in submit
// ══════════════════════════════════════════════════════════════

class AddPackingPage extends StatefulWidget {
  const AddPackingPage({super.key});

  @override
  State<AddPackingPage> createState() => _AddPackingPageState();
}

class _AddPackingPageState extends State<AddPackingPage> {
  late final AddPackingController c;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    Get.delete<AddPackingController>(force: true);
    c = Get.put(AddPackingController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    c.submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: ErpColors.accentBlue),
              SizedBox(height: 12),
              Text('Loading form data…',
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 13)),
            ]),
          );
        }
        if (c.errorMsg.value != null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline,
                  size: 40, color: ErpColors.textMuted),
              const SizedBox(height: 12),
              const Text('Failed to load form data',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary)),
              const SizedBox(height: 4),
              Text(c.errorMsg.value!,
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed:(){},
                style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue, elevation: 0),
                icon: const Icon(Icons.refresh,
                    size: 16, color: Colors.white),
                label: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }

        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(children: [
              // ── Job + Elastic ─────────────────────────────
              ErpSectionCard(
                title: 'JOB ASSIGNMENT',
                icon: Icons.work_outline_rounded,
                child: Column(children: [
                  // Job dropdown
                  DropdownButtonFormField<PackingJobModel>(
                    value: c.selectedJob.value,
                    isExpanded: true,
                    style: ErpTextStyles.fieldValue,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: ErpColors.textSecondary, size: 18),
                    decoration: ErpDecorations.formInput(
                      'Job Order',
                      prefix: const Icon(Icons.inventory_2_outlined,
                          size: 16, color: ErpColors.textMuted),
                    ),
                    hint: const Text('Select job in packing',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 12)),
                    items: c.jobs
                        .map((job) => DropdownMenuItem(
                      value: job,
                      child: Text(
                          'Job #${job.jobNo}${job.customerName != null ? "  •  ${job.customerName}" : ""}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary)),
                    ))
                        .toList(),
                    onChanged: (val) {
                      c.selectedJob.value     = val;
                      c.selectedElastic.value = null;
                    },
                    validator: (v) =>
                    v == null ? 'Please select a job' : null,
                  ),
                  const SizedBox(height: 12),
                  // Elastic dropdown (shown after job selected)
                  Obx(() => c.selectedJob.value == null
                      ? const SizedBox.shrink()
                      : DropdownButtonFormField<String>(
                    value: c.selectedElastic.value,
                    isExpanded: true,
                    style: ErpTextStyles.fieldValue,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: ErpColors.textSecondary, size: 18),
                    decoration: ErpDecorations.formInput(
                      'Elastic',
                      prefix: const Icon(
                          Icons.fiber_manual_record_outlined,
                          size: 16,
                          color: ErpColors.textMuted),
                    ),
                    hint: const Text('Select elastic',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 12)),
                    items: c.selectedJob.value!.elastics
                        .map((e) => DropdownMenuItem(
                      value: e.elasticId,
                      child: Text(e.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary)),
                    ))
                        .toList(),
                    onChanged: (val) =>
                    c.selectedElastic.value = val,
                    validator: (v) =>
                    v == null ? 'Please select an elastic' : null,
                  )),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Production data ───────────────────────────
              ErpSectionCard(
                title: 'PRODUCTION DATA',
                icon: Icons.precision_manufacturing_outlined,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: _numField(
                        ctrl:  c.meterCtrl,
                        label: 'Meters',
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
                          if (v == null || v.trim().isEmpty) return 'Required';
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
                ]),
              ),
              const SizedBox(height: 12),

              // ── Weights ────────────────────────────────────
              ErpSectionCard(
                title: 'WEIGHT DETAILS',
                icon: Icons.monitor_weight_outlined,
                accentColor: ErpColors.warningAmber,
                child: Column(children: [
                  _numField(
                    ctrl:  c.netCtrl,
                    label: 'Net Weight (kg)',
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
                        label: 'Tare Weight',
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
                        label: 'Gross Weight',
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
                ]),
              ),
              const SizedBox(height: 12),

              // ── QC / Employees ────────────────────────────
              ErpSectionCard(
                title: 'QUALITY CONTROL',
                icon: Icons.verified_outlined,
                accentColor: ErpColors.successGreen,
                child: Column(children: [
                  Obx(() => DropdownButtonFormField<String>(
                    value: c.selectedCheckedBy.value,
                    isExpanded: true,
                    style: ErpTextStyles.fieldValue,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: ErpColors.textSecondary, size: 18),
                    decoration: ErpDecorations.formInput(
                      'Checked By',
                      prefix: const Icon(Icons.person_search_outlined,
                          size: 16, color: ErpColors.textMuted),
                    ),
                    hint: const Text('Select checker',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 12)),
                    items: c.checkingEmployees
                        .map((e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary)),
                    ))
                        .toList(),
                    onChanged: (v) => c.selectedCheckedBy.value = v,
                    validator: (v) =>
                    v == null ? 'Please select checker' : null,
                  )),
                  const SizedBox(height: 12),
                  Obx(() => DropdownButtonFormField<String>(
                    value: c.selectedPackedBy.value,
                    isExpanded: true,
                    style: ErpTextStyles.fieldValue,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: ErpColors.textSecondary, size: 18),
                    decoration: ErpDecorations.formInput(
                      'Packed By',
                      prefix: const Icon(Icons.inventory_outlined,
                          size: 16, color: ErpColors.textMuted),
                    ),
                    hint: const Text('Select packer',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 12)),
                    items: c.packingEmployees
                        .map((e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary)),
                    ))
                        .toList(),
                    onChanged: (v) => c.selectedPackedBy.value = v,
                    validator: (v) =>
                    v == null ? 'Please select packer' : null,
                  )),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Submit ────────────────────────────────────
              Obx(() => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: c.isSaving.value ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    disabledBackgroundColor:
                    ErpColors.accentBlue.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: c.isSaving.value
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.save_outlined,
                      size: 19, color: Colors.white),
                  label: Text(
                    c.isSaving.value ? 'Saving…' : 'Save Packing Record',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ),
              )),
            ]),
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Packing', style: ErpTextStyles.pageTitle),
          Text('Packing  ›  New Record',
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
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
      controller:       ctrl,
      keyboardType:     const TextInputType.numberWithOptions(decimal: true),
      inputFormatters:  [
        FilteringTextInputFormatter.allow(
            isDouble ? RegExp(r'[\d.]') : RegExp(r'\d')),
      ],
      style:            ErpTextStyles.fieldValue,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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