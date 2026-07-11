import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../PurchaseOrder/services/theme.dart';
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

  final ImagePicker _picker = ImagePicker();

  /// Presents a camera / gallery chooser, then loads the selected photo.
  Future<void> pickImage() async {
    final source = await Get.bottomSheet<ImageSource>(
      Container(
        decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add defect photo',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: ErpColors.accentBlue),
              title: const Text('Take photo'),
              onTap: () => Get.back(result: ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: ErpColors.accentBlue),
              title: const Text('Choose from gallery'),
              onTap: () => Get.back(result: ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (source == null) return;
    await _loadFrom(source);
  }

  Future<void> _loadFrom(ImageSource source) async {
    // Inferred type (XFile / PickedFile depending on image_picker version)
    // — both expose readAsBytes() and path, so we don't name XFile or use
    // .name, keeping this tolerant across image_picker versions.
    final file = await _picker.pickImage(
      source: source,
      // Keep the base64 payload well under the backend's 4MB cap.
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    imageBytes = bytes;
    final name = file.path.split('/').last.split('\\').last;
    imageName = name.isEmpty ? 'photo.jpg' : name;
    final ext = imageName.contains('.') ? imageName.split('.').last.toLowerCase() : 'jpg';
    final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    imageDataUrl.value = 'data:$mime;base64,${base64Encode(bytes)}';
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
