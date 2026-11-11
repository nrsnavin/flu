import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../theme/erp_theme.dart';
import '../controllers/covering_detail_controller.dart';
import '../models/covering.dart';
import '_wt_helper.dart';

// ═════════════════════════════════════════════════════════════
//  COVERING DETAIL PAGE — worker view.
//
//  Reads `Get.arguments` either as a String (legacy: just id, view
//  mode) or as a Map { id, canRecordBeamEntries }. The covering
//  dept gets the Add Beam Entry form; warping dept just sees the
//  beam entries list, no add/delete buttons.
// ═════════════════════════════════════════════════════════════
class CoveringDetailPage extends StatefulWidget {
  const CoveringDetailPage({super.key});
  @override
  State<CoveringDetailPage> createState() => _CoveringDetailPageState();
}

class _CoveringDetailPageState extends State<CoveringDetailPage> {
  late final EmpCoveringDetailController c;
  late final bool canEdit;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    String id;
    if (args is Map) {
      id      = (args['id'] ?? '').toString();
      canEdit = args['canRecordBeamEntries'] == true;
    } else {
      id      = (args ?? '').toString();
      canEdit = false;
    }
    Get.delete<EmpCoveringDetailController>(force: true);
    c = Get.put(EmpCoveringDetailController(id,
        canRecordBeamEntries: canEdit));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _ErrorState(msg: c.errorMsg.value!, retry: c.fetchDetail);
        }
        final d = c.covering.value;
        if (d == null) {
          return _ErrorState(msg: 'Covering not found', retry: c.fetchDetail);
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              _HeroCard(data: d),
              const SizedBox(height: 12),
              _JobCard(job: d.job),
              if (d.remarks != null && d.remarks!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RemarksCard(remarks: d.remarks!),
              ],
              const SizedBox(height: 12),
              ...d.elasticPlanned.map((e) => _ElasticProgramCard(detail: e)),
              const SizedBox(height: 12),
              _BeamSection(
                data: d,
                c: c,
                canEdit: canEdit && !d.isCompleted && !d.isCancelled,
                showForm: _showForm,
                onToggleForm: () => setState(() => _showForm = !_showForm),
                onFormSaved:  () => setState(() => _showForm = false),
              ),
            ],
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: Obx(() {
          final d = c.covering.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                d != null
                    ? 'Job #${d.job.jobOrderNo}  •  Covering'
                    : 'Covering Detail',
                style: ErpTextStyles.pageTitle,
              ),
              Text(canEdit ? 'Covering  ›  Entry' : 'Covering  ›  View',
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10)),
            ],
          );
        }),
        actions: [
          Obx(() => IconButton(
                icon: c.isLoading.value
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
                onPressed: c.isLoading.value ? null : c.fetchDetail,
              )),
        ],
      );
}

class _HeroCard extends StatelessWidget {
  final CoveringDetail data;
  const _HeroCard({required this.data});

  Color _col(String s) {
    switch (s) {
      case 'open':        return ErpColors.accentBlue;
      case 'in_progress': return ErpColors.warningAmber;
      case 'completed':   return ErpColors.successGreen;
      case 'cancelled':   return ErpColors.errorRed;
      default:            return ErpColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _col(data.status);
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: const BoxDecoration(
            color: ErpColors.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: col.withValues(alpha: 0.6), width: 2),
              ),
              child: const Icon(Icons.layers_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Covering — Job #${data.job.jobOrderNo}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    if (data.job.customerName != null)
                      Text(data.job.customerName!,
                          style: const TextStyle(
                              color: ErpColors.textOnDarkSub,
                              fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.22),
                        border: Border.all(color: col.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(data.status.toUpperCase(),
                          style: TextStyle(
                              color: col,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Row(children: [
            _Stat(Icons.calendar_today_outlined, 'DATE',
                DateFormat('dd MMM yyyy').format(data.date)),
            Container(width: 1, height: 32, color: ErpColors.borderLight),
            _Stat(Icons.layers_outlined, 'ELASTICS',
                '${data.elasticPlanned.length}'),
            Container(width: 1, height: 32, color: ErpColors.borderLight),
            _Stat(Icons.scale_outlined, 'PRODUCED',
                '${wt(data.producedWeight)} kg'),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Stat(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, size: 13, color: ErpColors.textMuted),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _JobCard extends StatelessWidget {
  final JobSummary job;
  const _JobCard({required this.job});
  @override
  Widget build(BuildContext context) => ErpSectionCard(
        title: 'JOB ORDER',
        icon: Icons.work_outline_rounded,
        child: Column(children: [
          _Row('Job #',      '${job.jobOrderNo}'),
          if (job.customerName != null) _Row('Customer',  job.customerName!),
          if (job.po != null)           _Row('PO No.',    job.po!),
          if (job.orderNo != null)      _Row('Order No.', job.orderNo!),
          _Row('Job Status', job.status),
        ]),
      );
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 96,
            child: Text(label.toUpperCase(),
                style: ErpTextStyles.fieldLabel),
          ),
          Expanded(
            child: Text(value, style: ErpTextStyles.fieldValue),
          ),
        ]),
      );
}

class _RemarksCard extends StatelessWidget {
  final String remarks;
  const _RemarksCard({required this.remarks});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.warningAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: ErpColors.warningAmber.withValues(alpha: 0.4)),
        ),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notes_rounded,
                  size: 14, color: ErpColors.warningAmber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(remarks,
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
      );
}

class _ElasticProgramCard extends StatelessWidget {
  final CoveringElasticDetail detail;
  const _ElasticProgramCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final el = detail.elastic;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: ErpDecorations.card,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A2D4A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.grain_rounded,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(el.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                        Text('${el.weaveType}  •  ${detail.quantity} m planned',
                            style: const TextStyle(
                                color: ErpColors.textOnDarkSub,
                                fontSize: 10)),
                      ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  _SpecBox(Icons.straighten_outlined, 'WEIGHT',
                      '${el.weight} g'),
                  _SpecBox(Icons.linear_scale_outlined, 'SPANDEX ENDS',
                      '${el.spandexEnds}'),
                  _SpecBox(Icons.format_list_numbered_rtl_outlined,
                      'YARN ENDS', '${el.yarnEnds}'),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _SpecBox(Icons.view_week_outlined, 'PICK',
                      '${el.pick}'),
                  _SpecBox(Icons.tune_rounded, 'NO. OF HOOK',
                      '${el.noOfHook}'),
                  _SpecBox(Icons.layers_outlined, 'PLANNED',
                      '${detail.quantity} m'),
                ]),
                if (el.testing != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ErpColors.borderLight),
                    ),
                    child: Row(children: [
                      _TestBox(
                        'WIDTH',
                        el.testing!.width != null
                            ? '${el.testing!.width} mm'
                            : '—',
                        ErpColors.accentBlue,
                      ),
                      _TestBox('ELONGATION',
                          '${el.testing!.elongation}%',
                          ErpColors.successGreen),
                      _TestBox('RECOVERY',
                          '${el.testing!.recovery}%',
                          ErpColors.warningAmber),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
    );
  }
}

class _SpecBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _SpecBox(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(children: [
            Icon(icon, size: 14, color: ErpColors.textSecondary),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _TestBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TestBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3),
              textAlign: TextAlign.center),
        ]),
      );
}

// ─── Beam section ─────────────────────────────────────────────────
class _BeamSection extends StatelessWidget {
  final CoveringDetail data;
  final EmpCoveringDetailController c;
  final bool canEdit;
  final bool showForm;
  final VoidCallback onToggleForm;
  final VoidCallback onFormSaved;
  const _BeamSection({
    required this.data,
    required this.c,
    required this.canEdit,
    required this.showForm,
    required this.onToggleForm,
    required this.onFormSaved,
  });

  @override
  Widget build(BuildContext context) {
    final entries = data.beamEntries;
    return Container(
      decoration: ErpDecorations.card,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: const BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(8)),
                border:
                    Border(bottom: BorderSide(color: ErpColors.borderLight)),
              ),
              child: Row(children: [
                Container(
                  width: 3, height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: ErpColors.successGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(Icons.scale_outlined,
                    size: 13, color: ErpColors.textSecondary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('BEAM ENTRIES',
                      style: TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                ),
                if (data.producedWeight > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ErpColors.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: ErpColors.successGreen.withValues(alpha: 0.35)),
                    ),
                    child: Text('${wt(data.producedWeight)} kg',
                        style: const TextStyle(
                            color: ErpColors.successGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                if (canEdit) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      onToggleForm();
                      if (!showForm) c.beamNoCtrl.text = '${c.nextBeamNo}';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: showForm
                            ? ErpColors.errorRed.withValues(alpha: 0.10)
                            : ErpColors.accentBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: showForm
                              ? ErpColors.errorRed.withValues(alpha: 0.35)
                              : ErpColors.accentBlue.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          showForm ? Icons.close_rounded : Icons.add_rounded,
                          size: 13,
                          color: showForm
                              ? ErpColors.errorRed
                              : ErpColors.accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          showForm ? 'Cancel' : 'Add Beam',
                          style: TextStyle(
                              color: showForm
                                  ? ErpColors.errorRed
                                  : ErpColors.accentBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
            if (showForm && canEdit)
              _BeamEntryForm(c: c, onSaved: onFormSaved),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No beam entries yet',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 12)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                    children: entries
                        .map((be) => _BeamEntryRow(entry: be))
                        .toList()),
              ),
          ]),
    );
  }
}

class _BeamEntryForm extends StatelessWidget {
  final EmpCoveringDetailController c;
  final VoidCallback onSaved;
  const _BeamEntryForm({required this.c, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1F35),
        border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Beam Entry',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: c.beamNoCtrl,
                  keyboardType: TextInputType.number,
                  style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput(
                    'Beam No *',
                    hint: '1',
                    prefix: const Icon(Icons.view_week_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: c.beamWtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput(
                    'Weight (kg) *',
                    hint: '0.000',
                    prefix: const Icon(Icons.scale_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: c.beamNoteCtrl,
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput(
                'Note (optional)',
                hint: 'Any observation about this beam…',
                prefix: const Icon(Icons.notes_rounded,
                    size: 16, color: ErpColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() => SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ErpColors.successGreen,
                      disabledBackgroundColor:
                          ErpColors.successGreen.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: c.isAddingBeam.value
                        ? null
                        : () async {
                            final ok = await c.addBeamEntry();
                            if (ok) onSaved();
                          },
                    icon: c.isAddingBeam.value
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.add_circle_outline_rounded,
                            size: 16, color: Colors.white),
                    label: Text(
                      c.isAddingBeam.value ? 'Saving…' : 'Add Beam Entry',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                )),
          ]),
    );
  }
}

class _BeamEntryRow extends StatelessWidget {
  final BeamEntry entry;
  const _BeamEntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: ErpColors.accentBlue.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${entry.beamNo}',
                  style: const TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
              const Text('BM',
                  style: TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.scale_outlined,
                      size: 12, color: ErpColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${wt(entry.weight)} kg',
                      style: const TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                  if (entry.enteredByName != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.person_outline,
                        size: 11, color: ErpColors.textMuted),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(entry.enteredByName!,
                          style: const TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(DateFormat('dd MMM yyyy  HH:mm').format(entry.enteredAt),
                    style: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 10)),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(entry.note,
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis),
                ],
              ]),
        ),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorState({required this.msg, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined,
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
            icon: const Icon(Icons.refresh,
                size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
