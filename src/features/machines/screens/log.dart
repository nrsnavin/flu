// lib/src/features/machine/screens/add_service_log_page.dart
//
// Form page for logging a machine service entry.
// Called from MachineDetailPage with machineMongoId.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/machine_controller.dart';

class AddServiceLogPage extends StatefulWidget {
  // Pass the Mongo _id of the machine (not the display ID like LOOM-EL-01)
  final String machineMongoId;
  final String machineDisplayId;   // shown in AppBar subtitle

  const AddServiceLogPage({
    super.key,
    required this.machineMongoId,
    required this.machineDisplayId,
  });

  @override
  State<AddServiceLogPage> createState() => _AddServiceLogPageState();
}

class _AddServiceLogPageState extends State<AddServiceLogPage> {
  late final AddServiceLogController c;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    Get.delete<AddServiceLogController>(force: true);
    c = Get.put(AddServiceLogController(
      machineMongoId: widget.machineMongoId,
      onSuccess: () => Navigator.of(context).pop(true),
    ));
    // Rebuild on reactive state changes
    c.isSaving.listen((_) { if (mounted) setState(() {}); });
    c.selectedType.listen((_) { if (mounted) setState(() {}); });
    c.resolvedFlag.listen((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    Get.delete<AddServiceLogController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ErpColors.bgBase,
    appBar: _buildAppBar(),
    body: Form(
      key: _formKey,
      child: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            // ── Service type ──────────────────────────────
            _SectionCard(
              title: 'SERVICE TYPE',
              icon: Icons.build_outlined,
              child: _TypeSelector(c: c, onChanged: () => setState(() {})),
            ),
            const SizedBox(height: 12),

            // ── Description & technician ──────────────────
            _SectionCard(
              title: 'LOG DETAILS',
              icon: Icons.description_outlined,
              child: Column(children: [
                TextFormField(
                  controller: c.descCtrl,
                  maxLines: 4,
                  style: ErpTextStyles.fieldValue,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: ErpDecorations.formInput(
                    'Description *',
                    hint: 'What was done, what part was replaced…',
                    prefix: const Icon(Icons.notes_rounded,
                        size: 16, color: ErpColors.textMuted),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: c.techCtrl,
                  style: ErpTextStyles.fieldValue,
                  textCapitalization: TextCapitalization.words,
                  decoration: ErpDecorations.formInput(
                    'Technician Name',
                    hint: 'e.g. Rajan Kumar',
                    prefix: const Icon(Icons.engineering_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Cost & next service date ───────────────────
            _SectionCard(
              title: 'ADDITIONAL INFO',
              icon: Icons.info_outline_rounded,
              child: Column(children: [
                TextFormField(
                  controller: c.costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput(
                    'Service Cost (₹)',
                    hint: '0',
                    prefix: const Icon(Icons.currency_rupee_rounded,
                        size: 16, color: ErpColors.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                // Next service date picker
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: ErpColors.accentBlue,
                            onSurface: ErpColors.textPrimary,
                            surface: ErpColors.bgSurface,
                          ),
                          dialogBackgroundColor: ErpColors.bgSurface,
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) { c.setNextDate(d); setState(() {}); }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: c.nextDateCtrl,
                      style: ErpTextStyles.fieldValue,
                      decoration: ErpDecorations.formInput(
                        'Next Service Date (optional)',
                        hint: 'Tap to pick a date',
                        prefix: const Icon(Icons.event_rounded,
                            size: 16, color: ErpColors.textMuted),
                        suffix: c.nextDateCtrl.text.isNotEmpty
                            ? GestureDetector(
                            onTap: () { c.clearNextDate(); setState(() {}); },
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: ErpColors.textMuted))
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Resolved toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ErpColors.bgMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ErpColors.borderLight),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: ErpColors.textMuted),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Issue Resolved',
                            style: TextStyle(
                                color: ErpColors.textPrimary,
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('Uncheck if the issue is still ongoing',
                            style: TextStyle(
                                color: ErpColors.textSecondary, fontSize: 10)),
                      ],
                    )),
                    Switch(
                      value: c.resolvedFlag.value,
                      onChanged: (v) { c.resolvedFlag.value = v; setState(() {}); },
                      activeColor: ErpColors.successGreen,
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        )),

        // ── Footer ────────────────────────────────────────
        _FooterBar(c: c, formKey: _formKey),
      ]),
    ),
  );

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    ),
    titleSpacing: 4,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Add Service Log', style: ErpTextStyles.pageTitle),
        Text(
          '${widget.machineDisplayId}  ›  Service Entry',
          style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );
}

// ── Service type selector ──────────────────────────────────────
class _TypeSelector extends StatelessWidget {
  final AddServiceLogController c;
  final VoidCallback onChanged;
  const _TypeSelector({required this.c, required this.onChanged});

  Color _typeColor(String t) {
    switch (t) {
      case 'Preventive':  return ErpColors.successGreen;
      case 'Corrective':  return ErpColors.accentBlue;
      case 'Breakdown':   return ErpColors.errorRed;
      case 'Inspection':  return ErpColors.warningAmber;
      default:            return ErpColors.textSecondary;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'Preventive':  return Icons.health_and_safety_outlined;
      case 'Corrective':  return Icons.build_circle_outlined;
      case 'Breakdown':   return Icons.warning_amber_rounded;
      case 'Inspection':  return Icons.search_rounded;
      default:            return Icons.miscellaneous_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: AddServiceLogController.kTypes.map((t) {
      final active = c.selectedType.value == t;
      final color  = _typeColor(t);
      return GestureDetector(
        onTap: () { c.selectedType.value = t; onChanged(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? color.withOpacity(0.5) : ErpColors.borderLight,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_typeIcon(t), size: 14,
                color: active ? color : ErpColors.textMuted),
            const SizedBox(width: 6),
            Text(t, style: TextStyle(
                color: active ? color : ErpColors.textSecondary,
                fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }).toList(),
  );
}

// ── Section card ───────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
        ),
        child: Row(children: [
          Container(width: 3, height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  color: ErpColors.accentBlue,
                  borderRadius: BorderRadius.circular(2))),
          Icon(icon, size: 13, color: ErpColors.textSecondary),
          const SizedBox(width: 6),
          Text(title, style: ErpTextStyles.sectionHeader),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

// ── Footer bar ─────────────────────────────────────────────────
class _FooterBar extends StatelessWidget {
  final AddServiceLogController c;
  final GlobalKey<FormState> formKey;
  const _FooterBar({required this.c, required this.formKey});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      border: const Border(top: BorderSide(color: ErpColors.borderLight)),
      boxShadow: [
        BoxShadow(color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, -3)),
      ],
    ),
    child: Row(children: [
      // Cancel
      SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: ErpColors.borderMid),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Cancel',
              style: TextStyle(color: ErpColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 12),
      // Save
      Expanded(
        child: Obx(() => SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: c.isSaving.value
                ? null
                : () {
              if (formKey.currentState!.validate()) c.save();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              disabledBackgroundColor: ErpColors.accentBlue.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            icon: c.isSaving.value
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined,
                size: 16, color: Colors.white),
            label: Text(
              c.isSaving.value ? 'Saving…' : 'Save Log',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        )),
      ),
    ]),
  );
}