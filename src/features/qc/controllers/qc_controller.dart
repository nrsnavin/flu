import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';

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
      ApiClient.buildClient(baseUrl: 'http://13.233.117.153:2701/api/v2/qc');

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
}

class QcController extends GetxController {
  final recent = <QcRecent>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchRecent();
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
}
