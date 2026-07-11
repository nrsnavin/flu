import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'qc_controller.dart';

// Drives the "New QC check" capture flow.
class NewQcController extends GetxController {
  final jobs = <QcJob>[].obs;
  final loadingJobs = false.obs;

  final selectedJobId = ''.obs;
  final selectedElasticId = ''.obs;

  Uint8List? imageBytes;
  String imageName = '';
  final imageDataUrl = ''.obs;

  final results = <QcResultRow>[].obs;
  final defectCode = ''.obs;
  final rejectedMeters = '0'.obs;
  final notes = ''.obs;
  final confidence = RxnInt();
  final aiAssisted = false.obs;

  final isAnalyzing = false.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadJobs();
  }

  QcJob? get job => jobs.firstWhereOrNull((j) => j.id == selectedJobId.value);
  QcElastic? get elastic =>
      job?.elastics.firstWhereOrNull((e) => e.id == selectedElasticId.value);

  String get overall =>
      results.isNotEmpty && results.every((r) => r.pass) ? 'pass' : results.isEmpty ? 'pass' : 'fail';

  Future<void> loadJobs() async {
    loadingJobs.value = true;
    try {
      jobs.value = await QcApi.jobsForQc();
    } catch (_) {
    } finally {
      loadingJobs.value = false;
    }
  }

  void selectElastic(String id) {
    selectedElasticId.value = id;
    // Seed result rows from the elastic's testing parameters.
    final tp = elastic?.testingParameters ?? const {};
    final rows = <QcResultRow>[];
    void add(String p, dynamic v) {
      if (v != null && v is! Map && v is! List) rows.add(QcResultRow(p, '$v', '', true));
    }
    add('Width (mm)', tp['width']);
    add('Elongation (%)', tp['elongation']);
    tp.forEach((k, v) {
      if (k == 'width' || k == 'elongation') return;
      add(k, v);
    });
    results.value = rows;
    confidence.value = null;
    aiAssisted.value = false;
    defectCode.value = '';
    notes.value = '';
  }

  Future<void> pickImage() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    if (f.bytes == null) return;
    imageBytes = f.bytes;
    imageName = f.name;
    final ext = (f.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    imageDataUrl.value = 'data:$mime;base64,${base64Encode(f.bytes!)}';
  }

  Future<String?> analyze() async {
    if (selectedElasticId.value.isEmpty || imageBytes == null) {
      return 'Pick an elastic and a photo first';
    }
    isAnalyzing.value = true;
    try {
      final res = await QcApi.visionDraft(selectedElasticId.value, imageBytes!, imageName);
      if (res['available'] != true) return (res['message'] ?? 'AI vision not configured').toString();
      if (res['ok'] != true || res['draft'] == null) {
        return (res['message'] ?? "Couldn't read the image — fill it manually").toString();
      }
      final d = Map<String, dynamic>.from(res['draft']);
      final rows = (d['results'] as List? ?? [])
          .map((e) => QcResultRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (rows.isNotEmpty) results.value = rows;
      defectCode.value = (d['defectCode'] ?? '').toString();
      rejectedMeters.value = '${d['rejectedMetersHint'] ?? 0}';
      notes.value = (d['notes'] ?? '').toString();
      confidence.value = (d['confidence'] ?? 0) is int
          ? d['confidence']
          : int.tryParse('${d['confidence']}') ?? 0;
      aiAssisted.value = true;
      if (res['image'] != null) imageDataUrl.value = res['image'].toString();
      return null; // success
    } catch (e) {
      return 'Analysis failed';
    } finally {
      isAnalyzing.value = false;
    }
  }

  Future<String?> save() async {
    if (selectedJobId.value.isEmpty || selectedElasticId.value.isEmpty) {
      return 'Select a job and elastic';
    }
    if (results.isEmpty || results.any((r) => r.measured.trim().isEmpty)) {
      return 'Every parameter needs a measured value';
    }
    isSaving.value = true;
    try {
      await QcApi.create({
        'jobId': selectedJobId.value,
        'elasticId': selectedElasticId.value,
        'results': results.map((r) => r.toJson()).toList(),
        'defectCode': overall == 'fail' ? defectCode.value : '',
        'rejectedMeters': num.tryParse(rejectedMeters.value) ?? 0,
        'notes': notes.value,
        'image': imageDataUrl.value,
        'aiAssisted': aiAssisted.value,
      });
      return null;
    } catch (e) {
      return 'Save failed';
    } finally {
      isSaving.value = false;
    }
  }
}
