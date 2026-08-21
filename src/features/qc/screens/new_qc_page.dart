import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/qc_controller.dart';
import '../controllers/new_qc_controller.dart';
import '../../../core/widgets/scan_job_button.dart';

class NewQcPage extends StatefulWidget {
  const NewQcPage({super.key});

  @override
  State<NewQcPage> createState() => _NewQcPageState();
}

class _NewQcPageState extends State<NewQcPage> {
  late final NewQcController c;
  final _defect = TextEditingController();
  final _rejected = TextEditingController(text: '0');
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    c = Get.put(NewQcController());
  }

  @override
  void dispose() {
    _defect.dispose();
    _rejected.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('New QC check'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('Job'),
          Obx(() => _jobDropdown()),
          const SizedBox(height: 8),
          Obx(() => _jobScanButton()),
          const SizedBox(height: 14),
          _label('Elastic'),
          Obx(() => _elasticDropdown()),
          const SizedBox(height: 16),
          Obx(() => _photoCard()),
          const SizedBox(height: 16),
          // Parameters + PASS/FAIL — reactive to results.
          Obx(() {
            if (c.results.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _label('Parameters'),
                  _chip(c.overall == 'pass' ? 'PASS' : 'FAIL',
                      c.overall == 'pass' ? ErpColors.successGreen : ErpColors.errorRed),
                ]),
                const SizedBox(height: 6),
                ...List.generate(c.results.length, (i) => _resultRow(i)),
                const SizedBox(height: 12),
              ],
            );
          }),
          // Defect fields only when failing.
          Obx(() => c.overall == 'fail'
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Defect code'),
                  _textField(_defect, hint: 'e.g. weave-fault'),
                  const SizedBox(height: 12),
                  _label('Rejected (m)'),
                  _textField(_rejected, keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                ])
              : const SizedBox.shrink()),
          _label('Notes'),
          _textField(_notes, maxLines: 2),
          const SizedBox(height: 20),
          Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    foregroundColor: ErpColors.textOnDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: c.isSaving.value ? null : _save,
                  child: c.isSaving.value
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save QC check'),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _save() async {
    // Push the text fields into the controller before saving.
    c.defectCode.value = _defect.text;
    c.rejectedMeters.value = _rejected.text.isEmpty ? '0' : _rejected.text;
    c.notes.value = _notes.text;
    final err = await c.save();
    if (err == null) {
      if (Get.isRegistered<QcController>()) Get.find<QcController>().fetchRecent();
      Get.back();
      Get.snackbar('Saved', 'QC check recorded',
          backgroundColor: ErpColors.successGreen, colorText: Colors.white);
    } else {
      Get.snackbar('Error', err, backgroundColor: ErpColors.errorRed, colorText: Colors.white);
    }
  }

  Future<void> _analyze() async {
    final err = await c.analyze();
    if (err != null) {
      Get.snackbar('AI', err, backgroundColor: ErpColors.navyMid, colorText: Colors.white);
    } else {
      // Reflect the AI draft into the text controllers.
      _defect.text = c.defectCode.value;
      _rejected.text = c.rejectedMeters.value;
      _notes.text = c.notes.value;
      Get.snackbar('AI draft ready', 'Review and adjust',
          backgroundColor: ErpColors.successGreen, colorText: Colors.white);
    }
  }

  Widget _jobDropdown() {
    return Container(
      decoration: _fieldBox(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: c.selectedJobId.value.isEmpty ? null : c.selectedJobId.value,
          hint: Text(c.loadingJobs.value ? 'Loading…' : 'Select job',
              style: TextStyle(color: ErpColors.textMuted)),
          items: c.jobs
              .map((j) => DropdownMenuItem(
                  value: j.id,
                  child: Text('J-${j.jobOrderNo} · ${j.customerName} (${j.status})',
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            c.selectedJobId.value = v ?? '';
            c.selectedElasticId.value = '';
            c.results.clear();
          },
        ),
      ),
    );
  }

  /// Beside the dropdown, never instead of it. The QC check happens at
  /// the trolley with the job label on it, so scanning removes the
  /// transcription — but a torn label or a flat battery must not stop
  /// the check being recorded.
  Widget _jobScanButton() => Align(
        alignment: Alignment.centerLeft,
        child: ScanJobButton<QcJob>(
          candidates: c.jobs.toList(),
          idOf: (j) => j.id,
          jobNoOf: (j) => j.jobOrderNo,
          scopeLabel: 'jobs open for QC',
          onMatched: (job) {
            c.selectedJobId.value = job.id;
            c.selectedElasticId.value = '';
            c.results.clear();
          },
        ),
      );

  Widget _elasticDropdown() {
    final els = c.job?.elastics ?? [];
    return Container(
      decoration: _fieldBox(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: c.selectedElasticId.value.isEmpty ? null : c.selectedElasticId.value,
          hint: Text('Select elastic', style: TextStyle(color: ErpColors.textMuted)),
          items: els
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => c.selectElastic(v ?? ''),
        ),
      ),
    );
  }

  Widget _photoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: c.pickImage,
          child: Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: c.imageBytes != null
                ? Image.memory(c.imageBytes!, fit: BoxFit.cover)
                : Icon(Icons.photo_camera_outlined, color: ErpColors.textMuted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OutlinedButton.icon(
                onPressed: c.pickImage,
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: Text(c.imageBytes != null ? 'Change' : 'Add photo'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue, foregroundColor: ErpColors.textOnDark),
                onPressed: (c.selectedElasticId.value.isEmpty || c.imageBytes == null || c.isAnalyzing.value)
                    ? null
                    : _analyze,
                icon: c.isAnalyzing.value
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Analyze with AI'),
              ),
              if (c.confidence.value != null)
                _chip('${c.confidence.value}% confidence',
                    c.confidence.value! >= 70 ? ErpColors.successGreen
                        : c.confidence.value! >= 40 ? ErpColors.warningAmber : ErpColors.errorRed),
            ]),
            const SizedBox(height: 6),
            Text('AI flags visible defects and pre-fills the check. You verify every value before saving.',
                style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
          ]),
        ),
      ]),
    );
  }

  Widget _resultRow(int i) {
    final r = c.results[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.parameter, style: TextStyle(fontSize: 13, color: ErpColors.textPrimary)),
            if (r.expected.isNotEmpty)
              Text('exp ${r.expected}', style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextFormField(
            key: ValueKey('m$i-${r.parameter}'),
            initialValue: r.measured,
            onChanged: (v) => r.measured = v,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'measured',
              filled: true,
              fillColor: ErpColors.bgMuted,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            r.pass = !r.pass;
            c.results.refresh();
          },
          child: Icon(r.pass ? Icons.check_circle : Icons.cancel,
              color: r.pass ? ErpColors.successGreen : ErpColors.errorRed),
        ),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: ErpColors.textSecondary, fontSize: 13)),
      );

  Widget _textField(TextEditingController ctl, {String? hint, int maxLines = 1, TextInputType? keyboard}) =>
      TextField(
        controller: ctl,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: ErpColors.bgSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ErpColors.borderLight)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ErpColors.borderLight)),
        ),
      );

  Widget _chip(String t, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  BoxDecoration _fieldBox() => BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      );
}
