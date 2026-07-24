import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide MultipartFile, FormData;

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  VISION QC — AI-assisted defect capture
//  Mirrors prod/api/qc.js (jobs-for-qc, vision-draft, create, recent).
// ══════════════════════════════════════════════════════════════

class QcElastic {
  final String id;
  final String name;
  final Map<String, dynamic> testingParameters;
  QcElastic(this.id, this.name, this.testingParameters);
  factory QcElastic.fromJson(Map<String, dynamic> j) => QcElastic(
        (j['_id'] ?? '').toString(),
        (j['name'] ?? '').toString(),
        (j['testingParameters'] is Map)
            ? Map<String, dynamic>.from(j['testingParameters'])
            : const {},
      );
}

class QcJob {
  final String id;
  final int jobOrderNo;
  final String status;
  final String customerName;
  final List<QcElastic> elastics;
  QcJob(this.id, this.jobOrderNo, this.status, this.customerName, this.elastics);
  factory QcJob.fromJson(Map<String, dynamic> j) {
    final els = <QcElastic>[];
    for (final e in (j['elastics'] as List? ?? [])) {
      final el = (e is Map) ? e['elastic'] : null;
      if (el is Map) els.add(QcElastic.fromJson(Map<String, dynamic>.from(el)));
    }
    return QcJob(
      (j['_id'] ?? '').toString(),
      (j['jobOrderNo'] ?? 0) is int ? j['jobOrderNo'] : int.tryParse('${j['jobOrderNo']}') ?? 0,
      (j['status'] ?? '').toString(),
      (j['customer'] is Map ? j['customer']['name'] : '')?.toString() ?? '',
      els,
    );
  }
}

class QcResultRow {
  String parameter;
  String expected;
  String measured;
  bool pass;
  QcResultRow(this.parameter, this.expected, this.measured, this.pass);
  factory QcResultRow.fromJson(Map<String, dynamic> j) => QcResultRow(
        (j['parameter'] ?? '').toString(),
        (j['expected'] ?? '').toString(),
        (j['measured'] ?? '').toString(),
        j['pass'] == true,
      );
  Map<String, dynamic> toJson() =>
      {'parameter': parameter, 'expected': expected, 'measured': measured, 'pass': pass};
}

class QcRecent {
  final String overallResult, defectCode, notes, elasticName, customerName, createdAt;
  final num rejectedMeters;
  final bool aiAssisted;
  final int jobOrderNo;
  QcRecent(this.overallResult, this.defectCode, this.notes, this.elasticName,
      this.customerName, this.createdAt, this.rejectedMeters, this.aiAssisted, this.jobOrderNo);
  factory QcRecent.fromJson(Map<String, dynamic> j) => QcRecent(
        (j['overallResult'] ?? 'pass').toString(),
        (j['defectCode'] ?? '').toString(),
        (j['notes'] ?? '').toString(),
        (j['elastic'] is Map ? j['elastic']['name'] : '')?.toString() ?? '',
        (j['job'] is Map && j['job']['customer'] is Map ? j['job']['customer']['name'] : '')?.toString() ?? '',
        (j['createdAt'] ?? '').toString(),
        (j['rejectedMeters'] ?? 0) as num,
        j['aiAssisted'] == true,
        (j['job'] is Map ? (j['job']['jobOrderNo'] ?? 0) : 0) as int,
      );
}

class QcApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/qc');

  static Future<List<QcJob>> jobsForQc() async {
    final res = await _dio.get('/jobs-for-qc');
    return (res.data['jobs'] as List? ?? [])
        .map((e) => QcJob.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<QcRecent>> recent() async {
    final res = await _dio.get('/recent');
    return (res.data['records'] as List? ?? [])
        .map((e) => QcRecent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Map<String, dynamic>> visionDraft(
      String elasticId, Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'elasticId': elasticId,
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/vision-draft', data: form);
    return Map<String, dynamic>.from(res.data);
  }

  static Future<void> create(Map<String, dynamic> body) async {
    await _dio.post('/create', data: body);
  }

  static Future<TrainingReadiness> trainingReadiness() async {
    final res = await _dio.get('/training-readiness');
    return TrainingReadiness.fromJson(Map<String, dynamic>.from(res.data));
  }
}

// Mirrors GET /api/v2/qc/training-readiness (prod/api/qc.js). Tracks how
// close the labelled QC photos are to a trainable defect dataset — the
// flywheel where every AI draft an inspector corrects becomes a sample.
class ReadinessClass {
  final String defectCode;
  final int count;
  ReadinessClass(this.defectCode, this.count);
}

class TrainingReadiness {
  final int minSamples, minClasses, minPerClass;
  final int qcRecords, labelledImages, aiAssisted, aiAssistedShare;
  final List<ReadinessClass> classes;
  final int classesReady, progressPct;
  final bool ready;
  final String recommendation;

  TrainingReadiness({
    required this.minSamples,
    required this.minClasses,
    required this.minPerClass,
    required this.qcRecords,
    required this.labelledImages,
    required this.aiAssisted,
    required this.aiAssistedShare,
    required this.classes,
    required this.classesReady,
    required this.progressPct,
    required this.ready,
    required this.recommendation,
  });

  factory TrainingReadiness.fromJson(Map<String, dynamic> j) {
    final th = Map<String, dynamic>.from(j['thresholds'] ?? {});
    final t = Map<String, dynamic>.from(j['totals'] ?? {});
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    return TrainingReadiness(
      minSamples: n(th['MIN_SAMPLES']),
      minClasses: n(th['MIN_CLASSES']),
      minPerClass: n(th['MIN_PER_CLASS']),
      qcRecords: n(t['qcRecords']),
      labelledImages: n(t['labelledImages']),
      aiAssisted: n(t['aiAssisted']),
      aiAssistedShare: n(t['aiAssistedShare']),
      classes: (j['classes'] as List? ?? [])
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            return ReadinessClass('${m['defectCode'] ?? '(unlabelled)'}', n(m['count']));
          })
          .toList(),
      classesReady: n(j['classesReady']),
      progressPct: n(j['progressPct']),
      ready: j['ready'] == true,
      recommendation: '${j['recommendation'] ?? ''}',
    );
  }
}

class QcController extends GetxController {
  final recent = <QcRecent>[].obs;
  final isLoading = false.obs;
  final readiness = Rxn<TrainingReadiness>();

  @override
  void onInit() {
    super.onInit();
    fetchRecent();
    fetchReadiness();
  }

  Future<void> fetchRecent() async {
    isLoading.value = true;
    try {
      recent.value = await QcApi.recent();
    } catch (_) {
      // leave list as-is
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchReadiness() async {
    try {
      readiness.value = await QcApi.trainingReadiness();
    } catch (_) {
      // Non-fatal — the card just won't render.
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([fetchRecent(), fetchReadiness()]);
  }
}
