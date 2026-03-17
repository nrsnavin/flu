import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/cont.dart';
import '../models/models.dart';

// ══════════════════════════════════════════════════════════════
//  WARPING PLAN PAGE  —  Create Warping Plan
//
//  NESTED Obx FIXES (this revision):
//  All child widgets (_BeamCountCard, _StepperField, _BeamCard,
//  _SectionRow dropdown, _TotalEndsCard, _SubmitButton,
//  _AiGenerateButton, _AiBadge) previously had their own Obx
//  wrappers while already sitting inside the single outer Obx
//  in _WarpingPlanPageState.build(). Removed every nested Obx.
//  Only the one outer Obx remains — all children just read
//  observable values directly and rebuild with it.
// ══════════════════════════════════════════════════════════════

class WarpingPlanPage extends StatefulWidget {
  final String jobId;
  final String warpingId;
  const WarpingPlanPage({super.key, required this.jobId, required this.warpingId});

  @override
  State<WarpingPlanPage> createState() => _WarpingPlanPageState();
}

class _WarpingPlanPageState extends State<WarpingPlanPage> {
  late final WarpingPlanController c;

  @override
  void initState() {
    super.initState();
    Get.delete<WarpingPlanController>(force: true);
    c = Get.put(WarpingPlanController(widget.jobId, widget.warpingId));
  }

  @override
  void dispose() {
    Get.delete<WarpingPlanController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      // ── Single outer Obx — no nested Obx anywhere below ────
      body: Obx(() {
        if (c.isLoading.value && c.warpYarns.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.warpYarns.isEmpty) {
          return _ErrorState(msg: c.errorMsg.value!, retry: () {});
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          children: [
            if (c.warpYarns.isEmpty)
              _WarnBanner(
                  'No warp yarns found for this job. Check the elastic configuration.'),

            // ── AI generate button ─────────────────────────
            _AiGenerateButton(c: c),
            const SizedBox(height: 12),

            // ── AI badge (visible after generation / prefill) ──
            if (c.aiRemarks.value != null)
              _AiBadge(
                  remarks: c.aiRemarks.value!,
                  onDismiss: c.clearAiBadge),

            // ── Combine mode banner ────────────────────────
            if (c.isCombineMode.value)
              _CombineBanner(c: c),

            // ── Beam count ─────────────────────────────────
            _BeamCountCard(c: c),
            const SizedBox(height: 12),

            // ── Beam cards ─────────────────────────────────
            ...c.beams.asMap().entries.map((e) => _BeamCard(
              c: c,
              beam: e.value,
              beamIndex: e.key,
              isCombineMode: c.isCombineMode.value,
              isSelected: c.selectedBeams.contains(e.key),
              selectionOrder: c.selectedBeams.indexOf(e.key),
            )),
            const SizedBox(height: 12),

            // ── Totals ─────────────────────────────────────
            _TotalEndsCard(c: c),
            const SizedBox(height: 16),

            // ── Submit ─────────────────────────────────────
            _SubmitButton(c: c),
          ],
        );
      }),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: Get.back),
    titleSpacing: 4,
    title: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Create Warping Plan', style: ErpTextStyles.pageTitle),
        Text('Warping  ›  Plan  ›  Create',
            style: TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 10)),
      ],
    ),
    bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F))),
    actions: [
      Obx(() => IconButton(
        tooltip: c.isCombineMode.value ? 'Exit Combine Mode' : 'Combine Beams',
        icon: Icon(
          c.isCombineMode.value ? Icons.call_split_rounded : Icons.merge_rounded,
          size: 20,
          color: c.isCombineMode.value ? const Color(0xFFFBBF24) : Colors.white70,
        ),
        onPressed: c.toggleCombineMode,
      )),
    ],
  );
}

// ════════════════════════════════════════════════════════════
//  AI GENERATE BUTTON
//  No Obx — reads c.isGenerating directly (inside outer Obx)
// ════════════════════════════════════════════════════════════
class _AiGenerateButton extends StatelessWidget {
  final WarpingPlanController c;
  const _AiGenerateButton({required this.c});

  @override
  Widget build(BuildContext context) {
    final generating = c.isGenerating.value; // read directly — inside outer Obx
    return GestureDetector(
      onTap: generating ? null : c.generateFromAi,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: generating
              ? const LinearGradient(
              colors: [Color(0xFF1B2B45), Color(0xFF1B2B45)])
              : const LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2B45)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: generating
                ? const Color(0xFF2A3F5F)
                : const Color(0xFF1D6FEB).withOpacity(0.5),
          ),
          boxShadow: generating
              ? []
              : [
            BoxShadow(
                color: const Color(0xFF1D6FEB).withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: generating
                ? const SizedBox(
              key: ValueKey('spin'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Color(0xFF1D6FEB), strokeWidth: 2.5),
            )
                : const Icon(Icons.auto_awesome_rounded,
                key: ValueKey('icon'),
                size: 22,
                color: Color(0xFF1D6FEB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  generating
                      ? 'Claude is generating a plan…'
                      : 'Generate with AI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: generating
                        ? const Color(0xFF8BAAC8)
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  generating
                      ? 'Analysing elastic spec — this may take a few seconds'
                      : 'Let Claude suggest beams, sections and ends based on the elastic spec',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF8BAAC8)),
                ),
              ],
            ),
          ),
          if (!generating)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1D6FEB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Generate',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  AI BADGE
//  Pure StatelessWidget — no Obx (parent Obx controls visibility)
// ════════════════════════════════════════════════════════════
class _AiBadge extends StatelessWidget {
  final String remarks;
  final VoidCallback onDismiss;
  const _AiBadge({required this.remarks, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    decoration: BoxDecoration(
      color: const Color(0xFF16A34A).withOpacity(0.07),
      border:
      Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle_rounded,
          size: 16, color: Color(0xFF16A34A)),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'AI plan loaded — review and edit before submitting',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A))),
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(remarks,
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF5A6A85),
                      height: 1.4)),
            ],
          ],
        ),
      ),
      GestureDetector(
        onTap: onDismiss,
        child: const Padding(
          padding: EdgeInsets.all(2),
          child:
          Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
        ),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════════
//  COMBINE BANNER
//  Shown when combine mode is active. Explains the flow and
//  shows which beams are currently selected.
// ════════════════════════════════════════════════════════════
class _CombineBanner extends StatelessWidget {
  final WarpingPlanController c;
  const _CombineBanner({required this.c});

  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final sel = c.selectedBeams;
    final String msg = sel.isEmpty
        ? 'Tap the FIRST beam to combine'
        : sel.length == 1
        ? 'Beam ${c.beams[sel[0]].beamNo} selected — tap the SECOND beam'
        : 'Combining…';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _amber.withOpacity(0.5)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _amber.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.merge_rounded, size: 18, color: _amber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Combine Mode Active',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _amber)),
              const SizedBox(height: 2),
              Text(msg,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF92400E))),
              const SizedBox(height: 3),
              const Text(
                'Sections from both beams are merged. Ends are halved — '
                    'odd ends get 1 extra in the first beam.',
                style: TextStyle(fontSize: 9, color: Color(0xFFB45309)),
              ),
            ],
          ),
        ),
        // Cancel button
        GestureDetector(
          onTap: c.toggleCombineMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _amber)),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  BEAM COUNT CARD
//  No Obx — reads c.beamCount.value directly (inside outer Obx)
// ════════════════════════════════════════════════════════════
class _BeamCountCard extends StatelessWidget {
  final WarpingPlanController c;
  const _BeamCountCard({required this.c});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
    title: 'NUMBER OF BEAMS',
    icon: Icons.table_rows_rounded,
    child: Row(children: [
      const Expanded(
          child: Text('Total beams in this warping run',
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12))),
      const SizedBox(width: 12),
      _StepperField(
        value: c.beamCount.value,   // read directly — no nested Obx needed
        onChanged: c.updateBeamCount,
      ),
    ]),
  );
}

// No Obx — receives value as plain int, parent Obx drives rebuilds
class _StepperField extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;
  const _StepperField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: () {
          if (value > 1) onChanged(value - 1);
        },
        child: Container(
            width: 32,
            height: 36,
            alignment: Alignment.center,
            child: const Icon(Icons.remove,
                size: 16, color: ErpColors.textSecondary)),
      ),
      Container(
        width: 44,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            border: Border(
                left: BorderSide(color: ErpColors.borderLight),
                right: BorderSide(color: ErpColors.borderLight))),
        child: Text('$value',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: ErpColors.textPrimary)),
      ),
      InkWell(
        onTap: () => onChanged(value + 1),
        child: Container(
            width: 32,
            height: 36,
            alignment: Alignment.center,
            child: const Icon(Icons.add,
                size: 16, color: ErpColors.textSecondary)),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════════
//  BEAM CARD
//  No Obx — Column reads beam directly (inside outer Obx)
// ════════════════════════════════════════════════════════════
class _BeamCard extends StatelessWidget {
  final WarpingPlanController c;
  final EditableBeam beam;
  final int beamIndex;
  final bool isCombineMode;
  final bool isSelected;
  final int selectionOrder; // -1 if not selected, 0 = first, 1 = second
  const _BeamCard({
    required this.c,
    required this.beam,
    required this.beamIndex,
    this.isCombineMode  = false,
    this.isSelected     = false,
    this.selectionOrder = -1,
  });

  static const _combineAccent = Color(0xFFF59E0B); // amber

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? _combineAccent
        : isCombineMode
        ? _combineAccent.withOpacity(0.35)
        : ErpColors.borderLight;

    return GestureDetector(
        onTap: isCombineMode ? () => c.toggleBeamSelection(beamIndex) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? _combineAccent.withOpacity(0.06)
                : ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
            boxShadow: [
              BoxShadow(
                  color: ErpColors.navyDark.withOpacity(0.04),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beam header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                    color: isSelected
                        ? _combineAccent.withOpacity(0.12)
                        : ErpColors.navyDark.withOpacity(0.03),
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7))),
                child: Row(children: [
                  // Combine selection badge
                  if (isCombineMode) ...[
                    Container(
                      width: 22, height: 22,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _combineAccent : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? _combineAccent : _combineAccent.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                        child: Text(
                          '${selectionOrder + 1}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      )
                          : null,
                    ),
                  ],
                  Text('Beam ${beam.beamNo}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? _combineAccent : ErpColors.textPrimary)),
                  const Spacer(),
                  // Hide repeat button in combine mode
                  if (!isCombineMode) ...[
                    Tooltip(
                      message: 'Repeat beam ${beam.beamNo}',
                      child: GestureDetector(
                        onTap: () => c.repeatBeam(beamIndex),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.copy_all_rounded, size: 12, color: Color(0xFF7C3AED)),
                            SizedBox(width: 4),
                            Text('Repeat', style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                            )),
                          ]),
                        ),
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: isSelected
                            ? _combineAccent.withOpacity(0.15)
                            : ErpColors.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${beam.totalEnds} Ends',
                        style: TextStyle(
                            color: isSelected ? _combineAccent : ErpColors.accentBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
              // Section rows — not interactive in combine mode
              ...beam.sections.asMap().entries.map((e) => IgnorePointer(
                ignoring: isCombineMode,
                child: _SectionRow(
                  c: c,
                  beam: beam,
                  beamIndex: beamIndex,
                  section: e.value,
                  sectionIndex: e.key,
                ),
              )),
              // Add section — hidden in combine mode
              if (!isCombineMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: TextButton.icon(
                    onPressed: () => c.addSection(beamIndex),
                    icon: const Icon(Icons.add_circle_outline,
                        size: 14, color: ErpColors.accentBlue),
                    label: const Text('Add Section',
                        style: TextStyle(
                            color: ErpColors.accentBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ));
  }
}

// ════════════════════════════════════════════════════════════
//  SECTION ROW  (pure StatelessWidget — no local state)
//
//  Both TextEditingControllers (ends + maxMeters) are owned by
//  WarpingPlanController and synced via _syncControllers().
// ════════════════════════════════════════════════════════════
class _SectionRow extends StatelessWidget {
  final WarpingPlanController c;
  final EditableBeam beam;
  final EditableBeamSection section;
  final int beamIndex;
  final int sectionIndex;
  const _SectionRow({
    required this.c,
    required this.beam,
    required this.section,
    required this.beamIndex,
    required this.sectionIndex,
  });

  @override
  Widget build(BuildContext context) {
    final bi        = beamIndex;
    final si        = sectionIndex;
    final canRemove = beam.sections.length > 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: ErpColors.borderLight))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Section number badge
            Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                  color: ErpColors.bgMuted, shape: BoxShape.circle),
              child: Center(
                  child: Text('${si + 1}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: ErpColors.textSecondary))),
            ),
            const SizedBox(width: 8),

            // Yarn dropdown
            Expanded(
              child: DropdownButtonFormField<WarpYarnOption>(
                value: c.warpYarns.firstWhereOrNull((y) => y.id == section.warpYarnId),
                decoration: ErpDecorations.formInput('Warp Yarn *'),
                style: const TextStyle(fontSize: 12, color: ErpColors.textPrimary),
                dropdownColor: ErpColors.bgSurface,
                isExpanded: true,
                items: c.warpYarns
                    .map((y) => DropdownMenuItem(
                    value: y,
                    child: Text(y.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (y) {
                  if (y == null) return;
                  c.updateYarn(bi, si, y);
                },
              ),
            ),

            // Remove button
            if (canRemove) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: ErpColors.textMuted),
                onPressed: () => c.removeSection(bi, si),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ] else
              const SizedBox(width: 28),
          ]),

          const SizedBox(height: 8),

          // Ends + Max Meters side by side
          Row(children: [
            const SizedBox(width: 30), // align with badge
            Expanded(
              child: TextFormField(
                controller: c.endsCtrl(bi, si),
                style: const TextStyle(fontSize: 12, color: ErpColors.textPrimary),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: ErpDecorations.formInput('Ends *'),
                onChanged: (v) => c.updateEnds(bi, si, int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: c.maxMetersCtrl(bi, si),
                style: const TextStyle(fontSize: 12, color: ErpColors.textPrimary),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: ErpDecorations.formInput('Meter').copyWith(
                  suffixText: 'm',
                  suffixStyle: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11),
                  hintText: 'optional',
                  hintStyle: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 10),
                ),
                onChanged: (v) =>
                    c.updateMaxMeters(bi, si, double.tryParse(v) ?? 0),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TOTAL ENDS CARD
//  No Obx — reads c.totalEnds / c.beams.length directly
// ════════════════════════════════════════════════════════════
class _TotalEndsCard extends StatelessWidget {
  final WarpingPlanController c;
  const _TotalEndsCard({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ErpColors.accentBlue.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border:
      Border.all(color: ErpColors.accentBlue.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.calculate_rounded,
          color: ErpColors.accentBlue, size: 20),
      const SizedBox(width: 12),
      Text('Total Ends: ${c.totalEnds}',
          style: const TextStyle(
              color: ErpColors.accentBlue,
              fontSize: 15,
              fontWeight: FontWeight.w900)),
      const Spacer(),
      Text('${c.beams.length} Beams',
          style: const TextStyle(
              color: ErpColors.accentBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    ]),
  );
}

// ════════════════════════════════════════════════════════════
//  SUBMIT BUTTON
//  No Obx — reads c.isSaving.value directly (inside outer Obx)
// ════════════════════════════════════════════════════════════
class _SubmitButton extends StatelessWidget {
  final WarpingPlanController c;
  const _SubmitButton({required this.c});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          backgroundColor: ErpColors.accentBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10))),
      onPressed:
      c.isSaving.value ? null : () => _validate(context),
      icon: c.isSaving.value
          ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5))
          : const Icon(Icons.save_rounded,
          color: Colors.white, size: 18),
      label: Text(
          c.isSaving.value ? 'Saving…' : 'Submit Warping Plan',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15)),
    ),
  );

  void _validate(BuildContext context) {
    if (c.beams.isEmpty) {
      _snackErr('Add at least one beam');
      return;
    }
    for (final beam in c.beams) {
      if (beam.sections.isEmpty) {
        _snackErr('Beam ${beam.beamNo}: add at least one section');
        return;
      }
      for (final s in beam.sections) {
        if (s.warpYarnId == null || s.warpYarnId!.isEmpty) {
          _snackErr(
              'Beam ${beam.beamNo}: select warp yarn for all sections');
          return;
        }
        if (s.ends <= 0) {
          _snackErr(
              'Beam ${beam.beamNo}: enter valid ends (> 0) for all sections');
          return;
        }
      }
    }
    c.submit();
  }

  void _snackErr(String msg) => Get.snackbar('Validation Error', msg,
      backgroundColor: ErpColors.errorRed,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4));
}

// ════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════
class _WarnBanner extends StatelessWidget {
  final String msg;
  const _WarnBanner(this.msg);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ErpColors.warningAmber.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
          color: ErpColors.warningAmber.withOpacity(0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline,
          color: ErpColors.warningAmber, size: 16),
      const SizedBox(width: 8),
      Expanded(
          child: Text(msg,
              style: const TextStyle(
                  color: ErpColors.warningAmber, fontSize: 11))),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorState({required this.msg, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline,
          size: 40, color: ErpColors.textMuted),
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