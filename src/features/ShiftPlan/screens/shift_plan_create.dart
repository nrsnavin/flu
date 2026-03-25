import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// import '../../Orders/screens/erp_theme.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shiftPlan_controller.dart';
import '../../shiftPlanView/screens/shiftPlanDetail.dart';
import '../models/MachineRunningModel.dart';
import '../models/OperatorModel.dart';

// ══════════════════════════════════════════════════════════════
//  CREATE SHIFT PLAN PAGE
// ══════════════════════════════════════════════════════════════

class CreateShiftPlanPage extends StatefulWidget {
  const CreateShiftPlanPage({super.key});

  @override
  State<CreateShiftPlanPage> createState() => _CreateShiftPlanPageState();
}

class _CreateShiftPlanPageState extends State<CreateShiftPlanPage> {
  late final CreateShiftPlanController c;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    // FIX: was Get.put at class-field level in StatelessWidget → stale instances
    Get.delete<CreateShiftPlanController>(force: true);
    c = Get.put(CreateShiftPlanController(
      onSuccess: () {
        // Navigate to detail page so supervisor can review and confirm.
        // Replace the create page so Back returns to the list.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ShiftPlanDetailPage(shiftPlanId: c.createdShiftPlanId),
          ),
        );
      },
    ));
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Obx(() {
        // ── Loading ──────────────────────────────────────────
        if (c.isLoading.value) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: ErpColors.accentBlue),
                SizedBox(height: 14),
                Text('Loading machines & operators…',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        // ── Error state ──────────────────────────────────────
        if (c.errorMsg.value != null) {
          return _ErrorState(
            message: c.errorMsg.value!,
            onRetry: c.loadData,
          );
        }

        // ── Main body ────────────────────────────────────────
        return Stack(
          children: [
            // Scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Column(
                children: [
                  _ShiftHeaderCard(c: c, descController: _descController),
                  const SizedBox(height: 12),
                  _SummaryBanner(c: c),
                  const SizedBox(height: 12),
                  _MachineListSection(c: c),
                ],
              ),
            ),
            // Sticky save bar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _SaveBar(c: c),
            ),
          ],
        );
      }),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
          Text('Create Shift Plan', style: ErpTextStyles.pageTitle),
          Text('Shifts  ›  New Plan',
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      ),
      actions: [
        // Refresh icon
        Obx(() => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value ? null : c.loadData,
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ERROR STATE
// ══════════════════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(Icons.cloud_off_outlined,
                size: 36, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text('Failed to load data',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 6),
          Text(message,
              style: const TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue, elevation: 0),
            icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHIFT HEADER CARD  (date + shift type + description)
// ══════════════════════════════════════════════════════════════
class _ShiftHeaderCard extends StatelessWidget {
  final CreateShiftPlanController c;
  final TextEditingController descController;
  const _ShiftHeaderCard({required this.c, required this.descController});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'SHIFT INFORMATION',
      icon: Icons.schedule_outlined,
      child: Column(children: [
        // ── Date + Shift row ─────────────────────────────────
        Row(children: [
          // Date picker
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: ErpColors.accentBlue),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DATE',
                          style: TextStyle(
                              color: ErpColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Obx(() => Text(
                        c.formattedDate,
                        style: const TextStyle(
                            color: ErpColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      )),
                    ],
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Shift type toggle
          Expanded(child: _ShiftToggle(c: c)),
        ]),

        const SizedBox(height: 12),

        // ── Description ──────────────────────────────────────
        TextFormField(
          controller: descController,
          maxLines: 2,
          style: ErpTextStyles.fieldValue,
          onChanged: (v) => c.description.value = v,
          decoration: ErpDecorations.formInput(
            'Description (optional)',
            hint: 'e.g. Extra care for Job #45',
            prefix: const Icon(Icons.notes_outlined,
                size: 16, color: ErpColors.textMuted),
          ),
        ),
      ]),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: c.selectedDate.value,
      firstDate: DateTime(2024),
      lastDate:  DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ErpColors.accentBlue,
            onPrimary: Colors.white,
            surface: ErpColors.bgSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) c.selectedDate.value = picked;
  }
}

// ── Shift type toggle pill ────────────────────────────────────
class _ShiftToggle extends StatelessWidget {
  final CreateShiftPlanController c;
  const _ShiftToggle({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDay = c.shiftType.value == 'DAY';
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(children: [
          _ShiftChip(
            label: 'DAY',
            icon: Icons.wb_sunny_outlined,
            active: isDay,
            activeColor: ErpColors.warningAmber,
            onTap: () => c.shiftType.value = 'DAY',
          ),
          Container(width: 1, color: ErpColors.borderLight),
          _ShiftChip(
            label: 'NIGHT',
            icon: Icons.nightlight_outlined,
            active: !isDay,
            activeColor: ErpColors.accentBlue,
            onTap: () => c.shiftType.value = 'NIGHT',
          ),
        ]),
      );
    });
  }
}

class _ShiftChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _ShiftChip({
    required this.label, required this.icon, required this.active,
    required this.activeColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: active ? Colors.white : ErpColors.textMuted),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : ErpColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SUMMARY BANNER  (machines / assigned / unassigned counts)
// ══════════════════════════════════════════════════════════════
class _SummaryBanner extends StatelessWidget {
  final CreateShiftPlanController c;
  const _SummaryBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total      = c.runningMachines.length;
      final assigned   = total - c.unassignedCount;
      final unassigned = c.unassignedCount;
      final allDone    = unassigned == 0 && total > 0;

      // Colour logic:
      //   all assigned  → green (complete)
      //   some assigned → blue (informational — partial is fine)
      //   none assigned → amber (nudge to assign at least one)
      final Color accent;
      final IconData statusIcon;
      final String statusText;

      if (allDone) {
        accent     = ErpColors.successGreen;
        statusIcon = Icons.check_circle_outline_rounded;
        statusText = 'All $total machines have operators assigned';
      } else if (assigned > 0) {
        accent     = ErpColors.accentBlue;
        statusIcon = Icons.info_outline_rounded;
        statusText = '$assigned of $total machine(s) assigned — '
            '$unassigned will be skipped';
      } else {
        accent     = ErpColors.warningAmber;
        statusIcon = Icons.warning_amber_rounded;
        statusText = 'No operators assigned yet — '
            'assign at least one machine to save';
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color:  accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(statusIcon, size: 19, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                  color: accent, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:  accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Text('$assigned/$total',
                style: TextStyle(
                    color: accent,
                    fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ]),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  MACHINE LIST SECTION
// ══════════════════════════════════════════════════════════════
class _MachineListSection extends StatelessWidget {
  final CreateShiftPlanController c;
  const _MachineListSection({required this.c});

  @override
  Widget build(BuildContext context) {
    if (c.runningMachines.isEmpty) {
      return _EmptyMachines();
    }

    return ErpSectionCard(
      title: 'MACHINE OPERATOR ASSIGNMENT (${c.runningMachines.length})',
      icon: Icons.precision_manufacturing_outlined,
      child: Column(
        children: c.runningMachines.map((m) {
          return _MachineOperatorCard(machine: m, c: c);
        }).toList(),
      ),
    );
  }
}

class _EmptyMachines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: const Icon(Icons.precision_manufacturing_outlined,
              size: 32, color: ErpColors.textMuted),
        ),
        const SizedBox(height: 14),
        const Text('No Running Machines',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        const Text(
          'All machines are idle. Assign a machine to a weaving job first.',
          style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ── Individual machine → operator card ───────────────────────
class _MachineOperatorCard extends StatelessWidget {
  final MachineRunningModel machine;
  final CreateShiftPlanController c;
  const _MachineOperatorCard({required this.machine, required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedOpId = c.machineOperatorMap[machine.machineId];
      final isAssigned   = selectedOpId != null;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isAssigned
              ? ErpColors.statusCompletedBg
              : ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isAssigned
                  ? ErpColors.statusCompletedBorder
                  : ErpColors.borderLight,
              width: isAssigned ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Machine identity row ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(children: [
                // Icon badge
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.precision_manufacturing_outlined,
                      size: 20, color: ErpColors.accentBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machine.displayName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.tag_outlined,
                            size: 11, color: ErpColors.textMuted),
                        const SizedBox(width: 3),
                        Text('Job #${machine.jobOrderNo}',
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        const Icon(Icons.memory_outlined,
                            size: 11, color: ErpColors.textMuted),
                        const SizedBox(width: 3),
                        Text('${machine.noOfHeads} heads',
                            style: const TextStyle(
                                color: ErpColors.textMuted, fontSize: 10)),
                      ]),
                    ],
                  ),
                ),
                // Assignment badge
                if (isAssigned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ErpColors.successGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color:
                          ErpColors.successGreen.withOpacity(0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 11, color: ErpColors.successGreen),
                        SizedBox(width: 3),
                        Text('Assigned',
                            style: TextStyle(
                                color: ErpColors.successGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ErpColors.warningAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color:
                          ErpColors.warningAmber.withOpacity(0.35)),
                    ),
                    child: const Text('Unassigned',
                        style: TextStyle(
                            color: ErpColors.warningAmber,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),

            // ── Operator dropdown ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: _OperatorDropdown(
                machine: machine,
                c: c,
                selectedId: selectedOpId,
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Operator dropdown (full-width, not crammed in trailing) ───
// FIX: was inside ListTile trailing (180px) → overflowed on small screens.
//      Now takes full width below machine info.
class _OperatorDropdown extends StatelessWidget {
  final MachineRunningModel machine;
  final CreateShiftPlanController c;
  final String? selectedId;
  const _OperatorDropdown({
    required this.machine, required this.c, required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      isExpanded: true,
      style: ErpTextStyles.fieldValue,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: ErpColors.textSecondary, size: 18),
      decoration: ErpDecorations.formInput(
        'Assign Operator',
        prefix: const Icon(Icons.person_outline,
            size: 16, color: ErpColors.textMuted),
      ).copyWith(
        filled: true,
        fillColor: ErpColors.bgSurface,
      ),
      hint: const Text('Select operator',
          style: TextStyle(color: ErpColors.textMuted, fontSize: 12)),
      items: [
        // "None" option to clear
        const DropdownMenuItem<String>(
          value: null,
          child: Text('— None —',
              style: TextStyle(
                  color: ErpColors.textMuted,
                  fontStyle: FontStyle.italic,
                  fontSize: 13)),
        ),
        ...c.operators.map((o) {
          return DropdownMenuItem<String>(
            value: o.id,
            child: Row(children: [
              Container(
                width: 26, height: 36,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline,
                    size: 13, color: ErpColors.accentBlue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    if (o.department != null && o.department!.isNotEmpty)
                      Text(o.department!,
                          style: const TextStyle(
                              fontSize: 10,
                              color: ErpColors.textMuted)),
                  ],
                ),
              ),
            ]),
          );
        }),
      ],
      onChanged: (val) => c.setOperator(machine.machineId, val),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  STICKY SAVE BAR
// ══════════════════════════════════════════════════════════════
class _SaveBar extends StatelessWidget {
  final CreateShiftPlanController c;
  const _SaveBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: const Border(top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Obx(() {
        final saving = c.isSaving.value;
        // Button is always active as long as there are running machines.
        // Partial assignment is fine — unassigned machines are just skipped.
        final canSave = !saving && c.runningMachines.isNotEmpty;

        return Row(children: [
          // Cancel button
          SizedBox(
            width: 90, height: 48,
            child: OutlinedButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          // Save button — always blue when machines exist
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: canSave ? c.saveShiftPlan : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  disabledBackgroundColor:
                  ErpColors.accentBlue.withOpacity(0.45),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                icon: saving
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.save_outlined,
                    size: 18, color: Colors.white),
                label: Text(
                  saving ? 'Saving…' : 'Save as Draft',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}