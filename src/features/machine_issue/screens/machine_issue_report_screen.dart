import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../machines/controllers/machine_controller.dart';
import '../../machines/models/machine.dart';
import '../controllers/machine_issue_admin_controller.dart';

// ══════════════════════════════════════════════════════════════
//  REPORT MACHINE ISSUE (admin-raised)
//
//  Mirrors the web "Report machine issue" form. Admins can raise an
//  issue directly against a machine — the backend records it with
//  source: "admin" (no linked employee). Fields: machine (required),
//  title (required), description (required), severity.
// ══════════════════════════════════════════════════════════════
class MachineIssueReportScreen extends StatefulWidget {
  const MachineIssueReportScreen({super.key});

  @override
  State<MachineIssueReportScreen> createState() =>
      _MachineIssueReportScreenState();
}

class _MachineIssueReportScreenState extends State<MachineIssueReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  static const _severities = ['low', 'medium', 'high', 'critical'];
  String _severity = 'medium';

  String? _machineId;
  List<MachineListItem> _machines = const [];
  bool _loadingMachines = true;
  String? _machineError;

  MachineIssueAdminController get _c =>
      Get.isRegistered<MachineIssueAdminController>()
          ? Get.find<MachineIssueAdminController>()
          : Get.put(MachineIssueAdminController());

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadMachines() async {
    setState(() {
      _loadingMachines = true;
      _machineError = null;
    });
    try {
      final list = await MachineApiService.fetchAll();
      list.sort((a, b) => a.machineCode.compareTo(b.machineCode));
      // The screen can be popped while this is in flight — a report
      // raised and dismissed quickly is the ordinary case on a floor.
      if (!mounted) return;
      setState(() {
        _machines = list;
        _loadingMachines = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _machineError = 'Could not load machines';
        _loadingMachines = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_machineId == null || _machineId!.isEmpty) {
      Get.snackbar(
        'Pick a machine',
        'Choose which machine has the issue.',
        backgroundColor: ErpColors.solidWarning,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final ok = await _c.create(
      machineId: _machineId!,
      title: _title.text,
      description: _description.text,
      severity: _severity,
    );
    if (ok && mounted) {
      Get.back();
      Get.snackbar(
        'Issue reported',
        'The machine issue has been logged.',
        backgroundColor: ErpColors.solidSuccess,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Report Machine Issue',
        subtitle: 'Raise a breakdown or fault',
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _machineField(),
              const SizedBox(height: 16),

              TextFormField(
                controller: _title,
                style: ErpTextStyles.fieldValue,
                textCapitalization: TextCapitalization.sentences,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: ErpDecorations.formInput('Title *',
                    hint: 'e.g. Loom stops intermittently'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _description,
                style: ErpTextStyles.fieldValue,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: ErpDecorations.formInput('Description *',
                    hint: "What's happening?"),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 18),

              _label('Severity'),
              const SizedBox(height: 8),
              _severityPicker(),
              const SizedBox(height: 28),

              Obx(() => SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _c.creating.value ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ErpColors.accentBlue,
                        disabledBackgroundColor:
                            ErpColors.accentBlue.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _c.creating.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.report_problem_outlined,
                              size: 18, color: Colors.white),
                      label: Text(
                        _c.creating.value ? 'Reporting…' : 'Report issue',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: ErpTextStyles.fieldLabel);

  Widget _machineField() {
    if (_loadingMachines) {
      return Container(
        height: 52,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ErpColors.accentBlue)),
          SizedBox(width: 10),
          Text('Loading machines…',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 13)),
        ]),
      );
    }
    if (_machineError != null) {
      return Row(children: [
        Expanded(
          child: Text(_machineError!,
              style: TextStyle(color: ErpColors.errorRed, fontSize: 13)),
        ),
        TextButton(onPressed: _loadMachines, child: const Text('Retry')),
      ]);
    }
    return DropdownButtonFormField<String>(
      value: _machineId,
      isExpanded: true,
      style: ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput('Machine',
          hint: 'Select machine',
          prefix: Icon(Icons.precision_manufacturing_outlined,
              size: 16, color: ErpColors.textMuted)),
      items: _machines
          .map((m) => DropdownMenuItem(
                value: m.id,
                child: Text(
                  'Machine ${m.machineCode}'
                  '${m.isMaintenance ? '  · in maintenance' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _machineId = v),
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Select a machine' : null,
    );
  }

  Widget _severityPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _severities.map((s) {
        final selected = _severity == s;
        final color = switch (s) {
          'critical' => ErpColors.errorRed,
          'high' => ErpColors.warningAmber,
          'medium' => ErpColors.accentBlue,
          _ => ErpColors.textMuted,
        };
        return ChoiceChip(
          label: Text(s[0].toUpperCase() + s.substring(1)),
          selected: selected,
          selectedColor: color,
          backgroundColor: ErpColors.bgMuted,
          side: BorderSide(
              color: selected ? color : ErpColors.borderLight),
          labelStyle: TextStyle(
            color: selected ? Colors.white : ErpColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          onSelected: (_) => setState(() => _severity = s),
        );
      }).toList(),
    );
  }
}
