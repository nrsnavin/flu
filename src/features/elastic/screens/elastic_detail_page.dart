import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/elastic/controllers/elastic_detail_controller.dart';
import 'package:production/src/features/elastic/models/raw_material.dart';

import '../../PurchaseOrder/services/theme.dart';
import 'addElastic.dart';

class ElasticDetailPage extends StatefulWidget {
  final String elasticId;
  const ElasticDetailPage({super.key, required this.elasticId});

  @override
  State<ElasticDetailPage> createState() => _ElasticDetailPageState();
}

class _ElasticDetailPageState extends State<ElasticDetailPage> {
  late final ElasticDetailController c;

  @override
  void initState() {
    super.initState();
    Get.delete<ElasticDetailController>(force: true);
    c = Get.put(ElasticDetailController(widget.elasticId));
  }

  @override
  void dispose() {
    Get.delete<ElasticDetailController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DetailView(c: c);
}

class _DetailView extends StatelessWidget {
  final ElasticDetailController c;
  const _DetailView({required this.c});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(context),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        final e = c.elastic;
        if (e.isEmpty) {
          return const Center(child: Text("Elastic not found"));
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(children: [
              _HeroCard(e: e),
              const SizedBox(height: 12),
              _BasicInfoSection(e: e),
              const SizedBox(height: 10),
              _SpandexSection(e: e),
              const SizedBox(height: 10),
              _WarpYarnsSection(e: e),
              const SizedBox(height: 10),
              _WeftYarnSection(e: e),
              const SizedBox(height: 10),
              _TestingSection(e: e),
              const SizedBox(height: 10),
              // ── Warping Plan Template ────────────────────────
              _WarpingPlanSection(c: c, e: e),
              const SizedBox(height: 10),
              _CostingSection(c: c),
            ]),
          ),
        );
      }),
      floatingActionButton: Obx(() {
        if (c.elastic.isEmpty) return const SizedBox();
        return FloatingActionButton.extended(
          backgroundColor: ErpColors.accentBlue,
          icon: const Icon(Icons.copy_outlined, color: Colors.white),
          label: const Text("Clone",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          onPressed: c.cloneElastic,
        );
      }),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final elasticName = c.elastic["name"] ?? "this elastic";
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: ErpColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline, color: ErpColors.errorRed, size: 20)),
          const SizedBox(width: 12),
          const Text("Delete Elastic", style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
        ]),
        content: RichText(text: TextSpan(
          style: const TextStyle(fontSize: 13, color: ErpColors.textSecondary, height: 1.5),
          children: [
            const TextSpan(text: "Are you sure you want to delete "),
            TextSpan(text: elasticName, style: const TextStyle(
                fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            const TextSpan(text: "?\n\nThis will permanently remove the elastic and its "
                "costing data. This action cannot be undone."),
          ],
        )),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("Cancel",
                  style: TextStyle(color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: ErpColors.errorRed,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
              label: const Text("Delete",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )),
          ]),
        ],
      ),
    );
    if (confirmed == true) {
      c.deleteElastic(onDeleted: () => Navigator.of(context).pop());
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: ErpColors.navyDark, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      actions: [
        Obx(() {
          if (c.elastic.isEmpty) return const SizedBox();
          return Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              onPressed: c.loading.value ? null : () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFFC8181)),
              tooltip: "Delete Elastic",
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: c.loading.value ? null : () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddElasticPage(
                      editData: Map<String, dynamic>.from(c.elastic),
                    ),
                  ));
                  c.fetchDetail();
                },
                style: TextButton.styleFrom(
                  backgroundColor: ErpColors.warningAmber.withOpacity(0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14, color: ErpColors.warningAmber),
                label: const Text("Edit", style: TextStyle(color: ErpColors.warningAmber,
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ]);
        }),
      ],
      title: Flexible(child: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.elastic["name"] ?? "Elastic Detail", style: ErpTextStyles.pageTitle,
              overflow: TextOverflow.ellipsis),
          const Text("Elastics  ›  Detail",
              style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      ))),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  WARPING PLAN SECTION  (detail page)
// ══════════════════════════════════════════════════════════════
class _WarpingPlanSection extends StatelessWidget {
  final ElasticDetailController c;
  final Map<String, dynamic> e;
  const _WarpingPlanSection({required this.c, required this.e});

  @override
  Widget build(BuildContext context) {
    final tpl  = e["warpingPlanTemplate"];
    final beams = (tpl?["beams"] as List?);
    final hasPlan = beams != null && beams.isNotEmpty;

    return _Card(
      title: "WARPING PLAN TEMPLATE",
      icon:  Icons.table_rows_outlined,
      accentColor: const Color(0xFF7C3AED),
      action: Obx(() => c.savingPlan.value
          ? const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : TextButton.icon(
        onPressed: () => _openPlanSheet(context),
        style: TextButton.styleFrom(
          backgroundColor: hasPlan
              ? ErpColors.warningAmber.withOpacity(0.15)
              : const Color(0xFF7C3AED).withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        icon: Icon(hasPlan ? Icons.edit_outlined : Icons.add,
            size: 13,
            color: hasPlan ? ErpColors.warningAmber : const Color(0xFF7C3AED)),
        label: Text(hasPlan ? "Edit" : "Add Plan",
            style: TextStyle(
                color: hasPlan ? ErpColors.warningAmber : const Color(0xFF7C3AED),
                fontSize: 12, fontWeight: FontWeight.w700)),
      )),
      child: hasPlan ? _planContent(context, beams!) : _emptyState(),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.table_rows_outlined, size: 24, color: Color(0xFF7C3AED))),
        const SizedBox(height: 10),
        const Text("No warping plan template yet",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: ErpColors.textSecondary)),
        const SizedBox(height: 4),
        const Text("Tap Add Plan to configure beam & section data.\nIt will be auto-applied when creating warpings.",
            style: TextStyle(fontSize: 11, color: ErpColors.textMuted, height: 1.5),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _planContent(BuildContext context, List beams) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary chips
      Wrap(spacing: 8, runSpacing: 6, children: [
        _PlanChip("${beams.length} beam${beams.length != 1 ? 's' : ''}",
            Icons.view_week_outlined),
        _PlanChip(
          "${beams.fold<int>(0, (s, b) => s + ((b["totalEnds"] ?? 0) as int))} total ends",
          Icons.settings_ethernet,
        ),
      ]),
      const SizedBox(height: 12),
      // Beam cards
      ...beams.asMap().entries.map((entry) =>
          _PlanBeamReadCard(beam: entry.value, index: entry.key)),
    ]);
  }

  void _openPlanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarpingPlanSheet(c: c),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlanChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.08),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.22)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: Color(0xFF7C3AED))),
      ]),
    );
  }
}

class _PlanBeamReadCard extends StatelessWidget {
  final Map beam;
  final int index;
  const _PlanBeamReadCard({required this.beam, required this.index});

  @override
  Widget build(BuildContext context) {
    final sections = (beam["sections"] as List? ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(children: [
        // Beam header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Container(width: 26, height: 26, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('${beam["beamNo"] ?? index + 1}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                        color: Color(0xFF7C3AED)))),
            const SizedBox(width: 8),
            Expanded(child: Text('Beam ${beam["beamNo"] ?? index + 1}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary))),
            Text('${beam["totalEnds"] ?? 0} ends',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED))),
          ]),
        ),
        // Sections
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: sections.asMap().entries.map((se) {
            final s = se.value as Map;
            final yarnName = s["warpYarn"] is Map
                ? (s["warpYarn"]["name"] ?? "—")
                : "—";
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 18, height: 18, alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withOpacity(0.09), shape: BoxShape.circle),
                    child: Text('${se.key + 1}', style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800, color: ErpColors.accentBlue))),
                const SizedBox(width: 8),
                Expanded(child: Text(yarnName, style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: ErpColors.textPrimary))),
                Text('${s["ends"] ?? 0} ends',
                    style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ]),
            );
          }).toList()),
        ),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  WARPING PLAN BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class _WarpingPlanSheet extends StatefulWidget {
  final ElasticDetailController c;
  const _WarpingPlanSheet({required this.c});

  @override
  State<_WarpingPlanSheet> createState() => _WarpingPlanSheetState();
}

class _WarpingPlanSheetState extends State<_WarpingPlanSheet> {
  // Local mutable state for the sheet
  late List<_SheetBeam> _beams;
  int _beamCount = 1;

  @override
  void initState() {
    super.initState();
    _loadFromTemplate();
  }

  void _loadFromTemplate() {
    final tpl = widget.c.currentTemplate;
    if (tpl != null && (tpl["beams"] as List?)?.isNotEmpty == true) {
      _beams = (tpl["beams"] as List).map((b) {
        final sections = (b["sections"] as List? ?? []).map((s) {
          final yarnId = s["warpYarn"] is Map
              ? (s["warpYarn"]["_id"] ?? s["warpYarn"]["id"])?.toString()
              : s["warpYarn"]?.toString();
          return _SheetSection(
            yarnId:   yarnId ?? "",

          );
        }).toList();
        return _SheetBeam(
          beamNo: (b["beamNo"] as num?)?.toInt() ?? _beams.length + 1,
          sections: sections.isEmpty ? [_SheetSection()] : sections,
        );
      }).toList();
      _beamCount = _beams.length;
    } else {
      _beams = [_SheetBeam(beamNo: 1)];
      _beamCount = 1;
    }
  }

  void _setBeamCount(int n) {
    if (n < 1 || n > 12) return;
    setState(() {
      if (n > _beams.length) {
        for (var i = _beams.length; i < n; i++) {
          _beams.add(_SheetBeam(beamNo: i + 1));
        }
      } else {
        for (var i = _beams.length - 1; i >= n; i--) {
          _beams[i].dispose();
          _beams.removeAt(i);
        }
      }
      _beamCount = n;
    });
  }

  void _addSection(int bi) {
    setState(() => _beams[bi].sections.add(_SheetSection()));
  }

  void _removeSection(int bi, int si) {
    if (_beams[bi].sections.length <= 1) return;
    setState(() {
      _beams[bi].sections[si].dispose();
      _beams[bi].sections.removeAt(si);
    });
  }

  Map<String, dynamic>? _buildPayload() {
    bool any = false;
    final beams = _beams.map((b) {
      final sections = b.sections
          .where((s) => s.yarnId.isNotEmpty && (int.tryParse(s.endsCtrl.text) ?? 0) > 0)
          .map((s) => {"warpYarn": s.yarnId, "ends": int.parse(s.endsCtrl.text)})
          .toList();
      if (sections.isNotEmpty) any = true;
      final total = sections.fold<int>(0, (sum, s) => sum + (s["ends"] as int));
      return {"beamNo": b.beamNo, "totalEnds": total, "sections": sections};
    }).toList();
    if (!any) return null;
    return {"noOfBeams": beams.length, "beams": beams};
  }

  Future<void> _save() async {
    final payload = _buildPayload();
    final ok = await widget.c.savePlanTemplate(payload);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final b in _beams) b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yarns = widget.c.warpYarnOptions;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: ErpColors.bgBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          // Handle + header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: ErpColors.bgSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Column(children: [
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: ErpColors.borderMid,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 10),
              Row(children: [
                Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_rows_outlined, size: 16, color: Color(0xFF7C3AED))),
                const SizedBox(width: 12),
                const Expanded(child: Text("Warping Plan Template",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary))),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: ErpColors.textMuted, size: 20),
                ),
              ]),
            ]),
          ),

          // Scrollable body
          Expanded(child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.06),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.18)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 13, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    yarns.isEmpty
                        ? "No warp yarns found on this elastic. Add warp yarns first via Edit."
                        : "Configure beams and yarn sections. This template will be auto-applied when creating warpings for jobs containing this elastic.",
                    style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary, height: 1.45),
                  )),
                ]),
              ),

              // Beam count stepper
              Row(children: [
                const Expanded(child: Text("Number of Beams",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: ErpColors.textPrimary))),
                _SheetStepper(value: _beamCount, min: 1, max: 12,
                    onChanged: _setBeamCount),
              ]),
              const SizedBox(height: 14),

              // Beam cards
              ...List.generate(_beams.length, (bi) =>
                  _SheetBeamCard(
                    beam:     _beams[bi],
                    beamIdx:  bi,
                    yarns:    yarns,
                    onAddSection:    () => _addSection(bi),
                    onRemoveSection: (si) => _removeSection(bi, si),
                    onChanged: () => setState(() {}),
                  )),
              const SizedBox(height: 80),
            ],
          )),

          // Save / Cancel footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              border: const Border(top: BorderSide(color: ErpColors.borderLight)),
              boxShadow: [BoxShadow(color: ErpColors.navyDark.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, -3))],
            ),
            child: Row(children: [
              Expanded(flex: 1, child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ErpColors.borderMid),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text("Cancel",
                    style: TextStyle(color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: Obx(() => ElevatedButton.icon(
                onPressed: widget.c.savingPlan.value ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  disabledBackgroundColor: const Color(0xFF7C3AED).withOpacity(0.5),
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: widget.c.savingPlan.value
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 16, color: Colors.white),
                label: Text(widget.c.savingPlan.value ? "Saving…" : "Save Plan Template",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ))),
            ]),
          ),
        ]),
      ),
    );
  }
}


// ── Sheet beam card ────────────────────────────────────────────
class _SheetBeamCard extends StatelessWidget {
  final _SheetBeam beam;
  final int beamIdx;
  final List<Map<String, String>> yarns;
  final VoidCallback onAddSection;
  final void Function(int) onRemoveSection;
  final VoidCallback onChanged;

  const _SheetBeamCard({
    required this.beam, required this.beamIdx,
    required this.yarns,  required this.onAddSection,
    required this.onRemoveSection, required this.onChanged,
  });

  int get _totalEnds => beam.sections.fold(0,
          (s, sec) => s + (int.tryParse(sec.endsCtrl.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: const BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Container(width: 28, height: 28, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${beam.beamNo}', style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)))),
            const SizedBox(width: 10),
            Expanded(child: Text('Beam ${beam.beamNo}', style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.22)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$_totalEnds ends', style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
            ),
          ]),
        ),

        // Section rows
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(children: [
            ...List.generate(beam.sections.length, (si) =>
                _SheetSectionRow(
                  section:   beam.sections[si],
                  secIdx:    si,
                  yarns:     yarns,
                  canRemove: beam.sections.length > 1,
                  onRemove:  () => onRemoveSection(si),
                  onChanged: onChanged,
                )),
            GestureDetector(
              onTap: onAddSection,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 5),
                  const Text('Add Section', style: TextStyle(
                      fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}


// ── Sheet section row ──────────────────────────────────────────
class _SheetSectionRow extends StatelessWidget {
  final _SheetSection section;
  final int secIdx;
  final List<Map<String, String>> yarns;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SheetSectionRow({
    required this.section, required this.secIdx,
    required this.yarns,   required this.canRemove,
    required this.onRemove, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure value is valid or null (avoids assertion errors)
    final currentId = yarns.any((y) => y["id"] == section.yarnId)
        ? section.yarnId : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        // Section badge
        Container(width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.09), shape: BoxShape.circle),
            child: Text('${secIdx + 1}', style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)))),
        const SizedBox(width: 8),

        // Yarn dropdown
        Expanded(
          flex: 3,
          child: yarns.isEmpty
              ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(border: Border.all(color: ErpColors.borderLight),
                  borderRadius: BorderRadius.circular(4), color: ErpColors.bgSurface),
              child: const Text("No warp yarns found",
                  style: TextStyle(fontSize: 11, color: ErpColors.textMuted)))
              : DropdownButtonFormField<String>(
            value: currentId,
            isExpanded: true,
            dropdownColor: ErpColors.bgSurface,
            decoration: ErpDecorations.formInput('Warp Yarn'),
            style: const TextStyle(fontSize: 12, color: ErpColors.textPrimary),
            items: yarns.map((y) => DropdownMenuItem(
              value: y["id"],
              child: Text(y["name"]!, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            )).toList(),
            onChanged: (id) {
              section.yarnId = id ?? "";
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),

        // Ends
        SizedBox(width: 76,
            child: TextFormField(
              controller: section.endsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: ErpColors.textPrimary),
              decoration: ErpDecorations.formInput('Ends'),
              onChanged: (_) => onChanged(),
            )),
        const SizedBox(width: 6),

        if (canRemove)
          GestureDetector(onTap: onRemove,
              child: const Icon(Icons.remove_circle_outline,
                  size: 18, color: ErpColors.errorRed))
        else
          const SizedBox(width: 18),
      ]),
    );
  }
}


// ── Sheet stepper ──────────────────────────────────────────────
class _SheetStepper extends StatelessWidget {
  final int value, min, max;
  final void Function(int) onChanged;
  const _SheetStepper({required this.value, required this.min,
    required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: ErpColors.borderMid),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
          onTap: () { if (value > min) onChanged(value - 1); },
          child: Container(width: 34, height: 38, alignment: Alignment.center,
              child: Icon(Icons.remove, size: 16,
                  color: value <= min ? ErpColors.textMuted : ErpColors.textSecondary)),
        ),
        Container(width: 46, height: 38, alignment: Alignment.center,
            decoration: const BoxDecoration(border: Border.symmetric(
                vertical: BorderSide(color: ErpColors.borderLight))),
            child: Text('$value', style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w900, color: ErpColors.textPrimary))),
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


// ── Local mutable models for the bottom sheet ──────────────────
class _SheetSection {
  String yarnId;
  final TextEditingController endsCtrl;
  _SheetSection({this.yarnId = "", int initialEnds = 0})
      : endsCtrl = TextEditingController(
      text: initialEnds > 0 ? initialEnds.toString() : "");
  void dispose() => endsCtrl.dispose();
}

class _SheetBeam {
  int beamNo;
  final List<_SheetSection> sections;
  _SheetBeam({required this.beamNo, List<_SheetSection>? sections})
      : sections = sections ?? [_SheetSection()];
  void dispose() { for (final s in sections) s.dispose(); }
}


// ══════════════════════════════════════════════════════════════
//  REST OF THE PAGE  (unchanged from original)
// ══════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> e;
  const _HeroCard({required this.e});

  @override
  Widget build(BuildContext context) {
    final stock = (e["stock"] ?? 0).toDouble();
    final hasStock = stock > 0;
    final stockColor = hasStock ? ErpColors.successGreen : ErpColors.errorRed;

    return Container(
      decoration: BoxDecoration(color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: const BoxDecoration(color: ErpColors.navyDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Container(width: 48, height: 48,
                decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ErpColors.accentBlue.withOpacity(0.4))),
                child: const Icon(Icons.layers_outlined, size: 24, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e["name"] ?? "—", style: const TextStyle(color: Colors.white,
                  fontSize: 17, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
              Text("Weave Type: ${e["weaveType"] ?? "—"}",
                  style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text("STOCK", style: TextStyle(color: ErpColors.textOnDarkSub,
                  fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text("${stock.toStringAsFixed(1)} m", style: TextStyle(
                  color: stockColor, fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(children: [
              _Stat(label: "Pick",            value: e["pick"]?.toString()       ?? "—"),
              _Stat(label: "Hooks",           value: e["noOfHook"]?.toString()    ?? "—"),
              _Stat(label: "Weight",          value: "${e["weight"] ?? 0} gm"),
              _Stat(label: "Spandex\nEnds",   value: e["spandexEnds"]?.toString() ?? "—"),
            ])),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
          color: ErpColors.textPrimary), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: ErpColors.textMuted,
          fontWeight: FontWeight.w600, letterSpacing: 0.3), textAlign: TextAlign.center),
    ]));
  }
}

class _BasicInfoSection extends StatelessWidget {
  final Map<String, dynamic> e;
  const _BasicInfoSection({required this.e});

  @override
  Widget build(BuildContext context) {
    return _Card(title: "BASIC INFO", icon: Icons.info_outline,
        child: Column(children: [
          _Row("Weave Type",   e["weaveType"]),
          _Row("Pick",         e["pick"]?.toString()),
          _Row("No. of Hooks", e["noOfHook"]?.toString()),
          _Row("Weight",       "${e["weight"] ?? 0} gm"),
          _Row("Spandex Ends", e["spandexEnds"]?.toString()),
        ]));
  }
}

class _SpandexSection extends StatelessWidget {
  final Map<String, dynamic> e;
  const _SpandexSection({required this.e});

  @override
  Widget build(BuildContext context) {
    return _Card(title: "SPANDEX CONFIGURATION", icon: Icons.flash_on_outlined,
        child: Column(children: [
          _Row("Warp Spandex",    e["warpSpandex"]?["id"]?["name"]),
          _Row("Spandex Weight",  "${e["warpSpandex"]?["weight"] ?? 0} gm"),
          _Row("Covering",        e["spandexCovering"]?["id"]?["name"]),
          _Row("Covering Weight", "${e["spandexCovering"]?["weight"] ?? 0} gm"),
        ]));
  }
}

class _WarpYarnsSection extends StatelessWidget {
  final Map<String, dynamic> e;
  const _WarpYarnsSection({required this.e});

  @override
  Widget build(BuildContext context) {
    final yarns = (e["warpYarn"] as List? ?? []);
    if (yarns.isEmpty) return const SizedBox();
    return _Card(title: "WARP YARNS", icon: Icons.view_column_outlined,
        child: Column(children: yarns.asMap().entries.map((entry) {
          final i = entry.key;
          final w = entry.value as Map;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ErpColors.borderLight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 20, height: 20, alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withOpacity(0.1), shape: BoxShape.circle),
                    child: Text("${i + 1}", style: const TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w800, color: ErpColors.accentBlue))),
                const SizedBox(width: 8),
                Expanded(child: Text(w["id"]?["name"] ?? "—",
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                        color: ErpColors.textPrimary),
                    overflow: TextOverflow.ellipsis)),
                if ((w["type"] as String?)?.isNotEmpty == true)
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: ErpColors.statusOpenBg,
                          border: Border.all(color: ErpColors.statusOpenBorder),
                          borderRadius: BorderRadius.circular(3)),
                      child: Text(w["type"], style: const TextStyle(
                          color: ErpColors.statusOpenText, fontSize: 10, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _Chip("Ends",   w["ends"]?.toString() ?? "—"),
                const SizedBox(width: 12),
                _Chip("Weight", "${w["weight"] ?? 0} gm"),
              ]),
            ]),
          );
        }).toList()));
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text("$label: ", style: const TextStyle(color: ErpColors.textMuted,
          fontSize: 11, fontWeight: FontWeight.w600)),
      Text(value, style: const TextStyle(color: ErpColors.textPrimary,
          fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _WeftYarnSection extends StatelessWidget {
  final Map<String, dynamic> e;
  const _WeftYarnSection({required this.e});

  @override
  Widget build(BuildContext context) {
    return _Card(title: "WEFT YARN", icon: Icons.linear_scale,
        child: Column(children: [
          _Row("Material", e["weftYarn"]?["id"]?["name"]),
          _Row("Weight",   "${e["weftYarn"]?["weight"] ?? 0} gm"),
        ]));
  }
}

class _TestingSection extends StatelessWidget {
  final Map<String, dynamic> e;
  const _TestingSection({required this.e});

  @override
  Widget build(BuildContext context) {
    final tp = e["testingParameters"] as Map? ?? {};
    return _Card(title: "TESTING PARAMETERS", icon: Icons.science_outlined,
        child: Column(children: [
          _Row("Width",       "${tp["width"]  ?? "—"} mm"),
          _Row("Elongation",  "${tp["elongation"] ?? 120} %"),
          _Row("Recovery",    "${tp["recovery"] ?? 90} %"),
          if ((tp["strech"] ?? tp["stretch"]) != null)
            _Row("Stretch Type", tp["strech"] ?? tp["stretch"]),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════
//  COSTING SECTION  — with Recalculate button + breakdown sheet
// ══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
//  COSTING SECTION  — with recalculate button + breakdown
// ══════════════════════════════════════════════════════════════
class _CostingSection extends StatelessWidget {
  final ElasticDetailController c;
  const _CostingSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final costing = c.costing;
      final mat     = (costing['materialCost']   ?? 0).toDouble();
      final conv    = (costing['conversionCost'] ?? 0).toDouble();
      final total   = (costing['totalCost']      ?? 0).toDouble();
      final details = (costing['details'] as List? ?? []);

      // Last updated timestamp
      String? lastUpdated;
      try {
        if (costing['date'] != null) {
          lastUpdated = DateFormat('dd MMM yyyy, HH:mm')
              .format(DateTime.parse(costing['date'].toString()).toLocal());
        }
      } catch (_) {}

      return _Card(
        title: 'COSTING',
        icon: Icons.calculate_outlined,
        accentColor: ErpColors.successGreen,
        // ── Recalculate button ──────────────────────────────
        action: Obx(() => c.recalculating.value
            ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: ErpColors.successGreen))
            : TextButton.icon(
          onPressed: () => _showRecalcDialog(context),
          style: TextButton.styleFrom(
            backgroundColor: ErpColors.successGreen.withOpacity(0.12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
          ),
          icon: const Icon(Icons.refresh_rounded,
              size: 13, color: ErpColors.successGreen),
          label: const Text('Recalculate',
              style: TextStyle(
                  color: ErpColors.successGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Last updated stamp ──────────────────────────
            if (lastUpdated != null) ...[
              Row(children: [
                const Icon(Icons.access_time_outlined,
                    size: 11, color: ErpColors.textMuted),
                const SizedBox(width: 4),
                Text('Last updated: $lastUpdated',
                    style: const TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic)),
              ]),
              const SizedBox(height: 10),
            ],

            // ── Material breakdown table ────────────────────
            if (details.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                child: Column(children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: const BoxDecoration(
                      border: Border(bottom:
                      BorderSide(color: ErpColors.borderLight)),
                    ),
                    child: const Row(children: [
                      Expanded(flex: 3,
                          child: Text('Material',
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textMuted,
                                  letterSpacing: 0.3))),
                      SizedBox(width: 8),
                      SizedBox(width: 52,
                          child: Text('Qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textMuted))),
                      SizedBox(width: 8),
                      SizedBox(width: 52,
                          child: Text('Rate',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textMuted))),
                      SizedBox(width: 8),
                      SizedBox(width: 60,
                          child: Text('Cost',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textMuted))),
                    ]),
                  ),
                  // Detail rows
                  ...details.asMap().entries.map((entry) {
                    final i    = entry.key;
                    final d    = entry.value as Map? ?? {};
                    final qty  = (d['quantity'] as num?)?.toDouble() ?? 0;
                    final rate = (d['rate']     as num?)?.toDouble() ?? 0;
                    final cost = (d['cost']     as num?)?.toDouble() ?? 0;
                    final desc = d['description']?.toString() ?? '—';
                    final isLast = i == details.length - 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: isLast ? null : const Border(
                            bottom: BorderSide(
                                color: ErpColors.borderLight)),
                      ),
                      child: Row(children: [
                        Expanded(flex: 3,
                            child: Text(desc,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: ErpColors.textPrimary),
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        SizedBox(width: 52,
                            child: Text(qty.toStringAsFixed(3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: ErpColors.textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 52,
                            child: Text('₹${rate.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: ErpColors.textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 60,
                            child: Text('₹${cost.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ErpColors.textPrimary))),
                      ]),
                    );
                  }),
                ]),
              ),
              const SizedBox(height: 10),
            ],

            // ── Subtotals ───────────────────────────────────
            _Row('Material Cost',   '₹${mat.toStringAsFixed(2)}'),
            _Row('Conversion Cost', '₹${conv.toStringAsFixed(2)}'),
            const SizedBox(height: 8),

            // ── Total highlight box ─────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ErpColors.successGreen.withOpacity(0.06),
                border: Border.all(
                    color: ErpColors.successGreen.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL COST / MTR',
                        style: TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4)),
                    Text('₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: ErpColors.successGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ]),
            ),

            if (costing.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No costing data available',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 13)),
                ),
              ),
          ],
        ),
      );
    });
  }

  // ── Confirm dialog before recalculating ─────────────────────
  void _showRecalcDialog(BuildContext context) {
    final convCtrl = TextEditingController(
      text: (c.costing['conversionCost'] ?? 1.25).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: ErpColors.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: ErpColors.successGreen, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Recalculate Costing',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Fetches the latest raw material prices from the database '
                'and recomputes the material cost breakdown. '
                'You can also update the conversion cost below.',
            style: TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: convCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput(
              'Conversion Cost (₹/mtr)',
              prefix: const Icon(Icons.currency_rupee,
                  size: 16, color: ErpColors.textMuted),
            ),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  convCtrl.dispose();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ErpColors.borderMid),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  final conv = double.tryParse(convCtrl.text.trim());
                  convCtrl.dispose();
                  Navigator.of(context).pop();
                  c.recalculateCosting(conversionCost: conv);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.successGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: Colors.white),
                label: const Text('Recalculate & Save',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Shared card shell ──────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accentColor;
  final Widget? action;    // optional action button in header
  const _Card({required this.title, required this.icon, required this.child,
    this.accentColor = ErpColors.accentBlue, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: ErpColors.bgMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: ErpColors.borderLight))),
          child: Row(children: [
            Container(width: 3, height: 12, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: accentColor,
                    borderRadius: BorderRadius.circular(2))),
            Icon(icon, size: 13, color: ErpColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: ErpTextStyles.sectionHeader)),
            if (action != null) action!,
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final dynamic value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: ErpTextStyles.fieldLabel)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          value?.toString().isNotEmpty == true ? value.toString() : "—",
          style: ErpTextStyles.fieldValue,
        )),
      ]),
    );
  }
}