import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/elastic/controllers/add_elastic_controller.dart';
import 'package:production/src/features/elastic/models/cost.dart';
import 'package:production/src/features/elastic/models/raw_material.dart';
import 'package:production/src/features/elastic/screens/searchable_material_picker.dart';

import '../../PurchaseOrder/services/theme.dart';

// ════════════════════════════════════════════════════════════════
//  ADD / EDIT ELASTIC PAGE
// ════════════════════════════════════════════════════════════════
class AddElasticPage extends StatefulWidget {
  final Map<String, dynamic>? cloneData;
  final Map<String, dynamic>? editData;
  const AddElasticPage({super.key, this.cloneData, this.editData});

  @override
  State<AddElasticPage> createState() => _AddElasticPageState();
}

class _AddElasticPageState extends State<AddElasticPage> {
  late final AddElasticController c;

  @override
  void initState() {
    super.initState();
    Get.delete<AddElasticController>(force: true);
    c = Get.put(AddElasticController(
      cloneData: widget.cloneData,
      editData:  widget.editData,
    ));
    c.onSuccessCallback = () => Navigator.of(context).pop();
  }

  @override
  void dispose() {
    Get.delete<AddElasticController>(force: true);
    super.dispose();
  }

  bool get _isEdit  => widget.editData  != null;
  bool get _isClone => widget.cloneData != null;

  @override
  Widget build(BuildContext context) {
    String appBarTitle = _isEdit ? "Edit Elastic" : _isClone ? "Clone Elastic" : "New Elastic";
    String breadcrumb  = _isEdit ? "Elastics  ›  Edit"
        : _isClone ? "Elastics  ›  Clone" : "Elastics  ›  Add New";

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(appBarTitle, style: ErpTextStyles.pageTitle),
            Text(breadcrumb, style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        return Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(children: [
                _basicInfoCard(),
                const SizedBox(height: 12),
                _spandexCard(),
                const SizedBox(height: 12),
                _warpYarnCard(),
                const SizedBox(height: 12),
                // ── WARPING PLAN TEMPLATE (new section) ─────────
                _warpingPlanCard(),
                const SizedBox(height: 12),
                _weftYarnCard(),
                const SizedBox(height: 12),
                _testingParamsCard(),
                const SizedBox(height: 12),
                _costPreviewCard(),
                const SizedBox(height: 12),
                _costBreakdownCard(),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          _footerBar(),
        ]);
      }),
    );
  }

  // ── Basic Info ──────────────────────────────────────────────
  Widget _basicInfoCard() {
    return _SectionCard(
      title: "BASIC INFORMATION", icon: Icons.info_outline,
      child: Obx(() => Column(children: [
        _ErpField(label: "Elastic Name *", ctrl: c.nameCtrl,
            errorText: c.validationErrors['name'], prefix: Icons.label_outline,
            onChanged: (_) => c.clearError('name')),
        const SizedBox(height: 10),
        _ErpField(label: "Weave Type", ctrl: c.weaveTypeCtrl,
            prefix: Icons.grid_on_outlined, hint: "e.g. 8, 10, 12"),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ErpField(label: "Pick *", ctrl: c.pickCtrl,
              errorText: c.validationErrors['pick'],
              keyboard: TextInputType.number, prefix: Icons.format_list_numbered,
              onChanged: (_) => c.clearError('pick'))),
          const SizedBox(width: 10),
          Expanded(child: _ErpField(label: "No. of Hooks *", ctrl: c.noOfHookCtrl,
              errorText: c.validationErrors['noOfHook'],
              keyboard: TextInputType.number, prefix: Icons.tag,
              onChanged: (_) => c.clearError('noOfHook'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ErpField(label: "Weight (gm) *", ctrl: c.weightCtrl,
              errorText: c.validationErrors['weight'],
              keyboard: TextInputType.number, prefix: Icons.scale_outlined,
              onChanged: (_) => c.clearError('weight'))),
          const SizedBox(width: 10),
          Expanded(child: _ErpField(label: "Spandex Ends *", ctrl: c.spandexEndsCtrl,
              errorText: c.validationErrors['spandexEnds'],
              keyboard: TextInputType.number, prefix: Icons.settings_ethernet,
              onChanged: (_) => c.clearError('spandexEnds'))),
        ]),
      ])),
    );
  }

  // ── Spandex Config ───────────────────────────────────────────
  Widget _spandexCard() {
    return _SectionCard(
      title: "COVER ELASTOMER CONFIGURATION", icon: Icons.flash_on_outlined,
      child: Obx(() => Column(children: [
        _MaterialPickerField(label: "Warp Spandex *", value: c.warpSpandex.value,
            errorText: c.validationErrors['warpSpandex'],
            onTap: () => showMaterialPicker(title: "Select Warp Spandex",
                materials: c.rubberMaterials, onSelected: (v) {
                  c.warpSpandex.value = v; c.clearError('warpSpandex'); c.calculateCost();
                })),
        const SizedBox(height: 8),
        _ErpField(label: "Spandex Weight (gm) *", ctrl: c.warpSpandexWeightCtrl,
            errorText: c.validationErrors['warpSpandexWeight'],
            keyboard: TextInputType.number, prefix: Icons.scale_outlined,
            onChanged: (_) { c.clearError('warpSpandexWeight'); c.calculateCost(); }),
        const SizedBox(height: 14),
        _MaterialPickerField(label: "Covering", value: c.spandexCovering.value,
            onTap: () => showMaterialPicker(title: "Select Covering",
                materials: c.coveringMaterials, onSelected: (v) {
                  c.spandexCovering.value = v; c.calculateCost();
                })),
        const SizedBox(height: 8),
        _ErpField(label: "Covering Weight (gm)", ctrl: c.coveringWeightCtrl,
            keyboard: TextInputType.number, prefix: Icons.scale_outlined,
            onChanged: (_) => c.calculateCost()),
      ])),
    );
  }

  // ── Warp Yarn ────────────────────────────────────────────────
  Widget _warpYarnCard() {
    return _SectionCard(
      title: "WARP YARN CONFIGURATION", icon: Icons.view_column_outlined,
      child: Column(children: [
        Obx(() => Column(
          children: List.generate(c.warpYarns.length, (i) => _WarpYarnRowCard(
            index: i, row: c.warpYarns[i], materials: c.warpMaterials,
            errorText: c.validationErrors['warpYarn_$i'],
            onRemove: () => c.removeWarpYarnRow(i),
            onChanged: () {
              c.clearError('warpYarn_$i');
              c.warpYarns.refresh();
              c.calculateCost();
            },
          )),
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: c.addWarpYarnRow,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.accentBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.add, size: 16, color: ErpColors.accentBlue),
              label: const Text("Add Warp Yarn",
                  style: TextStyle(color: ErpColors.accentBlue, fontWeight: FontWeight.w600)),
            )),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  WARPING PLAN TEMPLATE CARD
  // ════════════════════════════════════════════════════════════
  Widget _warpingPlanCard() {
    return _SectionCard(
      title: "WARPING PLAN TEMPLATE",
      icon:  Icons.table_rows_outlined,
      accentColor: const Color(0xFF7C3AED),
      child: Column(children: [

        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.06),
            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 13, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Optional. When a warping is created for a job containing this elastic, "
                    "this plan is auto-applied — saving operators from re-entering beam data.",
                style: TextStyle(fontSize: 11, color: ErpColors.textSecondary, height: 1.45),
              ),
            ),
          ]),
        ),

        // Beam count stepper row
        Obx(() => Row(children: [
          const Expanded(child: Text("Number of Beams",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: ErpColors.textPrimary))),
          _StepperWidget(
            value:     c.planBeamCount.value,
            min: 1, max: 12,
            onChanged: c.updatePlanBeamCount,
          ),
        ])),
        const SizedBox(height: 14),

        // One card per beam
        Obx(() => Column(
          children: c.planBeams.asMap().entries.map((entry) =>
              _PlanBeamCard(c: c, beamIdx: entry.key, beam: entry.value)
          ).toList(),
        )),
      ]),
    );
  }

  // ── Weft Yarn ────────────────────────────────────────────────
  Widget _weftYarnCard() {
    return _SectionCard(
      title: "WEFT YARN CONFIGURATION", icon: Icons.linear_scale,
      child: Obx(() => Column(children: [
        _MaterialPickerField(label: "Weft Yarn", value: c.weftYarn.value,
            onTap: () => showMaterialPicker(title: "Select Weft Yarn",
                materials: c.weftMaterials, onSelected: (v) {
                  c.weftYarn.value = v; c.calculateCost();
                })),
        const SizedBox(height: 8),
        _ErpField(label: "Weft Weight (gm)", ctrl: c.weftWeightCtrl,
            keyboard: TextInputType.number, prefix: Icons.scale_outlined,
            onChanged: (_) => c.calculateCost()),
      ])),
    );
  }

  // ── Testing Parameters ───────────────────────────────────────
  Widget _testingParamsCard() {
    return _SectionCard(
      title: "TESTING PARAMETERS", icon: Icons.science_outlined,
      child: Obx(() => Column(children: [
        Row(children: [
          Expanded(child: _ErpField(label: "Width (mm)", ctrl: c.widthCtrl,
              errorText: c.validationErrors['width'],
              keyboard: TextInputType.number, prefix: Icons.straighten,
              onChanged: (_) => c.clearError('width'))),
          const SizedBox(width: 10),
          Expanded(child: _ErpField(label: "Elongation (%)", ctrl: c.elongationCtrl,
              errorText: c.validationErrors['elongation'],
              keyboard: TextInputType.number, prefix: Icons.expand,
              onChanged: (_) => c.clearError('elongation'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ErpField(label: "Recovery (%)", ctrl: c.recoveryCtrl,
              errorText: c.validationErrors['recovery'],
              keyboard: TextInputType.number, prefix: Icons.replay,
              onChanged: (_) => c.clearError('recovery'))),
          const SizedBox(width: 10),
          Expanded(child: _ErpField(label: "Stretch Type", ctrl: c.stretchCtrl,
              prefix: Icons.compare_arrows)),
        ]),
      ])),
    );
  }

  // ── Cost Preview ─────────────────────────────────────────────
  Widget _costPreviewCard() {
    return Obx(() => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          ErpColors.accentBlue.withOpacity(0.06),
          ErpColors.successGreen.withOpacity(0.06),
        ]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.accentBlue.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: ErpColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.calculate_outlined, color: ErpColors.successGreen, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("ESTIMATED MATERIAL COST",
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text("₹${c.totalCost.value.toStringAsFixed(2)}",
              style: const TextStyle(color: ErpColors.successGreen, fontSize: 22,
                  fontWeight: FontWeight.w900)),
        ])),
      ]),
    ));
  }

  Widget _costBreakdownCard() {
    return Obx(() {
      if (c.costBreakdown.isEmpty) return const SizedBox();
      return _CostBreakdown(items: c.costBreakdown, total: c.totalCost.value);
    });
  }

  // ── Footer bar ───────────────────────────────────────────────
  Widget _footerBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: const Border(top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [BoxShadow(color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, -3))],
      ),
      child: Row(children: [
        Expanded(flex: 1, child: SizedBox(height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text("Cancel",
                  style: TextStyle(color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
            ))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Obx(() => SizedBox(height: 44,
            child: ElevatedButton.icon(
              onPressed: c.loading.value ? null : (_isEdit ? c.updateElastic : c.submitElastic),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEdit ? ErpColors.warningAmber : ErpColors.accentBlue,
                disabledBackgroundColor: (_isEdit ? ErpColors.warningAmber : ErpColors.accentBlue)
                    .withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: c.loading.value
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isEdit ? Icons.save_outlined : Icons.check, size: 16, color: Colors.white),
              label: Text(
                c.loading.value
                    ? (_isEdit ? "Updating…" : "Saving…")
                    : (_isEdit ? "Update Elastic" : "Save Elastic"),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            )))),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  PLAN BEAM CARD
// ══════════════════════════════════════════════════════════════
class _PlanBeamCard extends StatelessWidget {
  final AddElasticController c;
  final int beamIdx;
  final PlanBeam beam;
  const _PlanBeamCard({required this.c, required this.beamIdx, required this.beam});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: ErpColors.navyDark.withOpacity(0.03),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // ── Beam header ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: const BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${beam.beamNo}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                      color: Color(0xFF7C3AED))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Beam ${beam.beamNo}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary))),
            // Total ends chip
            Obx(() {
              // Access planBeams to rebuild when sections change
              final total = c.planBeams.length > beamIdx
                  ? c.planBeams[beamIdx].totalEnds : 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.08),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$total ends total',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED))),
              );
            }),
          ]),
        ),

        // ── Section rows ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(children: [
            ...List.generate(beam.sections.length, (si) =>
                _PlanSectionRow(
                  c: c, beamIdx: beamIdx, secIdx: si,
                  section: beam.sections[si],
                  canRemove: beam.sections.length > 1,
                )),
            // Add section button
            GestureDetector(
              onTap: () => c.addPlanSection(beamIdx),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 5),
                  const Text('Add Section',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}


// ── Plan section row ─────────────────────────────────────────
class _PlanSectionRow extends StatelessWidget {
  final AddElasticController c;
  final int beamIdx, secIdx;
  final PlanSection section;
  final bool canRemove;

  const _PlanSectionRow({
    required this.c, required this.beamIdx, required this.secIdx,
    required this.section, required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    // planYarnOptions reads warpYarns — rebuild when warpYarns change
    return Obx(() {
      final yarns = c.planYarnOptions;

      // If the currently saved yarn is no longer in the list, clear it
      if (section.warpYarnId != null &&
          yarns.every((y) => y.id != section.warpYarnId)) {
        section.warpYarnId   = null;
        section.warpYarnName = null;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          // Section index badge
          Container(
            width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: Text('${secIdx + 1}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED))),
          ),
          const SizedBox(width: 8),

          // Yarn dropdown
          Expanded(
            flex: 3,
            child: yarns.isEmpty
                ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: ErpColors.borderLight),
                  borderRadius: BorderRadius.circular(4),
                  color: ErpColors.bgSurface,
                ),
                child: const Text("Add warp yarn above first",
                    style: TextStyle(fontSize: 11, color: ErpColors.textMuted)))
                : DropdownButtonFormField<String>(
              value: yarns.any((y) => y.id == section.warpYarnId)
                  ? section.warpYarnId : null,
              decoration: ErpDecorations.formInput('Warp Yarn'),
              isExpanded: true,
              dropdownColor: ErpColors.bgSurface,
              style: const TextStyle(fontSize: 12, color: ErpColors.textPrimary),
              items: yarns.map((y) => DropdownMenuItem(
                value: y.id,
                child: Text(y.name, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (id) {
                if (id == null) return;
                c.setPlanSectionYarn(
                    beamIdx, secIdx, yarns.firstWhere((y) => y.id == id));
              },
            ),
          ),
          const SizedBox(width: 8),

          // Ends field
          SizedBox(
            width: 76,
            child: TextFormField(
              controller: section.endsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: ErpColors.textPrimary),
              decoration: ErpDecorations.formInput('Ends'),
              onChanged: (_) => c.planBeams.refresh(),
            ),
          ),
          const SizedBox(width: 6),

          // Remove button (or spacer)
          if (canRemove)
            GestureDetector(
              onTap: () => c.removePlanSection(beamIdx, secIdx),
              child: const Icon(Icons.remove_circle_outline,
                  size: 18, color: ErpColors.errorRed),
            )
          else
            const SizedBox(width: 18),
        ]),
      );
    });
  }
}


// ── Beam count stepper widget ─────────────────────────────────
class _StepperWidget extends StatelessWidget {
  final int value, min, max;
  final void Function(int) onChanged;
  const _StepperWidget({required this.value, required this.min,
    required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: ErpColors.borderMid),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
          onTap: () { if (value > min) onChanged(value - 1); },
          child: Container(width: 34, height: 38, alignment: Alignment.center,
              child: Icon(Icons.remove, size: 16,
                  color: value <= min ? ErpColors.textMuted : ErpColors.textSecondary)),
        ),
        Container(
          width: 46, height: 38, alignment: Alignment.center,
          decoration: const BoxDecoration(border: Border.symmetric(
              vertical: BorderSide(color: ErpColors.borderLight))),
          child: Text('$value',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                  color: ErpColors.textPrimary)),
        ),
        InkWell(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
          onTap: () { if (value < max) onChanged(value + 1); },
          child: Container(width: 34, height: 38, alignment: Alignment.center,
              child: Icon(Icons.add, size: 16,
                  color: value >= max ? ErpColors.textMuted : ErpColors.textSecondary)),
        ),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  Warp Yarn Row Card  (unchanged from original)
// ══════════════════════════════════════════════════════════════
class _WarpYarnRowCard extends StatelessWidget {
  final int index;
  final dynamic row;
  final List<RawMaterialMini> materials;
  final String? errorText;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _WarpYarnRowCard({required this.index, required this.row,
    required this.materials, required this.onRemove,
    required this.onChanged, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: errorText != null
            ? ErpColors.errorRed.withOpacity(0.5) : ErpColors.borderLight),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(color: ErpColors.bgSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              border: Border(bottom: BorderSide(color: ErpColors.borderLight))),
          child: Row(children: [
            Container(width: 22, height: 22, alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: Text("${index + 1}", style: const TextStyle(
                    color: ErpColors.accentBlue, fontSize: 11, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            const Expanded(child: Text("Warp Yarn",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                    color: ErpColors.textPrimary))),
            GestureDetector(onTap: onRemove,
                child: Container(padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: ErpColors.errorRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.delete_outline, color: ErpColors.errorRed, size: 16))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _MaterialPickerField(label: "Material", value: row.material,
                onTap: () => showMaterialPicker(title: "Select Warp Yarn Material",
                    materials: materials, onSelected: (v) { row.material = v; onChanged(); })),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(controller: row.endsCtrl,
                  keyboardType: TextInputType.number, style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput("Ends"),
                  onChanged: (_) => onChanged())),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: row.typeCtrl,
                  style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput("Type"),
                  onChanged: (_) => onChanged())),
            ]),
            const SizedBox(height: 8),
            TextFormField(controller: row.weightCtrl,
                keyboardType: TextInputType.number, style: ErpTextStyles.fieldValue,
                decoration: ErpDecorations.formInput("Weight (gm)",
                  prefix: const Icon(Icons.scale_outlined, size: 18, color: ErpColors.textMuted),
                ).copyWith(
                  errorText: errorText,
                  enabledBorder: errorText != null ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: ErpColors.errorRed.withOpacity(0.6))) : null,
                ),
                onChanged: (_) => onChanged()),
          ]),
        ),
      ]),
    );
  }
}


// ── Cost Breakdown  (unchanged from original) ─────────────────
class _CostBreakdown extends StatelessWidget {
  final List<CostItem> items;
  final double total;
  const _CostBreakdown({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<CostItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return Container(
      decoration: BoxDecoration(color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          title: Row(children: [
            Container(width: 3, height: 12, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: ErpColors.successGreen,
                    borderRadius: BorderRadius.circular(2))),
            const Icon(Icons.receipt_long_outlined, size: 13, color: ErpColors.textSecondary),
            const SizedBox(width: 6),
            const Text("COST BREAKDOWN", style: ErpTextStyles.sectionHeader),
          ]),
          subtitle: Text("Total: ₹${total.toStringAsFixed(2)}",
              style: const TextStyle(color: ErpColors.successGreen, fontSize: 12,
                  fontWeight: FontWeight.w700)),
          children: grouped.entries.map((entry) {
            final catTotal = entry.value.fold<double>(0, (s, i) => s + i.cost);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: ErpColors.textPrimary)),
                  trailing: Text("₹${catTotal.toStringAsFixed(2)}", style: const TextStyle(
                      color: ErpColors.accentBlue, fontWeight: FontWeight.w800, fontSize: 13)),
                  children: entry.value.map((item) => Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600, color: ErpColors.textPrimary)),
                            Text("${item.weight}g × ₹${item.rate}/kg",
                                style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
                          ])),
                      Text("₹${item.cost.toStringAsFixed(2)}", style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13, color: ErpColors.textPrimary)),
                    ]),
                  )).toList(),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  SHARED WIDGETS  (unchanged from original)
// ══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accentColor;
  const _SectionCard({required this.title, required this.icon,
    required this.child, this.accentColor = ErpColors.accentBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ErpColors.bgSurface, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
          boxShadow: [BoxShadow(color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: ErpColors.bgMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: ErpColors.borderLight))),
          child: Row(children: [
            Container(width: 3, height: 12, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
            Icon(icon, size: 13, color: ErpColors.textSecondary),
            const SizedBox(width: 6),
            Text(title, style: ErpTextStyles.sectionHeader),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}

class _ErpField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? errorText;
  final TextInputType keyboard;
  final IconData? prefix;
  final String? hint;
  final ValueChanged<String>? onChanged;
  const _ErpField({required this.label, required this.ctrl, this.errorText,
    this.keyboard = TextInputType.text, this.prefix, this.hint, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl, keyboardType: keyboard, style: ErpTextStyles.fieldValue,
      onChanged: onChanged,
      decoration: ErpDecorations.formInput(label, hint: hint,
        prefix: prefix != null ? Icon(prefix, size: 18, color: ErpColors.textMuted) : null,
      ).copyWith(
        errorText: errorText,
        enabledBorder: errorText != null ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: ErpColors.errorRed.withOpacity(0.6))) : null,
        focusedBorder: errorText != null ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: ErpColors.errorRed)) : null,
        errorStyle: const TextStyle(color: ErpColors.errorRed, fontSize: 10),
      ),
    );
  }
}

class _MaterialPickerField extends StatelessWidget {
  final String label;
  final RawMaterialMini? value;
  final String? errorText;
  final VoidCallback onTap;
  const _MaterialPickerField({required this.label, required this.value,
    required this.onTap, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: ErpColors.bgSurface,
                border: Border.all(color: errorText != null
                    ? ErpColors.errorRed.withOpacity(0.6)
                    : value != null ? ErpColors.accentBlue.withOpacity(0.4)
                    : ErpColors.borderLight),
                borderRadius: BorderRadius.circular(4)),
            child: Row(children: [
              Icon(Icons.line_axis, size: 18,
                  color: errorText != null ? ErpColors.errorRed
                      : value != null ? ErpColors.accentBlue : ErpColors.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(
                    color: errorText != null ? ErpColors.errorRed
                        : value != null ? ErpColors.accentBlue : ErpColors.textSecondary,
                    fontSize: value != null ? 10 : 13, fontWeight: FontWeight.w500)),
                if (value != null) ...[
                  const SizedBox(height: 1),
                  Text(value!.name, style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: ErpColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ],
              ])),
              if (value != null)
                Text("₹${value!.price}/kg",
                    style: const TextStyle(color: ErpColors.textMuted, fontSize: 11))
              else
                const Text("Select", style: TextStyle(color: ErpColors.textMuted, fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: ErpColors.textMuted, size: 20),
            ]),
          )),
      if (errorText != null)
        Padding(padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(errorText!, style: const TextStyle(
                color: ErpColors.errorRed, fontSize: 10))),
    ]);
  }
}