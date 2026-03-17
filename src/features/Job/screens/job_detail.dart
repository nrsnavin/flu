import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../PurchaseOrder/services/theme.dart';

// ════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════

class ElasticQty {
  final String? elasticId;
  final String elasticName;
  final double quantity;
  const ElasticQty({
    this.elasticId,
    required this.elasticName,
    required this.quantity,
  });
  factory ElasticQty.fromJson(Map<String, dynamic> j) => ElasticQty(
    elasticId: j['elasticId']?.toString(),
    elasticName: j['elasticName']?.toString() ?? '-',
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
  );
}

class BeamSection {
  final int sectionNo, ends;
  final String yarnName, yarnUnit;
  const BeamSection({
    required this.sectionNo,
    required this.ends,
    required this.yarnName,
    required this.yarnUnit,
  });
  factory BeamSection.fromJson(Map<String, dynamic> j) => BeamSection(
    sectionNo: (j['sectionNo'] as num?)?.toInt() ?? 0,
    ends: (j['ends'] as num?)?.toInt() ?? 0,
    yarnName: j['yarnName']?.toString() ?? '-',
    yarnUnit: j['yarnUnit']?.toString() ?? '',
  );
}

class BeamModel {
  final int beamNo, totalEnds;
  final List<BeamSection> sections;
  const BeamModel({
    required this.beamNo,
    required this.totalEnds,
    required this.sections,
  });
  factory BeamModel.fromJson(Map<String, dynamic> j) => BeamModel(
    beamNo: (j['beamNo'] as num?)?.toInt() ?? 0,
    totalEnds: (j['totalEnds'] as num?)?.toInt() ?? 0,
    sections: (j['sections'] as List<dynamic>?)
        ?.map((s) => BeamSection.fromJson(s as Map<String, dynamic>))
        .toList() ??
        [],
  );
}

class JobWarping {
  final String status, remarks;
  final String? date, completedDate;
  final int noOfBeams;
  final List<BeamModel> beams;
  const JobWarping({
    required this.status,
    required this.remarks,
    required this.date,
    required this.completedDate,
    required this.noOfBeams,
    required this.beams,
  });
  factory JobWarping.fromJson(Map<String, dynamic> j) => JobWarping(
    status: j['status']?.toString() ?? 'open',
    remarks: j['remarks']?.toString() ?? '',
    date: j['date']?.toString(),
    completedDate: j['completedDate']?.toString(),
    noOfBeams: (j['noOfBeams'] as num?)?.toInt() ?? 0,
    beams: (j['beams'] as List<dynamic>?)
        ?.map((b) => BeamModel.fromJson(b as Map<String, dynamic>))
        .toList() ??
        [],
  );
}

class JobCovering {
  final String status, remarks;
  final String? date, completedDate;
  final List<ElasticQty> elasticPlanned;
  const JobCovering({
    required this.status,
    required this.remarks,
    required this.date,
    required this.completedDate,
    required this.elasticPlanned,
  });
  factory JobCovering.fromJson(Map<String, dynamic> j) => JobCovering(
    status: j['status']?.toString() ?? 'open',
    remarks: j['remarks']?.toString() ?? '',
    date: j['date']?.toString(),
    completedDate: j['completedDate']?.toString(),
    elasticPlanned: (j['elasticPlanned'] as List<dynamic>?)
        ?.map((e) => ElasticQty.fromJson(e as Map<String, dynamic>))
        .toList() ??
        [],
  );
}

class HeadElastic {
  final int head;
  final String elasticName;
  const HeadElastic({required this.head, required this.elasticName});
  factory HeadElastic.fromJson(Map<String, dynamic> j) => HeadElastic(
    head: (j['head'] as num?)?.toInt() ?? 0,
    elasticName: j['elasticName']?.toString() ?? '-',
  );
}

class JobShiftDetail {
  final String id, shift, status, timer, machineName, operatorName;
  final String operatorDept, description, feedback;
  final String? date;
  final int productionMeters, machineNoOfHead;
  final List<HeadElastic> elastics;
  const JobShiftDetail({
    required this.id,
    required this.shift,
    required this.status,
    required this.timer,
    required this.machineName,
    required this.operatorName,
    required this.operatorDept,
    required this.description,
    required this.feedback,
    required this.date,
    required this.productionMeters,
    required this.machineNoOfHead,
    required this.elastics,
  });
  factory JobShiftDetail.fromJson(Map<String, dynamic> j) => JobShiftDetail(
    id: j['id']?.toString() ?? '',
    shift: j['shift']?.toString() ?? 'DAY',
    status: j['status']?.toString() ?? 'open',
    timer: j['timer']?.toString() ?? '00:00:00',
    machineName: j['machineName']?.toString() ?? '-',
    operatorName: j['operatorName']?.toString() ?? '-',
    operatorDept: j['operatorDept']?.toString() ?? '',
    description: j['description']?.toString() ?? '',
    feedback: j['feedback']?.toString() ?? '',
    date: j['date']?.toString(),
    productionMeters: (j['productionMeters'] as num?)?.toInt() ?? 0,
    machineNoOfHead: (j['machineNoOfHead'] as num?)?.toInt() ?? 0,
    elastics: (j['elastics'] as List<dynamic>?)
        ?.map((e) => HeadElastic.fromJson(e as Map<String, dynamic>))
        .toList() ??
        [],
  );
  String get shiftLabel =>
      shift.isNotEmpty ? '${shift[0]}${shift.substring(1).toLowerCase()}' : shift;
  String get shiftShort => shiftLabel;
}

class JobWastage {
  final String id, elasticName, employeeName, reason;
  final String? date;
  final double quantity, penalty;
  const JobWastage({
    required this.id,
    required this.elasticName,
    required this.employeeName,
    required this.reason,
    required this.date,
    required this.quantity,
    required this.penalty,
  });
  factory JobWastage.fromJson(Map<String, dynamic> j) => JobWastage(
    id: j['id']?.toString() ?? '',
    elasticName: j['elasticName']?.toString() ?? '-',
    employeeName: j['employeeName']?.toString() ?? '-',
    reason: j['reason']?.toString() ?? '',
    date: j['date']?.toString(),
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    penalty: (j['penalty'] as num?)?.toDouble() ?? 0,
  );
}

class JobPacking {
  final String id, elasticName, employeeName, batch, status;
  final String? date, checkedBy;
  final int rolls, metersPerRoll, total, joints;
  final double quantity, weight;

  const JobPacking({
    required this.id,
    required this.elasticName,
    required this.employeeName,
    required this.batch,
    required this.status,
    required this.date,
    required this.checkedBy,
    required this.rolls,
    required this.metersPerRoll,
    required this.total,
    required this.joints,
    required this.quantity,
    required this.weight,
  });

  factory JobPacking.fromJson(Map<String, dynamic> j) => JobPacking(
    id: j['id']?.toString() ?? '',
    elasticName: j['elasticName']?.toString() ?? '-',
    employeeName: j['employeeName']?.toString() ?? '-',
    batch: j['batch']?.toString() ?? '-',
    status: j['status']?.toString() ?? 'open',
    date: j['date']?.toString(),
    checkedBy: j['checkedBy']?.toString(),
    rolls: (j['rolls'] as num?)?.toInt() ?? 0,
    metersPerRoll: (j['metersPerRoll'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    joints: (j['joints'] as num?)?.toInt() ?? 0,
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    weight: (j['weight'] as num?)?.toDouble() ?? 0,
  );

  // short packing ID: last 6 chars of mongo id
  String get shortId =>
      id.length >= 6 ? '#${id.substring(id.length - 6).toUpperCase()}' : '#$id';
}

class JobDetailModel {
  final String id, jobNo, status, customerName, customerPhone;
  final String? date, orderNo;
  final String? machineId, machineName;
  final int machineNoOfHead;
  final List<HeadElastic> machineHeadPlan;
  final List<ElasticQty> plannedElastics, producedElastics;
  final List<ElasticQty> packedElastics, wastageElastics;
  final JobWarping? warping;
  final JobCovering? covering;
  final List<JobShiftDetail> shiftDetails;
  final List<JobWastage> wastages;
  final List<JobPacking> packingDetails;

  const JobDetailModel({
    required this.id,
    required this.jobNo,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.date,
    required this.orderNo,
    required this.machineId,
    required this.machineName,
    required this.machineNoOfHead,
    this.machineHeadPlan = const [],
    required this.plannedElastics,
    required this.producedElastics,
    required this.packedElastics,
    required this.wastageElastics,
    required this.warping,
    required this.covering,
    required this.shiftDetails,
    required this.wastages,
    required this.packingDetails,
  });

  factory JobDetailModel.fromJson(Map<String, dynamic> j) {
    final machineRaw = j['machine'] as Map<String, dynamic>?;
    return JobDetailModel(
      id: j['id']?.toString() ?? '',
      jobNo: j['jobNo']?.toString() ?? '-',
      status: j['status']?.toString() ?? 'preparatory',
      customerName: j['customerName']?.toString() ?? '-',
      customerPhone: j['customerPhone']?.toString() ?? '',
      date: j['date']?.toString(),
      orderNo: j['orderNo']?.toString(),
      machineId: machineRaw?['machineId']?.toString(),
      machineName: machineRaw?['machineName']?.toString(),
      machineNoOfHead: (machineRaw?['machineNoOfHead'] as num?)?.toInt() ?? 0,
      machineHeadPlan: (machineRaw?['headPlan'] as List<dynamic>?)
          ?.map((e) => HeadElastic.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      plannedElastics: _mapElastics(j['plannedElastics']),
      producedElastics: _mapElastics(j['producedElastics']),
      packedElastics: _mapElastics(j['packedElastics']),
      wastageElastics: _mapElastics(j['wastageElastics']),
      warping: j['warping'] != null
          ? JobWarping.fromJson(j['warping'] as Map<String, dynamic>)
          : null,
      covering: j['covering'] != null
          ? JobCovering.fromJson(j['covering'] as Map<String, dynamic>)
          : null,
      shiftDetails: (j['shiftDetails'] as List<dynamic>?)
          ?.map((e) => JobShiftDetail.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      wastages: (j['wastages'] as List<dynamic>?)
          ?.map((e) => JobWastage.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      packingDetails: (j['packingDetails'] as List<dynamic>?)
          ?.map((e) => JobPacking.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  static List<ElasticQty> _mapElastics(dynamic raw) =>
      (raw as List<dynamic>?)
          ?.map((e) => ElasticQty.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [];

  double get totalPlanned =>
      plannedElastics.fold(0.0, (s, e) => s + e.quantity);
  double get totalProduced =>
      producedElastics.fold(0.0, (s, e) => s + e.quantity);
  double get totalPacked => packedElastics.fold(0.0, (s, e) => s + e.quantity);
  double get totalWastage =>
      wastageElastics.fold(0.0, (s, e) => s + e.quantity);
  double get completionPct =>
      totalPlanned > 0 ? (totalProduced / totalPlanned).clamp(0.0, 1.0) : 0.0;
  bool get hasMachine => machineId != null && machineId!.isNotEmpty;
  int get totalShiftMeters =>
      shiftDetails.fold(0, (s, d) => s + d.productionMeters);
  double get totalWastagePenalty =>
      wastages.fold(0.0, (s, w) => s + w.penalty);
  int get totalPackedMeters => packingDetails.fold(0, (s, p) => s + p.total);
}

class MachineMini {
  final String id, machineID, manufacturer;
  final int noOfHead, noOfHooks;
  const MachineMini({
    required this.id,
    required this.machineID,
    required this.manufacturer,
    required this.noOfHead,
    required this.noOfHooks,
  });
  factory MachineMini.fromJson(Map<String, dynamic> j) => MachineMini(
    id: j['id']?.toString() ?? '',
    machineID: j['machineID']?.toString() ?? '-',
    manufacturer: j['manufacturer']?.toString() ?? '',
    noOfHead: (j['noOfHead'] as num?)?.toInt() ?? 0,
    noOfHooks: (j['noOfHooks'] as num?)?.toInt() ?? 0,
  );
  String get displayLabel {
    final mfr = manufacturer.isNotEmpty ? '  ·  $manufacturer' : '';
    return '$machineID$mfr  ($noOfHead heads)';
  }
}

// ════════════════════════════════════════════════════════════════
//  CONTROLLER
// ════════════════════════════════════════════════════════════════

class JobDetailController extends GetxController {
  static const _baseUrl = 'http://13.233.117.153:2701/api/v2/job';
  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final isLoading = true.obs;
  final errorMsg = Rxn<String>();
  final job = Rxn<JobDetailModel>();
  final pdfLoading = false.obs;
  final actionLoading = false.obs;
  final machinesLoading = false.obs;
  final freeMachines = RxList.empty();

  String get jobId => Get.arguments as String? ?? '';

  @override
  void onInit() {
    super.onInit();
    fetchJob();
  }

  Future<void> assignMachine(
      String machineId, List<Map<String, dynamic>> elastics) async {
    final j = job.value;
    if (j == null) return;
    actionLoading.value = true;
    try {
      await _dio.post('/assign-machine', data: {
        'jobId': j.id,
        'machineId': machineId,
        'elastics': elastics,
      });
      Get.snackbar('Machine Assigned', 'Machine & head plan saved for ${j.jobNo}.',
          backgroundColor: ErpColors.successGreen,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(12),
          borderRadius: 8,
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white));
      await fetchJob();
    } on DioException catch (e) {
      Get.snackbar('Error',
          e.response?.data?['message']?.toString() ?? 'Failed to assign machine.',
          backgroundColor: ErpColors.errorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      actionLoading.value = false;
    }
  }

  Future<void> updateStatus(String nextStatus) async {
    final j = job.value;
    if (j == null) return;
    actionLoading.value = true;
    try {
      await _dio.post('/update-status',
          data: {'jobId': j.id, 'nextStatus': nextStatus});
      const messages = {
        'finishing': 'Weaving complete. Machine released. Job → Finishing.',
        'checking': 'Finishing complete. Job → Checking.',
        'packing': 'Checking complete. Job → Packing.',
        'completed': 'Packing complete. Job is now Completed!',
      };
      Get.snackbar('Status Updated', messages[nextStatus] ?? 'Status updated.',
          backgroundColor: ErpColors.successGreen,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(12),
          borderRadius: 8);
      await fetchJob();
    } on DioException catch (e) {
      Get.snackbar('Error',
          e.response?.data?['message']?.toString() ?? 'Failed to update status.',
          backgroundColor: ErpColors.errorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      actionLoading.value = false;
    }
  }

  Future<void> fetchFreeMachines() async {
    if (machinesLoading.value) return;
    machinesLoading.value = true;
    try {
      final res = await _dio.get('/free-machines');
      final list = res.data['machines'] as List<dynamic>? ?? [];
      freeMachines.value = list
          .map((m) => MachineMini.fromJson(m as Map<String, dynamic>))
          .toList();
    } on DioException {
      freeMachines.value = [];
    } finally {
      machinesLoading.value = false;
    }
  }

  Future<void> fetchJob() async {
    if (jobId.isEmpty) {
      job.value = _sampleJobDetail;
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get('/$jobId');
      job.value =
          JobDetailModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message']?.toString() ??
          'Failed to load job. Check connection.';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportPdf(BuildContext context) async {
    final j = job.value;
    if (j == null) return;
    pdfLoading.value = true;
    try {
      final bytes = await JobDetailPdfService.generate(j);
      final dir = await getApplicationDocumentsDirectory();
      final safe = j.jobNo.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final file = File('${dir.path}/Job_$safe.pdf');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
      Get.snackbar('PDF Ready', 'Job ${j.jobNo} report exported.',
          backgroundColor: ErpColors.successGreen,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          borderRadius: 8,
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white));
    } catch (e) {
      Get.snackbar('Export Failed', e.toString(),
          backgroundColor: ErpColors.errorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      pdfLoading.value = false;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key});
  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final JobDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _ctrl = Get.put(JobDetailController());
  }

  @override
  void dispose() {
    _tabs.dispose();
    Get.delete<JobDetailController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = _ctrl.isLoading.value;
      final errorMsg = _ctrl.errorMsg.value;
      final job = _ctrl.job.value;
      final pdfLoading = _ctrl.pdfLoading.value;
      final actionLoading = _ctrl.actionLoading.value;

      return Scaffold(
        backgroundColor: ErpColors.bgBase,
        bottomNavigationBar: (job != null && !isLoading)
            ? _ActionBar(job: job, ctrl: _ctrl, actionLoading: actionLoading)
            : null,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              expandedHeight: 248,
              pinned: true,
              backgroundColor: ErpColors.navyDark,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 16, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: ErpColors.accentBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onPressed: (isLoading || pdfLoading || job == null)
                        ? null
                        : () => _ctrl.exportPdf(context),
                    icon: pdfLoading
                        ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 16),
                    label: Text(
                      pdfLoading ? 'Generating…' : 'Export PDF',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: job != null
                    ? _HeroCard(job: job)
                    : const _HeroPlaceholder(),
              ),
              bottom: TabBar(
                controller: _tabs,
                isScrollable: true,
                labelColor: ErpColors.accentBlue,
                unselectedLabelColor: ErpColors.textOnDarkSub,
                indicatorColor: ErpColors.accentBlue,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'General'),
                  Tab(text: 'Warping'),
                  Tab(text: 'Covering'),
                  Tab(text: 'Weaving'),
                  Tab(text: 'Wastage'),
                  Tab(text: 'Packing'),
                ],
              ),
            ),
          ],
          body: isLoading
              ? const _LoadingView()
              : errorMsg != null
              ? _ErrorView(msg: errorMsg, onRetry: _ctrl.fetchJob)
              : job == null
              ? const _ErrorView(
              msg: 'No data received.', onRetry: null)
              : TabBarView(
            controller: _tabs,
            children: [
              _GeneralTab(job: job),
              _WarpingTab(warping: job.warping),
              _CoveringTab(covering: job.covering),
              _WeavingTab(shiftDetails: job.shiftDetails),
              _WastageTab(
                wastages: job.wastages,
                totalPlanned: job.totalPlanned,
              ),
              _PackingTab(packingDetails: job.packingDetails),
            ],
          ),
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════
//  HERO CARD — shows elastic qty table
// ════════════════════════════════════════════════════════════════

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();
  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: ErpColors.navyDark);
}

class _HeroCard extends StatelessWidget {
  final JobDetailModel job;
  const _HeroCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final pct = job.completionPct;
    return Container(
      color: ErpColors.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Job identity ─────────────────────────────────────
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.jobNo,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(job.customerName,
                      style: const TextStyle(
                          color: ErpColors.textOnDarkSub, fontSize: 12)),
                  if (job.customerPhone.isNotEmpty)
                    Text(job.customerPhone,
                        style: const TextStyle(
                            color: ErpColors.textOnDarkSub, fontSize: 11)),
                ],
              ),
            ),
            _StatusChip(job.status),
          ]),
          const SizedBox(height: 8),

          // ── KPI strip ────────────────────────────────────────
          Row(children: [
            _KpiCell('Date', job.date ?? '-'),
            _divider(),
            _KpiCell('Planned', '${job.totalPlanned.toStringAsFixed(0)}m'),
            _divider(),
            _KpiCell('Produced', '${job.totalProduced.toStringAsFixed(0)}m'),
            _divider(),
            _KpiCell('Wastage', '${job.totalWastage.toStringAsFixed(0)}m'),
          ]),

          // ── Elastics planned — mini table ────────────────────


          // ── Progress bar ─────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Completion',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 11)),
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor:
              const AlwaysStoppedAnimation(ErpColors.accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withOpacity(0.12),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _KpiCell extends StatelessWidget {
  final String label, value;
  const _KpiCell(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              color: ErpColors.textOnDarkSub, fontSize: 9)),
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800)),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    const map = {
      'preparatory': (Color(0xFF7C3AED), Color(0xFFF5F3FF), 'Preparatory'),
      'weaving': (ErpColors.accentBlue, Color(0xFFEFF6FF), 'Weaving'),
      'finishing': (Color(0xFF0891B2), Color(0xFFECFEFF), 'Finishing'),
      'checking': (ErpColors.warningAmber, Color(0xFFFFFBEB), 'Checking'),
      'packing': (Color(0xFF059669), Color(0xFFF0FDF4), 'Packing'),
      'completed': (ErpColors.successGreen, Color(0xFFF0FDF4), 'Completed'),
      'cancelled': (ErpColors.errorRed, Color(0xFFFEF2F2), 'Cancelled'),
    };
    final entry = map[status];
    final fg = entry?.$1 ?? ErpColors.textSecondary;
    final bg = entry?.$2 ?? ErpColors.bgBase;
    final lbl = entry?.$3 ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(lbl,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  LOADING / ERROR
// ════════════════════════════════════════════════════════════════

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: ErpColors.accentBlue),
      SizedBox(height: 12),
      Text('Loading job details…',
          style: TextStyle(
              color: ErpColors.textSecondary, fontSize: 13)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String? msg;
  final VoidCallback? onRetry;
  const _ErrorView({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded,
            color: ErpColors.errorRed, size: 48),
        const SizedBox(height: 12),
        Text(msg ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: ErpColors.textPrimary, fontSize: 14)),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                foregroundColor: Colors.white),
          ),
        ],
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  SECTION SHELL
// ════════════════════════════════════════════════════════════════

class _SectionShell extends StatelessWidget {
  final String title, status;
  final Color accentColor;
  final List<Widget> children;
  final List<_StatBadge>? badges;
  const _SectionShell({
    required this.title,
    required this.status,
    required this.accentColor,
    required this.children,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            border: Border.all(color: ErpColors.borderLight),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800))),
                _StatusBadge(status),
              ]),
            ),
            if (badges != null && badges!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: badges!
                      .map((b) => Expanded(child: _StatTile(b)))
                      .toList(),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _StatBadge {
  final String label, value;
  const _StatBadge(this.label, this.value);
}

class _StatTile extends StatelessWidget {
  final _StatBadge b;
  const _StatTile(this.b);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(b.value,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: ErpColors.textPrimary)),
    Text(b.label,
        style: const TextStyle(
            fontSize: 9, color: ErpColors.textSecondary)),
  ]);
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    const map = {
      'completed': (ErpColors.successGreen, Color(0xFFF0FDF4)),
      'closed': (ErpColors.successGreen, Color(0xFFF0FDF4)),
      'in_progress': (Color(0xFF7C3AED), Color(0xFFF5F3FF)),
      'running': (Color(0xFF7C3AED), Color(0xFFF5F3FF)),
      'open': (ErpColors.accentBlue, Color(0xFFEFF6FF)),
      'partial': (ErpColors.warningAmber, Color(0xFFFFFBEB)),
      'logged': (ErpColors.errorRed, Color(0xFFFEF2F2)),
    };
    final entry = map[status.toLowerCase()];
    final fg = entry?.$1 ?? ErpColors.textSecondary;
    final bg = entry?.$2 ?? ErpColors.bgBase;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        status.isEmpty
            ? '-'
            : '${status[0].toUpperCase()}${status.substring(1)}',
        style:
        TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  GENERAL TAB  —  full job overview with all details
// ════════════════════════════════════════════════════════════════

class _GeneralTab extends StatelessWidget {
  final JobDetailModel job;
  const _GeneralTab({required this.job});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ── Job Details card ─────────────────────────────────────
        _GenCard(
          icon: Icons.work_outline_rounded,
          title: 'JOB DETAILS',
          accentColor: ErpColors.navyDark,
          child: Column(children: [
            _GRow('Job No', job.jobNo),
            _GRow('Status', job.status.toUpperCase().replaceAll('_', ' '),
                valueColor: _statusColor(job.status)),
            _GRow('Date', job.date ?? '—'),
            _GRow('Order No', job.orderNo ?? '—'),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Customer card ────────────────────────────────────────
        _GenCard(
          icon: Icons.person_outline_rounded,
          title: 'CUSTOMER',
          accentColor: const Color(0xFF0891B2),
          child: Column(children: [
            _GRow('Name', job.customerName),
            if (job.customerPhone.isNotEmpty)
              _GRow('Phone', job.customerPhone),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Production summary card ──────────────────────────────
        _GenCard(
          icon: Icons.bar_chart_rounded,
          title: 'PRODUCTION SUMMARY',
          accentColor: const Color(0xFF7C3AED),
          child: Column(children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Completion',
                          style: TextStyle(
                              fontSize: 11,
                              color: ErpColors.textSecondary)),
                      Text(
                          '${(job.completionPct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: job.completionPct,
                      minHeight: 7,
                      backgroundColor:
                      ErpColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation(
                          ErpColors.accentBlue),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ErpColors.borderLight),
            _GRow('Total Planned', '${job.totalPlanned.toStringAsFixed(0)} m'),
            _GRow('Total Produced', '${job.totalProduced.toStringAsFixed(0)} m',
                valueColor: ErpColors.accentBlue),
            _GRow('Total Packed', '${job.totalPacked.toStringAsFixed(0)} m',
                valueColor: ErpColors.successGreen),
            _GRow('Total Wastage', '${job.totalWastage.toStringAsFixed(0)} m',
                valueColor: ErpColors.errorRed),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Planned Elastics table ───────────────────────────────
        _GenCard(
          icon: Icons.layers_outlined,
          title: 'PLANNED ELASTICS',
          accentColor: ErpColors.accentBlue,
          child: Column(children: [
            // Table header
            Container(
              color: ErpColors.accentBlue.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              child: Row(children: [
                const SizedBox(
                  width: 22,
                  child: Text('#',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textSecondary)),
                ),
                const Expanded(
                  flex: 3,
                  child: Text('ELASTIC',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textSecondary)),
                ),
                const SizedBox(
                  width: 58,
                  child: Text('PLANNED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
                const SizedBox(
                  width: 62,
                  child: Text('PRODUCED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
                const SizedBox(
                  width: 58,
                  child: Text('WASTAGE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
              ]),
            ),
            const Divider(height: 1, color: ErpColors.borderLight),
            if (job.plannedElastics.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No elastics planned.',
                    style:
                    TextStyle(color: ErpColors.textSecondary)),
              )
            else
              ...job.plannedElastics.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final produced = job.producedElastics
                    .where((p) => p.elasticName == e.elasticName)
                    .fold(0.0, (s, p) => s + p.quantity);
                final wastage = job.wastageElastics
                    .where((w) => w.elasticName == e.elasticName)
                    .fold(0.0, (w, v) => w + v.quantity);
                final isLast = i == job.plannedElastics.length - 1;

                return Column(children: [
                  Container(
                    color: i.isOdd
                        ? ErpColors.bgMuted
                        : ErpColors.bgSurface,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      SizedBox(
                        width: 22,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: ErpColors.accentBlue
                                  .withOpacity(0.12),
                              shape: BoxShape.circle),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: ErpColors.accentBlue)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(e.elasticName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.textPrimary)),
                      ),
                      SizedBox(
                        width: 58,
                        child: Text(
                            '${e.quantity.toStringAsFixed(0)} m',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.textPrimary),
                            textAlign: TextAlign.right),
                      ),
                      SizedBox(
                        width: 62,
                        child: Text(
                            produced > 0
                                ? '${produced.toStringAsFixed(0)} m'
                                : '—',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.accentBlue),
                            textAlign: TextAlign.right),
                      ),
                      SizedBox(
                        width: 58,
                        child: Text(
                            wastage > 0
                                ? '${wastage.toStringAsFixed(1)} m'
                                : '—',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: wastage > 0
                                    ? ErpColors.errorRed
                                    : ErpColors.textMuted),
                            textAlign: TextAlign.right),
                      ),
                    ]),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, color: ErpColors.borderLight),
                ]);
              }),
            // Total row
            Container(
              decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(7)),
                  border: Border(
                      top: BorderSide(
                          color: ErpColors.accentBlue.withOpacity(0.2)))),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 9),
              child: Row(children: [
                const SizedBox(width: 22),
                const Expanded(
                  flex: 3,
                  child: Text('TOTAL',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ErpColors.textPrimary)),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                      '${job.totalPlanned.toStringAsFixed(0)} m',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: ErpColors.textPrimary),
                      textAlign: TextAlign.right),
                ),
                SizedBox(
                  width: 62,
                  child: Text(
                      '${job.totalProduced.toStringAsFixed(0)} m',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: ErpColors.accentBlue),
                      textAlign: TextAlign.right),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                      job.totalWastage > 0
                          ? '${job.totalWastage.toStringAsFixed(1)} m'
                          : '—',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: job.totalWastage > 0
                              ? ErpColors.errorRed
                              : ErpColors.textMuted),
                      textAlign: TextAlign.right),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Machine assignment card (if weaving+) ────────────────
        if (job.hasMachine)
          _GenCard(
            icon: Icons.precision_manufacturing_outlined,
            title: 'MACHINE ASSIGNMENT',
            accentColor: const Color(0xFF059669),
            child: Column(children: [
              _GRow('Machine', job.machineName ?? '—'),
              _GRow('No. of Heads', '${job.machineNoOfHead}'),
              if (job.machineHeadPlan.isNotEmpty) ...[
                const Divider(height: 1, color: ErpColors.borderLight),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(children: [
                    const Text('HEAD PLAN',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: ErpColors.textSecondary)),
                  ]),
                ),
                ...job.machineHeadPlan.asMap().entries.map((entry) {
                  final i = entry.key;
                  final h = entry.value;
                  return Container(
                    color: i.isOdd
                        ? ErpColors.bgMuted
                        : ErpColors.bgSurface,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    child: Row(children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: Text('${h.head}',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(h.elasticName,
                            style: const TextStyle(
                                fontSize: 12,
                                color: ErpColors.textPrimary)),
                      ),
                    ]),
                  );
                }),
              ],
            ]),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'preparatory': return const Color(0xFF7C3AED);
      case 'weaving':     return ErpColors.accentBlue;
      case 'finishing':   return const Color(0xFF0891B2);
      case 'checking':    return ErpColors.warningAmber;
      case 'packing':     return const Color(0xFF059669);
      case 'completed':   return ErpColors.successGreen;
      default:            return ErpColors.textSecondary;
    }
  }
}

// ── General card shell ────────────────────────────────────────
class _GenCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final Widget child;
  const _GenCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ]),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Label-value row ───────────────────────────────────────────
class _GRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _GRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
          border:
          Border(bottom: BorderSide(color: ErpColors.borderLight))),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: ErpColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? ErpColors.textPrimary)),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  WARPING TAB  (unchanged design — already good)
// ════════════════════════════════════════════════════════════════

class _WarpingTab extends StatelessWidget {
  final JobWarping? warping;
  const _WarpingTab({required this.warping});

  @override
  Widget build(BuildContext context) {
    if (warping == null) {
      return const _EmptyTab(
          icon: Icons.straighten_rounded,
          label: 'No warping data for this job.');
    }
    final w = warping!;
    final te = w.beams.fold(0, (s, b) => s + b.totalEnds);
    return _SectionShell(
      title: 'Warping Program',
      status: w.status,
      accentColor: ErpColors.navyDark,
      badges: [
        _StatBadge('Beams', '${w.beams.length}'),
        _StatBadge('Total Ends', '$te'),
        _StatBadge('Start', w.date ?? '-'),
        _StatBadge('Completed', w.completedDate ?? '-'),
      ],
      children: [
        ...w.beams.map((b) => _BeamCard(beam: b)),
        if (w.remarks.isNotEmpty) _NoteCard(w.remarks, ErpColors.warningAmber),
      ],
    );
  }
}

class _BeamCard extends StatelessWidget {
  final BeamModel beam;
  const _BeamCard({required this.beam});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
              color: Color(0xFF1B2B45),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            // numbered badge
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: ErpColors.accentBlue,
                  borderRadius: BorderRadius.circular(6)),
              child: Text('${beam.beamNo}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Text('Beam ${beam.beamNo}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${beam.totalEnds} ends',
                style: const TextStyle(
                    color: Color(0xFF5A9EFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        // Column headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: ErpColors.accentBlue,
          child: const Row(children: [
            Expanded(
                flex: 1,
                child: Text('SEC',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 4,
                child: Text('WARP YARN',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 1,
                child: Text('ENDS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center)),
          ]),
        ),
        ...beam.sections.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: i.isOdd ? ErpColors.bgMuted : ErpColors.bgSurface,
            child: Row(children: [
              Expanded(
                  flex: 1,
                  child: Text('${s.sectionNo}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.accentBlue))),
              Expanded(
                  flex: 4,
                  child: Text(
                      s.yarnUnit.isNotEmpty
                          ? '${s.yarnName} (${s.yarnUnit})'
                          : s.yarnName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textPrimary))),
              Expanded(
                  flex: 1,
                  child: Text('${s.ends}',
                      style: const TextStyle(
                          fontSize: 12, color: ErpColors.textPrimary),
                      textAlign: TextAlign.center)),
            ]),
          );
        }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(8))),
          child: Row(children: [
            const Spacer(),
            const Text('Total Ends:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            const SizedBox(width: 8),
            Text('${beam.totalEnds}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ErpColors.successGreen)),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  COVERING TAB
// ════════════════════════════════════════════════════════════════

class _CoveringTab extends StatelessWidget {
  final JobCovering? covering;
  const _CoveringTab({required this.covering});

  @override
  Widget build(BuildContext context) {
    if (covering == null) {
      return const _EmptyTab(
          icon: Icons.settings_outlined,
          label: 'No covering data for this job.');
    }
    final c = covering!;
    final totalQty = c.elasticPlanned.fold(0.0, (s, e) => s + e.quantity);

    return _SectionShell(
      title: 'Covering Program',
      status: c.status,
      accentColor: const Color(0xFF0891B2),
      badges: [
        _StatBadge('Elastics', '${c.elasticPlanned.length}'),
        _StatBadge('Total Qty', '${totalQty.toStringAsFixed(0)}m'),
        _StatBadge('Start', c.date ?? '-'),
        _StatBadge('Completed', c.completedDate ?? '-'),
      ],
      children: [
        Container(
          decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              border: Border.all(color: ErpColors.borderLight),
              borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                  color: Color(0xFF0891B2),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8))),
              child: const Row(children: [
                Expanded(
                    child: Text('ELASTIC',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
                Text('PLANNED QTY',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            if (c.elasticPlanned.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No elastics planned.',
                      style:
                      TextStyle(color: ErpColors.textSecondary)))
            else
              ...c.elasticPlanned.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  color: i.isOdd
                      ? ErpColors.bgMuted
                      : ErpColors.bgSurface,
                  child: Row(children: [
                    Expanded(
                        child: Text(e.elasticName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.textPrimary))),
                    Text('${e.quantity.toStringAsFixed(0)} m',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0891B2))),
                  ]),
                );
              }),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                  color: Color(0xFFECFEFF),
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(8))),
              child: Row(children: [
                const Expanded(
                    child: Text('TOTAL',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.textPrimary))),
                Text('${totalQty.toStringAsFixed(0)} m',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0891B2))),
              ]),
            ),
          ]),
        ),
        if (c.remarks.isNotEmpty)
          _NoteCard(c.remarks, const Color(0xFF0891B2)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  WEAVING TAB
// ════════════════════════════════════════════════════════════════

class _WeavingTab extends StatelessWidget {
  final List<JobShiftDetail> shiftDetails;
  const _WeavingTab({required this.shiftDetails});

  @override
  Widget build(BuildContext context) {
    final totalMeters =
    shiftDetails.fold(0, (s, d) => s + d.productionMeters);
    final closedCount =
        shiftDetails.where((d) => d.status == 'closed').length;

    return _SectionShell(
      title: 'Weaving — Shift Log',
      status: shiftDetails.isEmpty
          ? 'open'
          : shiftDetails.any((d) => d.status == 'running')
          ? 'running'
          : shiftDetails.every((d) => d.status == 'closed')
          ? 'completed'
          : 'open',
      accentColor: const Color(0xFF7C3AED),
      badges: [
        _StatBadge('Produced', '${totalMeters}m'),
        _StatBadge('Shifts', '${shiftDetails.length}'),
        _StatBadge('Closed', '$closedCount'),
      ],
      children: shiftDetails.isEmpty
          ? [const _EmptyCard(label: 'No shift records yet.')]
          : shiftDetails
          .map((s) => _ShiftDetailCard(detail: s))
          .toList(),
    );
  }
}

class _ShiftDetailCard extends StatelessWidget {
  final JobShiftDetail detail;
  const _ShiftDetailCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final isDay = detail.shift == 'DAY';
    final accent =
    isDay ? ErpColors.accentBlue : const Color(0xFF7C3AED);
    final isClosed = detail.status == 'closed';
    final isRunning = detail.status == 'running';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight)),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Column(children: [
            Text(detail.shiftShort,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent)),
            Text(detail.date ?? '-',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 8,
                    color: ErpColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${detail.machineName}  ·  ${detail.operatorName}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary)),
              const SizedBox(height: 2),
              if (detail.elastics.isNotEmpty)
                Text(detail.elastics.map((e) => e.elasticName).join(', '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: ErpColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.timer_outlined,
                    size: 12, color: ErpColors.textSecondary),
                const SizedBox(width: 3),
                Text(detail.timer,
                    style: const TextStyle(
                        fontSize: 11,
                        color: ErpColors.textSecondary)),
              ]),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${detail.productionMeters} m',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isClosed
                  ? ErpColors.successGreen
                  : isRunning
                  ? const Color(0xFF7C3AED)
                  : ErpColors.accentBlue)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isClosed ? 'Closed' : isRunning ? 'Running' : 'Open',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isClosed
                      ? ErpColors.successGreen
                      : isRunning
                      ? const Color(0xFF7C3AED)
                      : ErpColors.accentBlue),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  WASTAGE TAB — tabular redesign
// ════════════════════════════════════════════════════════════════

class _WastageTab extends StatelessWidget {
  final List<JobWastage> wastages;
  final double totalPlanned;
  const _WastageTab(
      {required this.wastages, required this.totalPlanned});

  @override
  Widget build(BuildContext context) {
    final totalQty = wastages.fold(0.0, (s, w) => s + w.quantity);
    final totalPenalty = wastages.fold(0.0, (s, w) => s + w.penalty);
    final wastageRate = totalPlanned > 0
        ? (totalQty / totalPlanned * 100).clamp(0.0, 100.0)
        : 0.0;

    return _SectionShell(
      title: 'Wastage Report',
      status: 'Logged',
      accentColor: ErpColors.errorRed,
      badges: [
        _StatBadge('Total Wastage', '${totalQty.toStringAsFixed(1)}m'),
        _StatBadge('Penalty', 'Rs.${totalPenalty.toStringAsFixed(0)}'),
        _StatBadge('Rate', '${wastageRate.toStringAsFixed(2)}%'),
        _StatBadge('Records', '${wastages.length}'),
      ],
      children: wastages.isEmpty
          ? [const _EmptyCard(label: 'No wastage records.')]
          : [_WastageTable(wastages: wastages)],
    );
  }
}

class _WastageTable extends StatelessWidget {
  final List<JobWastage> wastages;
  const _WastageTable({required this.wastages});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
              color: ErpColors.errorRed,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(7))),
          child: const Row(children: [
            SizedBox(width: 20, child: _TH('#')),
            SizedBox(width: 8),
            Expanded(flex: 3, child: _TH('ELASTIC')),
            Expanded(flex: 2, child: _TH('EMPLOYEE')),
            SizedBox(width: 44, child: _TH('QTY', right: true)),
            SizedBox(width: 56, child: _TH('PENALTY', right: true)),
          ]),
        ),
        // Data rows
        ...wastages.asMap().entries.map((entry) {
          final i = entry.key;
          final w = entry.value;
          return Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 4),
              color:
              i.isOdd ? ErpColors.bgMuted : ErpColors.bgSurface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: ErpColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.elasticName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.textPrimary)),
                        if (w.date != null)
                          Text(w.date!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: ErpColors.textMuted)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(w.employeeName,
                        style: const TextStyle(
                            fontSize: 11,
                            color: ErpColors.textSecondary)),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('${w.quantity.toStringAsFixed(1)}m',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.errorRed),
                        textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      w.penalty > 0
                          ? 'Rs.${w.penalty.toStringAsFixed(0)}'
                          : '—',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: w.penalty > 0
                              ? ErpColors.errorRed
                              : ErpColors.textMuted),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            // Reason sub-row
            if (w.reason.isNotEmpty)
              Container(
                color: i.isOdd ? ErpColors.bgMuted : ErpColors.bgSurface,
                padding:
                const EdgeInsets.fromLTRB(40, 0, 12, 8),
                child: Row(children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded,
                      size: 12, color: ErpColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(w.reason,
                        style: const TextStyle(
                            fontSize: 11,
                            color: ErpColors.textMuted,
                            fontStyle: FontStyle.italic)),
                  ),
                ]),
              ),
            if (i < wastages.length - 1)
              const Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: ErpColors.borderLight),
          ]);
        }),
        // Total row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: ErpColors.errorRed.withOpacity(0.07),
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(7)),
              border: Border(
                  top: BorderSide(
                      color: ErpColors.errorRed.withOpacity(0.2)))),
          child: Row(children: [
            const Expanded(
                child: Text('TOTAL',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary))),
            Text(
                '${wastages.fold(0.0, (s, w) => s + w.quantity).toStringAsFixed(1)}m',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ErpColors.errorRed)),
            const SizedBox(width: 8),
            Text(
                '  Rs.${wastages.fold(0.0, (s, w) => s + w.penalty).toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.errorRed)),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  PACKING TAB — full tabular redesign
// ════════════════════════════════════════════════════════════════

class _PackingTab extends StatelessWidget {
  final List<JobPacking> packingDetails;
  const _PackingTab({required this.packingDetails});

  @override
  Widget build(BuildContext context) {
    final totalPacked = packingDetails.fold(0, (s, p) => s + p.total);
    final dispatched = packingDetails
        .where((p) => p.status == 'dispatched')
        .fold(0, (s, p) => s + p.total);
    final totalRolls = packingDetails.fold(0, (s, p) => s + p.rolls);

    return _SectionShell(
      title: 'Packing & Dispatch',
      status: packingDetails.isEmpty ? 'open' : 'partial',
      accentColor: ErpColors.navyDark,
      badges: [
        _StatBadge('Packed', '${totalPacked}m'),
        _StatBadge('Dispatched', '${dispatched}m'),
        _StatBadge('Pending', '${totalPacked - dispatched}m'),
        _StatBadge('Rolls', '$totalRolls'),
      ],
      children: packingDetails.isEmpty
          ? [const _EmptyCard(label: 'No packing records yet.')]
          : [_PackingTable(packingDetails: packingDetails)],
    );
  }
}

class _PackingTable extends StatelessWidget {
  final List<JobPacking> packingDetails;
  const _PackingTable({required this.packingDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        // ── Header ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
              color: ErpColors.navyDark,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(7))),
          child: const Row(children: [
            SizedBox(width: 54, child: _TH('PACK ID')),
            SizedBox(width: 8),
            Expanded(flex: 3, child: _TH('ELASTIC')),
            Expanded(flex: 2, child: _TH('STATUS')),
          ]),
        ),
        // ── Packing rows ───────────────────────────────────────
        ...packingDetails.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          const statusColors = {
            'dispatched': ErpColors.successGreen,
            'ready': ErpColors.accentBlue,
            'packing': ErpColors.warningAmber,
          };
          final sc = statusColors[p.status] ?? ErpColors.textSecondary;

          return Column(children: [
            // ── Main row ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              color: i.isOdd ? ErpColors.bgMuted : ErpColors.bgSurface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pack ID badge
                  Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 4),
                    decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: ErpColors.accentBlue.withOpacity(0.3))),
                    child: Text(p.shortId,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.accentBlue),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 8),
                  // Elastic + date
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.elasticName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.textPrimary)),
                        if (p.date != null)
                          Text(p.date!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: ErpColors.textMuted)),
                        Text('Batch: ${p.batch}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: ErpColors.textMuted)),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: sc.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sc.withOpacity(0.35))),
                    child: Text(p.status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: sc)),
                  ),
                ],
              ),
            ),

            // ── Detail grid: 3 × 2 ────────────────────────────
            Container(
              color: i.isOdd ? ErpColors.bgMuted : ErpColors.bgSurface,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                const SizedBox(width: 62), // align with elastic col
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _PackCell(
                          label: 'Packed By',
                          value: p.employeeName,
                          icon: Icons.person_outline),
                      _PackCell(
                          label: 'Checked By',
                          value: p.checkedBy ?? '—',
                          icon: Icons.verified_user_outlined),
                      _PackCell(
                          label: 'Meters',
                          value: '${p.total} m',
                          icon: Icons.straighten_outlined),
                      _PackCell(
                          label: 'Rolls',
                          value:
                          '${p.rolls} × ${p.metersPerRoll}m',
                          icon: Icons.rotate_right_outlined),
                      if (p.joints > 0)
                        _PackCell(
                            label: 'Joints',
                            value: '${p.joints}',
                            icon: Icons.join_inner_outlined),
                      if (p.weight > 0)
                        _PackCell(
                            label: 'Weight',
                            value: '${p.weight.toStringAsFixed(2)} kg',
                            icon: Icons.scale_outlined),
                    ],
                  ),
                ),
              ]),
            ),

            if (i < packingDetails.length - 1)
              const Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: ErpColors.borderLight),
          ]);
        }),

        // ── Totals row ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(7)),
              border: Border(
                  top: BorderSide(color: Color(0xFFBBF7D0)))),
          child: Row(children: [
            const Expanded(
                child: Text('TOTAL',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary))),
            Text(
                '${packingDetails.fold(0, (s, p) => s + p.total)} m',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ErpColors.successGreen)),
            const SizedBox(width: 10),
            Text(
                '${packingDetails.fold(0, (s, p) => s + p.rolls)} rolls',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ErpColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

// ── Packing detail cell ────────────────────────────────────────
class _PackCell extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _PackCell(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: ErpColors.textMuted),
      const SizedBox(width: 4),
      Text('$label: ',
          style: const TextStyle(
              fontSize: 10, color: ErpColors.textMuted)),
      Text(value,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ErpColors.textPrimary)),
    ],
  );
}

// ── Table header text ─────────────────────────────────────────
class _TH extends StatelessWidget {
  final String label;
  final bool right;
  const _TH(this.label, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5),
      textAlign: right ? TextAlign.right : TextAlign.left);
}

// ════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(text,
        style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600)),
  );
}

class _NoteCard extends StatelessWidget {
  final String text;
  final Color color;
  const _NoteCard(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontStyle: FontStyle.italic))),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final String label;
  const _EmptyCard({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight)),
    child: Center(
        child: Text(label,
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 13))),
  );
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: ErpColors.textSecondary, size: 40),
      const SizedBox(height: 12),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 14)),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  ACTION BAR
// ════════════════════════════════════════════════════════════════

class _ActionBar extends StatelessWidget {
  final JobDetailModel job;
  final JobDetailController ctrl;
  final bool actionLoading;
  const _ActionBar(
      {required this.job,
        required this.ctrl,
        required this.actionLoading});

  @override
  Widget build(BuildContext context) {
    switch (job.status) {
      case 'weaving':
        return _weavingBar(context);
      case 'finishing':
        return _singleActionBar(context,
            label: 'Mark Finishing Complete',
            nextStatus: 'checking',
            color: const Color(0xFF0891B2),
            icon: Icons.dry_cleaning_outlined,
            confirmTitle: 'Complete Finishing?',
            confirmMsg: 'Job will move to the Checking stage.');
      case 'checking':
        return _singleActionBar(context,
            label: 'Mark Checking Complete',
            nextStatus: 'packing',
            color: const Color(0xFF7C3AED),
            icon: Icons.fact_check_outlined,
            confirmTitle: 'Complete Checking?',
            confirmMsg: 'Job will move to the Packing stage.');
      case 'packing':
        return _singleActionBar(context,
            label: 'Mark Packing Complete',
            nextStatus: 'completed',
            color: ErpColors.successGreen,
            icon: Icons.inventory_2_outlined,
            confirmTitle: 'Complete Packing?',
            confirmMsg:
            'Job will be marked as Completed. This cannot be undone.');
      case 'completed':
        return _completedBanner();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _weavingBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border:
          const Border(top: BorderSide(color: ErpColors.borderLight)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.precision_manufacturing_outlined,
              size: 14, color: ErpColors.textSecondary),
          const SizedBox(width: 6),
          if (job.hasMachine) ...[
            const Text('Machine:',
                style: TextStyle(
                    fontSize: 11, color: ErpColors.textSecondary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: ErpColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(job.machineName!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.successGreen)),
            ),
            const SizedBox(width: 8),
            if (job.machineNoOfHead > 0)
              Text('${job.machineNoOfHead} heads',
                  style: const TextStyle(
                      fontSize: 11,
                      color: ErpColors.textSecondary)),
          ] else
            const Text('No machine assigned',
                style: TextStyle(
                    fontSize: 12,
                    color: ErpColors.warningAmber,
                    fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: actionLoading
                  ? null
                  : () => _openAssignMachineSheet(context),
              style: OutlinedButton.styleFrom(
                  foregroundColor: ErpColors.accentBlue,
                  side: const BorderSide(color: ErpColors.accentBlue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              icon: const Icon(Icons.precision_manufacturing_rounded,
                  size: 16),
              label: Text(job.hasMachine ? 'Reassign' : 'Assign Machine',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          if (job.hasMachine) ...[
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: actionLoading
                    ? null
                    : () => _showConfirmDialog(context,
                    title: 'Complete Weaving?',
                    message:
                    'Machine ${job.machineName} will be released '
                        'and the job will move to Finishing.',
                    nextStatus: 'finishing',
                    color: const Color(0xFF7C3AED)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                icon: actionLoading
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: const Text('Complete Weaving',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _singleActionBar(BuildContext context,
      {required String label,
        required String nextStatus,
        required Color color,
        required IconData icon,
        required String confirmTitle,
        required String confirmMsg}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border:
          const Border(top: BorderSide(color: ErpColors.borderLight)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ]),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: actionLoading
              ? null
              : () => _showConfirmDialog(context,
              title: confirmTitle,
              message: confirmMsg,
              nextStatus: nextStatus,
              color: color),
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          icon: actionLoading
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 18),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _completedBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
        color: ErpColors.successGreen.withOpacity(0.06),
        border: Border(
            top: BorderSide(
                color: ErpColors.successGreen.withOpacity(0.3)))),
    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.verified_rounded,
          color: ErpColors.successGreen, size: 20),
      SizedBox(width: 8),
      Text('Job Completed',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ErpColors.successGreen)),
    ]),
  );

  void _openAssignMachineSheet(BuildContext context) {
    ctrl.fetchFreeMachines();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignMachineSheet(ctrl: ctrl),
    );
  }

  void _showConfirmDialog(BuildContext context,
      {required String title,
        required String message,
        required String nextStatus,
        required Color color}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.info_outline_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800))),
        ]),
        content: Text(message,
            style: const TextStyle(
                fontSize: 13,
                color: ErpColors.textSecondary,
                height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: ErpColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ctrl.updateStatus(nextStatus);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Confirm',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ASSIGN MACHINE SHEET  (unchanged logic, kept intact)
// ════════════════════════════════════════════════════════════════

class _AssignMachineSheet extends StatefulWidget {
  final JobDetailController ctrl;
  const _AssignMachineSheet({required this.ctrl});
  @override
  State<_AssignMachineSheet> createState() => _AssignMachineSheetState();
}

class _AssignMachineSheetState extends State<_AssignMachineSheet> {
  static const _kFree = '__FREE__';
  MachineMini? _picked;
  Map<int, String?> _headMap = {};
  JobDetailController get _c => widget.ctrl;

  bool get _allSet {
    if (_picked == null || _picked!.noOfHead == 0) return false;
    for (var i = 0; i < _picked!.noOfHead; i++) {
      if (_headMap[i] == null) return false;
    }
    return true;
  }

  int get _setCount => _headMap.values.where((v) => v != null).length;

  List<Map<String, dynamic>> get _payload => [
    for (var i = 0; i < (_picked?.noOfHead ?? 0); i++)
      if (_headMap[i] != null)
        {
          'head': i + 1,
          'elastic': _headMap[i] == _kFree ? null : _headMap[i]!,
        },
  ];

  void _selectMachine(MachineMini m) {
    setState(() {
      _picked = m;
      final existing = _c.job.value?.machineHeadPlan ?? [];
      _headMap = {
        for (var i = 0; i < m.noOfHead; i++)
          i: _existingElasticId(existing, i + 1),
      };
    });
  }

  String? _existingElasticId(List<HeadElastic> plan, int headNo) {
    final entry = plan.where((h) => h.head == headNo).firstOrNull;
    if (entry == null) return null;
    final match = (_c.job.value?.plannedElastics ?? [])
        .where((e) => e.elasticName == entry.elasticName)
        .firstOrNull;
    return match?.elasticId ?? match?.elasticName;
  }

  void _setHead(int headIndex, String elasticValue) =>
      setState(() => _headMap[headIndex] = elasticValue);

  void _submit() {
    if (!_allSet) return;
    final id = _picked!.id;
    final payload = _payload;
    Navigator.of(context).pop();
    _c.assignMachine(id, payload);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.92),
      decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        _header(),
        const Divider(height: 1, color: ErpColors.borderLight),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _machineSection(),
                if (_picked != null) ...[
                  const SizedBox(height: 16),
                  _headSection(),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        _footer(bottomPad),
      ]),
    );
  }

  Widget _handle() => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Center(
      child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: ErpColors.borderLight,
              borderRadius: BorderRadius.circular(2))),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Machine',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 2),
            Text(
                _picked == null
                    ? 'Select a free machine below'
                    : 'Assign an elastic to each head',
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
          ],
        ),
      ),
      if (_picked != null) _progressChip(),
    ]),
  );

  Widget _progressChip() {
    final total = _picked!.noOfHead;
    final done = _setCount;
    final isDone = done == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: isDone
              ? ErpColors.successGreen.withOpacity(0.1)
              : ErpColors.warningAmber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Text('$done / $total heads',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color:
              isDone ? ErpColors.successGreen : ErpColors.warningAmber)),
    );
  }

  Widget _machineSection() => Obx(() {
    if (_c.machinesLoading.value) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
              child: CircularProgressIndicator(
                  color: ErpColors.accentBlue)));
    }
    if (_c.freeMachines.isEmpty) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.precision_manufacturing_outlined,
                    size: 40, color: ErpColors.textSecondary),
                SizedBox(height: 10),
                Text('No free machines available.',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 13)),
              ])));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SELECT MACHINE'),
        ...(_c.freeMachines as List).map((raw) {
          final m = raw as MachineMini;
          final isSelected = _picked?.id == m.id;
          return GestureDetector(
            onTap: () => _selectMachine(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                  color: isSelected
                      ? ErpColors.accentBlue.withOpacity(0.07)
                      : ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isSelected
                          ? ErpColors.accentBlue
                          : ErpColors.borderLight,
                      width: isSelected ? 1.5 : 1)),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: isSelected
                          ? ErpColors.accentBlue.withOpacity(0.12)
                          : ErpColors.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                      border:
                      Border.all(color: ErpColors.borderLight)),
                  child: Icon(Icons.precision_manufacturing_outlined,
                      size: 18,
                      color: isSelected
                          ? ErpColors.accentBlue
                          : ErpColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.machineID,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? ErpColors.accentBlue
                                    : ErpColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                            [
                              if (m.manufacturer.isNotEmpty) m.manufacturer,
                              '${m.noOfHead} heads',
                              '${m.noOfHooks} hooks',
                            ].join('  ·  '),
                            style: const TextStyle(
                                fontSize: 11,
                                color: ErpColors.textSecondary)),
                      ],
                    )),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: ErpColors.accentBlue, size: 20)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color:
                        ErpColors.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('FREE',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.successGreen)),
                  ),
              ]),
            ),
          );
        }),
      ],
    );
  });

  Widget _headSection() {
    final machine = _picked!;
    final jobElastics = _c.job.value?.plannedElastics ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('HEAD → ELASTIC  (${machine.machineID})'),
      if (jobElastics.isEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: ErpColors.warningAmber.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: ErpColors.warningAmber.withOpacity(0.3))),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: ErpColors.warningAmber, size: 16),
            SizedBox(width: 8),
            Expanded(
                child: Text('No planned elastics found for this job.',
                    style: TextStyle(
                        fontSize: 12,
                        color: ErpColors.warningAmber))),
          ]),
        )
      else ...[
        ...List.generate(machine.noOfHead, (i) {
          final assignedVal = _headMap[i];
          final isSet = assignedVal != null;
          final isFree = assignedVal == _kFree;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
                color: isSet
                    ? ErpColors.accentBlue.withOpacity(0.04)
                    : ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSet
                        ? ErpColors.accentBlue.withOpacity(0.35)
                        : ErpColors.borderLight)),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: ErpColors.accentBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: assignedVal,
                    isExpanded: true,
                    hint: const Text('Select Elastic',
                        style: TextStyle(
                            fontSize: 12, color: ErpColors.textMuted)),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ErpColors.textPrimary),
                    icon: const Icon(Icons.arrow_drop_down,
                        color: ErpColors.textMuted),
                    onChanged: (v) {
                      if (v != null) _setHead(i, v);
                    },
                    items: [
                      DropdownMenuItem<String>(
                        value: _kFree,
                        child: Row(children: [
                          const Icon(Icons.do_not_disturb_on_rounded,
                              size: 14, color: ErpColors.textMuted),
                          const SizedBox(width: 8),
                          const Text('Free — no elastic',
                              style: TextStyle(
                                  color: ErpColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13)),
                        ]),
                      ),
                      ...jobElastics.map((e) {
                        final val = e.elasticId ?? e.elasticName;
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(e.elasticName,
                              overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (isSet) ...[
                const SizedBox(width: 8),
                Icon(
                    isFree
                        ? Icons.do_not_disturb_on_rounded
                        : Icons.check_circle_rounded,
                    color: isFree
                        ? ErpColors.textMuted
                        : ErpColors.successGreen,
                    size: 18),
              ],
            ]),
          );
        }),
        if (!_allSet)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 12, color: ErpColors.textMuted),
              const SizedBox(width: 6),
              Text(
                  'Assign an elastic or mark as free for all '
                      '${machine.noOfHead} heads to confirm.',
                  style: const TextStyle(
                      fontSize: 11, color: ErpColors.textMuted)),
            ]),
          ),
      ],
    ]);
  }

  Widget _footer(double bottomPad) => Container(
    padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottomPad),
    decoration: const BoxDecoration(
        color: ErpColors.bgSurface,
        border:
        Border(top: BorderSide(color: ErpColors.borderLight))),
    child: Row(children: [
      SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ErpColors.borderMid),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
              const EdgeInsets.symmetric(horizontal: 20)),
          child: const Text('Cancel',
              style: TextStyle(
                  color: ErpColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Obx(
              () => SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed:
              (_allSet && !_c.actionLoading.value) ? _submit : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  disabledBackgroundColor:
                  ErpColors.accentBlue.withOpacity(0.35),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              icon: _c.actionLoading.value
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded,
                  size: 16, color: Colors.white),
              label: Text(
                  _c.actionLoading.value
                      ? 'Saving…'
                      : _picked == null
                      ? 'Select a Machine'
                      : !_allSet
                      ? '$_setCount / ${_picked!.noOfHead} heads set'
                      : 'Confirm Plan',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    ]),
  );

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: ErpColors.textSecondary)),
  );
}

// ════════════════════════════════════════════════════════════════
//  PDF SERVICE  —  A5, Excel-style, compact
//  Same design language as warping plan & covering program PDFs
// ════════════════════════════════════════════════════════════════


// ════════════════════════════════════════════════════════════════
//  PDF SERVICE  —  A5, Excel-style, compact
//  FIXES:
//  • PdfColor.fromInt() removed — uses PdfColor(r,g,b) 0-1 floats
//  • pw.Page → pw.MultiPage (supports header/footer/build as list)
// ════════════════════════════════════════════════════════════════

class JobDetailPdfService {
  // ── Print-safe palette (0–1 float RGB) ───────────────────────
  static const _dark    = PdfColor(0.102, 0.102, 0.102);   // #1A1A1A
  static const _mid     = PdfColor(0.267, 0.267, 0.267);   // #444444
  static const _lite    = PdfColor(0.533, 0.533, 0.533);   // #888888
  static const _hdrFill = PdfColor(0.851, 0.882, 0.949);   // #D9E1F2 Excel blue-grey
  static const _altFill = PdfColor(0.949, 0.949, 0.949);   // #F2F2F2 alt row
  static const _bdr     = PdfColor(0.667, 0.667, 0.667);   // #AAAAAA thin grid
  static const _bdrMed  = PdfColor(0.400, 0.400, 0.400);   // #666666 section box
  static const _white   = PdfColors.white;
  static const _red     = PdfColor(0.863, 0.149, 0.149);   // #DC2626
  static const _green   = PdfColor(0.086, 0.639, 0.290);   // #16A34A
  static const _blue    = PdfColor(0.114, 0.435, 0.922);   // #1D6FEB
  static const _purple  = PdfColor(0.486, 0.227, 0.929);   // #7C3AED
  static const _amber   = PdfColor(0.851, 0.475, 0.035);   // #D97706

  static Future<List<int>> generate(JobDetailModel job) async {
    final pdf = pw.Document();
    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();
    final today = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(_overviewPage(job, today, bold, reg));
    pdf.addPage(_warpingPage(job, today, bold, reg));
    pdf.addPage(_coveringPage(job, today, bold, reg));
    pdf.addPage(_weavingPage(job, today, bold, reg));
    pdf.addPage(_wastagePackingPage(job, today, bold, reg));

    return pdf.save();
  }

  // ── Shared: page header ───────────────────────────────────────
  static pw.Widget _pageHeader(
      String section, JobDetailModel job, String today,
      pw.Font bold, pw.Font reg) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(children: [
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(section,
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 11,
                            color: _dark,
                            letterSpacing: 0.5)),
                    pw.Text('${job.jobNo}   |   ${job.customerName}',
                        style: pw.TextStyle(font: reg, fontSize: 6.5, color: _mid)),
                  ]),
              pw.Text('Generated: $today',
                  style: pw.TextStyle(font: reg, fontSize: 6, color: _lite)),
            ]),
        pw.SizedBox(height: 2),
        pw.Divider(thickness: 0.65, color: _bdrMed),
        pw.SizedBox(height: 4),
      ]),
    );
  }

  // ── Shared: page footer ───────────────────────────────────────
  static pw.Widget _pageFooter(pw.Context ctx, pw.Font reg) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Column(children: [
        pw.Divider(thickness: 0.4, color: _bdr),
        pw.SizedBox(height: 2),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ANU TAPES — Factory ERP System',
                  style: pw.TextStyle(font: reg, fontSize: 5.5, color: _lite)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(font: reg, fontSize: 5.5, color: _lite)),
            ]),
      ]),
    );
  }

  // ── Shared: section heading ───────────────────────────────────
  static pw.Widget _secHeading(String title, pw.Font bold) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: bold, fontSize: 7, color: _dark, letterSpacing: 0.3)),
          pw.SizedBox(height: 2),
          pw.Divider(thickness: 0.8, color: _bdrMed),
          pw.SizedBox(height: 3),
        ]);
  }

  // ── Shared: cell helper ───────────────────────────────────────
  static pw.Widget _c(String text, pw.Font font, double size, PdfColor color,
      {pw.TextAlign align = pw.TextAlign.left,
        double hpad = 3.5,
        double vpad = 2.5}) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(horizontal: hpad, vertical: vpad),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: size, color: color),
            textAlign: align),
      );

  // ── Shared: KPI bar ───────────────────────────────────────────
  static pw.Widget _kpiBar(
      List<Map<String, String>> cells, pw.Font bold, pw.Font reg) {
    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.35),
      columnWidths: {
        for (var i = 0; i < cells.length; i++)
          i: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _hdrFill),
          children: cells
              .map((c) => _c(c['l']!, reg, 5.5, _mid,
              align: pw.TextAlign.center, vpad: 2))
              .toList(),
        ),
        pw.TableRow(
          children: cells
              .map((c) => _c(c['v']!, bold, 9, _dark,
              align: pw.TextAlign.center, vpad: 4))
              .toList(),
        ),
      ],
    );
  }

  // ── Shared: 2-col key-value helper ───────────────────────────
  static pw.Widget _kv(
      String label, String value, pw.Font bold, pw.Font reg) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 54,
          child: pw.Text(label,
              style: pw.TextStyle(font: reg, fontSize: 6, color: _mid)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(font: bold, fontSize: 7, color: _dark)),
        ),
      ]),
    );
  }

  // ── Shared: remarks box ───────────────────────────────────────
  static pw.Widget _remarksBox(String text, pw.Font bold, pw.Font reg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
          color: _altFill,
          border: pw.Border.all(color: _bdrMed, width: 0.6)),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Note: ',
                style: pw.TextStyle(font: bold, fontSize: 6, color: _mid)),
            pw.Expanded(
              child: pw.Text(text,
                  style: pw.TextStyle(
                      font: reg,
                      fontSize: 6,
                      color: _mid,
                      fontStyle: pw.FontStyle.italic)),
            ),
          ]),
    );
  }

  // ── Shared: beam cell (2-col grid) ────────────────────────────
  static pw.Widget _beamCell(BeamModel b, pw.Font bold, pw.Font reg) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _bdrMed, width: 0.8)),
      child: pw.Column(children: [
        pw.Container(
          color: _hdrFill,
          child: pw.Row(children: [
            pw.Expanded(
                child: _c('Beam ${b.beamNo}', bold, 7, _dark, vpad: 3.5)),
            _c('${b.totalEnds} ends', reg, 6, _mid,
                align: pw.TextAlign.right, vpad: 3.5),
          ]),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _bdr, width: 0.3),
          columnWidths: const {
            0: pw.FixedColumnWidth(12),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(20),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _altFill),
              children: ['S', 'YARN', 'ENDS']
                  .map((h) => _c(h, bold, 5.5, _mid,
                  align: pw.TextAlign.center))
                  .toList(),
            ),
            ...b.sections.asMap().entries.map((e) {
              final s = e.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: e.key.isOdd ? _altFill : _white),
                children: [
                  _c('${s.sectionNo}', reg, 6, _mid,
                      align: pw.TextAlign.center),
                  _c(
                      s.yarnUnit.isNotEmpty
                          ? '${s.yarnName} (${s.yarnUnit})'
                          : s.yarnName,
                      reg, 6, _dark),
                  _c('${s.ends}', bold, 6.5, _dark,
                      align: pw.TextAlign.center),
                ],
              );
            }),
          ],
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 1 — OVERVIEW
  // ══════════════════════════════════════════════════════════════
  static pw.MultiPage _overviewPage(
      JobDetailModel job, String today, pw.Font bold, pw.Font reg) {
    final pct = job.completionPct * 100;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(base: reg, bold: bold),
      header: (_) => _pageHeader('JOB OVERVIEW', job, today, bold, reg),
      footer: (ctx) => _pageFooter(ctx, reg),
      build: (ctx) => [
        // Job info 2-col table
        pw.Table(
          border: pw.TableBorder.all(color: _bdr, width: 0.35),
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children: [
                _c('JOB DETAILS', bold, 6.5, _mid),
                _c('CUSTOMER DETAILS', bold, 6.5, _mid),
              ],
            ),
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('Job No', job.jobNo, bold, reg),
                      _kv('Date', job.date ?? '-', bold, reg),
                      _kv('Status',
                          job.status.toUpperCase().replaceAll('_', ' '),
                          bold, reg),
                      _kv('Order No', job.orderNo ?? '-', bold, reg),
                    ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('Customer', job.customerName, bold, reg),
                      _kv('Phone', job.customerPhone, bold, reg),
                    ]),
              ),
            ]),
          ],
        ),
        pw.SizedBox(height: 6),

        // KPI bar
        _kpiBar([
          {'v': '${job.totalPlanned.toStringAsFixed(0)}m', 'l': 'PLANNED'},
          {'v': '${job.totalProduced.toStringAsFixed(0)}m', 'l': 'PRODUCED'},
          {'v': '${job.totalPacked.toStringAsFixed(0)}m',   'l': 'PACKED'},
          {'v': '${job.totalWastage.toStringAsFixed(0)}m',  'l': 'WASTAGE'},
          {'v': '${pct.toStringAsFixed(0)}%',               'l': 'COMPLETION'},
        ], bold, reg),
        pw.SizedBox(height: 8),

        // Planned elastics table
        _secHeading('PLANNED ELASTICS', bold),
        pw.Table(
          border: pw.TableBorder.all(color: _bdr, width: 0.35),
          columnWidths: const {
            0: pw.FixedColumnWidth(12),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(1.4),
            4: pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children: ['#', 'ELASTIC', 'PLANNED', 'PRODUCED', 'WASTAGE']
                  .map((h) => _c(h, bold, 6, _mid,
                  align: pw.TextAlign.center))
                  .toList(),
            ),
            ...job.plannedElastics.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final produced = job.producedElastics
                  .where((p) => p.elasticName == e.elasticName)
                  .fold(0.0, (s, p) => s + p.quantity);
              final wastage = job.wastageElastics
                  .where((w) => w.elasticName == e.elasticName)
                  .fold(0.0, (s, w) => s + w.quantity);
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? _altFill : _white),
                children: [
                  _c('${i + 1}', reg, 6, _lite,
                      align: pw.TextAlign.center),
                  _c(e.elasticName, bold, 7, _dark),
                  _c('${e.quantity.toStringAsFixed(0)}m', reg, 7, _dark,
                      align: pw.TextAlign.center),
                  _c('${produced.toStringAsFixed(0)}m', reg, 7, _blue,
                      align: pw.TextAlign.center),
                  _c(wastage > 0
                      ? '${wastage.toStringAsFixed(1)}m'
                      : '—', reg, 7, wastage > 0 ? _red : _lite,
                      align: pw.TextAlign.center),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 2 — WARPING
  // ══════════════════════════════════════════════════════════════
  static pw.MultiPage _warpingPage(
      JobDetailModel job, String today, pw.Font bold, pw.Font reg) {
    final w = job.warping;
    final te = w?.beams.fold(0, (s, b) => s + b.totalEnds) ?? 0;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(base: reg, bold: bold),
      header: (_) => _pageHeader('WARPING PROGRAM', job, today, bold, reg),
      footer: (ctx) => _pageFooter(ctx, reg),
      build: (ctx) => w == null
          ? [
        pw.Text('No warping data.',
            style: pw.TextStyle(font: reg, color: _lite))
      ]
          : [
        _kpiBar([
          {'v': '${w.beams.length}', 'l': 'BEAMS'},
          {'v': '$te',               'l': 'TOTAL ENDS'},
          {'v': w.status.toUpperCase(), 'l': 'STATUS'},
          {'v': w.date ?? '-',       'l': 'STARTED'},
          {'v': w.completedDate ?? '-', 'l': 'COMPLETED'},
        ], bold, reg),
        pw.SizedBox(height: 8),
        _secHeading('BEAM DETAILS', bold),

        // 2-column beam grid
        ...() {
          final beams = w.beams;
          final rows = <pw.Widget>[];
          for (var i = 0; i < beams.length; i += 2) {
            final leftCell = _beamCell(beams[i], bold, reg);
            final rightCell = (i + 1 < beams.length)
                ? _beamCell(beams[i + 1], bold, reg)
                : pw.SizedBox();
            rows.add(pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: leftCell),
                pw.SizedBox(width: 4),
                pw.Expanded(child: rightCell),
              ],
            ));
            rows.add(pw.SizedBox(height: 5));
          }
          return rows;
        }(),

        if (w.remarks.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _remarksBox(w.remarks, bold, reg),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 3 — COVERING
  // ══════════════════════════════════════════════════════════════
  static pw.MultiPage _coveringPage(
      JobDetailModel job, String today, pw.Font bold, pw.Font reg) {
    final c = job.covering;
    final totalQty =
        c?.elasticPlanned.fold(0.0, (s, e) => s + e.quantity) ?? 0.0;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(base: reg, bold: bold),
      header: (_) => _pageHeader('COVERING PROGRAM', job, today, bold, reg),
      footer: (ctx) => _pageFooter(ctx, reg),
      build: (ctx) => c == null
          ? [
        pw.Text('No covering data.',
            style: pw.TextStyle(font: reg, color: _lite))
      ]
          : [
        _kpiBar([
          {'v': '${c.elasticPlanned.length}',     'l': 'ELASTICS'},
          {'v': '${totalQty.toStringAsFixed(0)}m','l': 'TOTAL QTY'},
          {'v': c.status.toUpperCase(),           'l': 'STATUS'},
          {'v': c.date ?? '-',                    'l': 'STARTED'},
          {'v': c.completedDate ?? '-',           'l': 'COMPLETED'},
        ], bold, reg),
        pw.SizedBox(height: 8),
        _secHeading('ELASTIC PLAN', bold),
        pw.Table(
          border: pw.TableBorder.all(color: _bdr, width: 0.35),
          columnWidths: const {
            0: pw.FixedColumnWidth(12),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children: ['#', 'ELASTIC', 'PLANNED QTY (m)']
                  .map((h) => _c(h, bold, 6, _mid,
                  align: pw.TextAlign.center))
                  .toList(),
            ),
            ...c.elasticPlanned.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? _altFill : _white),
                children: [
                  _c('${i + 1}', reg, 6, _lite,
                      align: pw.TextAlign.center),
                  _c(e.elasticName, bold, 7, _dark),
                  _c('${e.quantity.toStringAsFixed(0)}', bold, 7,
                      _dark,
                      align: pw.TextAlign.center),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children: [
                _c('', reg, 6, _mid),
                _c('TOTAL', bold, 7, _dark),
                _c('${totalQty.toStringAsFixed(0)}', bold, 8, _dark,
                    align: pw.TextAlign.center),
              ],
            ),
          ],
        ),
        if (c.remarks.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _remarksBox(c.remarks, bold, reg),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 4 — WEAVING
  // ══════════════════════════════════════════════════════════════
  static pw.MultiPage _weavingPage(
      JobDetailModel job, String today, pw.Font bold, pw.Font reg) {
    final total =
    job.shiftDetails.fold(0, (s, d) => s + d.productionMeters);
    final closed =
        job.shiftDetails.where((d) => d.status == 'closed').length;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(base: reg, bold: bold),
      header: (_) =>
          _pageHeader('WEAVING — SHIFT LOG', job, today, bold, reg),
      footer: (ctx) => _pageFooter(ctx, reg),
      build: (ctx) => [
        _kpiBar([
          {'v': '${total}m',                      'l': 'PRODUCED'},
          {'v': '${job.shiftDetails.length}',     'l': 'SHIFTS'},
          {'v': '$closed',                        'l': 'CLOSED'},
        ], bold, reg),
        pw.SizedBox(height: 8),
        _secHeading('SHIFT RECORDS', bold),
        pw.Table(
          border: pw.TableBorder.all(color: _bdr, width: 0.35),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.4),
            1: pw.FlexColumnWidth(0.8),
            2: pw.FlexColumnWidth(1.1),
            3: pw.FlexColumnWidth(1.8),
            4: pw.FlexColumnWidth(2.0),
            5: pw.FlexColumnWidth(1.0),
            6: pw.FlexColumnWidth(0.9),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children: [
                'DATE', 'SHIFT', 'MACHINE', 'OPERATOR',
                'ELASTIC', 'PROD.', 'STATUS',
              ]
                  .map((h) => _c(h, bold, 5.5, _mid,
                  align: pw.TextAlign.center))
                  .toList(),
            ),
            ...job.shiftDetails.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              final sc = d.status == 'closed'
                  ? _green
                  : d.status == 'running'
                  ? _purple
                  : _blue;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? _altFill : _white),
                children: [
                  _c(d.date ?? '-', reg, 6, _dark),
                  _c(d.shiftShort, reg, 6, _mid,
                      align: pw.TextAlign.center),
                  _c(d.machineName, reg, 6, _dark),
                  _c(d.operatorName, reg, 6, _dark),
                  _c(d.elastics.isNotEmpty
                      ? d.elastics.first.elasticName
                      : '-', reg, 6, _dark),
                  _c('${d.productionMeters}m', bold, 6.5, _dark,
                      align: pw.TextAlign.center),
                  _c(d.status.toUpperCase(), bold, 5.5, sc,
                      align: pw.TextAlign.center),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 5 — WASTAGE + PACKING
  // ══════════════════════════════════════════════════════════════
  static pw.MultiPage _wastagePackingPage(
      JobDetailModel job, String today, pw.Font bold, pw.Font reg) {
    final tw = job.wastages.fold(0.0, (s, w) => s + w.quantity);
    final tp = job.wastages.fold(0.0, (s, w) => s + w.penalty);
    final wr = job.totalPlanned > 0 ? (tw / job.totalPlanned * 100) : 0.0;
    final tpk = job.packingDetails.fold(0, (s, p) => s + p.total);
    final tdi = job.packingDetails
        .where((p) => p.status == 'dispatched')
        .fold(0, (s, p) => s + p.total);
    final tro = job.packingDetails.fold(0, (s, p) => s + p.rolls);

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(base: reg, bold: bold),
      header: (_) =>
          _pageHeader('WASTAGE + PACKING', job, today, bold, reg),
      footer: (ctx) => _pageFooter(ctx, reg),
      build: (ctx) => [
        // ── Wastage ───────────────────────────────────────────
        _secHeading('WASTAGE REPORT', bold),
        _kpiBar([
          {'v': '${tw.toStringAsFixed(1)}m',   'l': 'TOTAL WASTAGE'},
          {'v': 'Rs.${tp.toStringAsFixed(0)}', 'l': 'PENALTY'},
          {'v': '${wr.toStringAsFixed(2)}%',   'l': 'WASTAGE RATE'},
          {'v': '${job.wastages.length}',      'l': 'RECORDS'},
        ], bold, reg),
        pw.SizedBox(height: 5),
        pw.Table(
          border: pw.TableBorder.all(color: _bdr, width: 0.35),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(2.0),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(2.5),
            5: pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children:
              ['DATE', 'ELASTIC', 'EMPLOYEE', 'QTY', 'REASON', 'PENALTY']
                  .map((h) => _c(h, bold, 5.5, _mid,
                  align: pw.TextAlign.center))
                  .toList(),
            ),
            ...job.wastages.asMap().entries.map((entry) {
              final i = entry.key;
              final w = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? _altFill : _white),
                children: [
                  _c(w.date ?? '-', reg, 6, _dark),
                  _c(w.elasticName, bold, 6, _dark),
                  _c(w.employeeName, reg, 6, _dark),
                  _c('${w.quantity.toStringAsFixed(1)}', bold, 6.5, _red,
                      align: pw.TextAlign.center),
                  _c(w.reason, reg, 5.8, _mid),
                  _c(w.penalty > 0
                      ? 'Rs.${w.penalty.toStringAsFixed(0)}'
                      : '—', bold, 6,
                      w.penalty > 0 ? _red : _lite,
                      align: pw.TextAlign.center),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 10),

        // ── Packing ───────────────────────────────────────────
        _secHeading('PACKING & DISPATCH', bold),
        _kpiBar([
          {'v': '${tpk}m',       'l': 'PACKED'},
          {'v': '${tdi}m',       'l': 'DISPATCHED'},
          {'v': '${tpk - tdi}m', 'l': 'PENDING'},
          {'v': '$tro',          'l': 'TOTAL ROLLS'},
        ], bold, reg),
        pw.SizedBox(height: 5),
        pw.Table(
          border: pw.TableBorder.all(color: _bdr, width: 0.35),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),  // pack id
            1: pw.FlexColumnWidth(2.0),  // elastic
            2: pw.FlexColumnWidth(1.5),  // packed by
            3: pw.FlexColumnWidth(1.5),  // checked by
            4: pw.FixedColumnWidth(24),  // meters
            5: pw.FixedColumnWidth(22),  // rolls
            6: pw.FixedColumnWidth(20),  // joints
            7: pw.FixedColumnWidth(24),  // weight
            8: pw.FlexColumnWidth(1.0),  // status
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children: [
                'PACK ID', 'ELASTIC', 'PACKED BY', 'CHECKED BY',
                'MTR', 'ROLLS', 'JNT', 'WT(kg)', 'STATUS',
              ]
                  .map((h) => _c(h, bold, 5, _mid,
                  align: pw.TextAlign.center))
                  .toList(),
            ),
            ...job.packingDetails.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final sc = p.status == 'dispatched'
                  ? _green
                  : p.status == 'ready'
                  ? _blue
                  : _amber;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? _altFill : _white),
                children: [
                  _c(p.shortId, bold, 5.5, _blue,
                      align: pw.TextAlign.center),
                  _c(p.elasticName, bold, 6, _dark),
                  _c(p.employeeName, reg, 5.8, _dark),
                  _c(p.checkedBy ?? '—', reg, 5.8, _dark),
                  _c('${p.total}', bold, 6.5, _dark,
                      align: pw.TextAlign.center),
                  _c('${p.rolls}×${p.metersPerRoll}', reg, 5.5, _mid,
                      align: pw.TextAlign.center),
                  _c(p.joints > 0 ? '${p.joints}' : '—', reg, 6,
                      _mid, align: pw.TextAlign.center),
                  _c(p.weight > 0
                      ? p.weight.toStringAsFixed(2)
                      : '—', reg, 6, _mid,
                      align: pw.TextAlign.center),
                  _c(p.status.toUpperCase(), bold, 5, sc,
                      align: pw.TextAlign.center),
                ],
              );
            }),
            // Totals row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _hdrFill),
              children: [
                _c('', reg, 6, _mid),
                _c('TOTAL', bold, 6.5, _dark),
                _c('', reg, 6, _mid),
                _c('', reg, 6, _mid),
                _c('${tpk}m', bold, 7, _dark,
                    align: pw.TextAlign.center),
                _c('$tro', bold, 7, _dark,
                    align: pw.TextAlign.center),
                _c('', reg, 6, _mid),
                _c('', reg, 6, _mid),
                _c('', reg, 6, _mid),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

final _sampleJobDetail = JobDetailModel(
  id: 'sample001',
  jobNo: 'J-147',
  status: 'weaving',
  customerName: 'Sumeet Garments Pvt. Ltd.',
  customerPhone: '+91 98765 43210',
  date: '10 Jan 2026',
  orderNo: 'ORD-2026-089',
  plannedElastics: const [
    ElasticQty(elasticId: 'e1', elasticName: '25mm Black Elastic', quantity: 800),
    ElasticQty(elasticId: 'e2', elasticName: '38mm White Waistband', quantity: 1200),
    ElasticQty(elasticId: 'e3', elasticName: '20mm Soft Knit Grey', quantity: 500),
  ],
  producedElastics: const [
    ElasticQty(elasticName: '25mm Black Elastic', quantity: 620),
    ElasticQty(elasticName: '38mm White Waistband', quantity: 980),
    ElasticQty(elasticName: '20mm Soft Knit Grey', quantity: 240),
  ],
  packedElastics: const [
    ElasticQty(elasticName: '25mm Black Elastic', quantity: 600),
    ElasticQty(elasticName: '38mm White Waistband', quantity: 800),
  ],
  wastageElastics: const [
    ElasticQty(elasticName: '25mm Black Elastic', quantity: 8),
    ElasticQty(elasticName: '38mm White Waistband', quantity: 27.5),
    ElasticQty(elasticName: '20mm Soft Knit Grey', quantity: 12),
  ],
  warping: JobWarping(
    status: 'completed', date: '15 Jan 2026', completedDate: '17 Jan 2026',
    noOfBeams: 3,
    remarks: 'Warping completed on schedule. Beam 2 spandex tension adjusted.',
    beams: [
      BeamModel(beamNo: 1, totalEnds: 360, sections: const [
        BeamSection(sectionNo: 1, yarnName: 'Nylon 70D/24F', ends: 120, yarnUnit: ''),
        BeamSection(sectionNo: 2, yarnName: 'Polyester 150D/48F', ends: 160, yarnUnit: ''),
        BeamSection(sectionNo: 3, yarnName: 'Nylon 70D/24F', ends: 80, yarnUnit: ''),
      ]),
      BeamModel(beamNo: 2, totalEnds: 280, sections: const [
        BeamSection(sectionNo: 1, yarnName: 'Polyester 75D/36F', ends: 140, yarnUnit: ''),
        BeamSection(sectionNo: 2, yarnName: 'Nylon Spandex 40D', ends: 80, yarnUnit: ''),
        BeamSection(sectionNo: 3, yarnName: 'Polyester 150D/48F', ends: 60, yarnUnit: ''),
      ]),
      BeamModel(beamNo: 3, totalEnds: 200, sections: const [
        BeamSection(sectionNo: 1, yarnName: 'Nylon 70D/24F', ends: 100, yarnUnit: ''),
        BeamSection(sectionNo: 2, yarnName: 'Polyester 75D/36F', ends: 100, yarnUnit: ''),
      ]),
    ],
  ),
  covering: JobCovering(
    status: 'completed', date: '18 Jan 2026', completedDate: '22 Jan 2026',
    remarks: 'All machines ran without issues. M-02 had minor yarn break at hr 2.',
    elasticPlanned: const [
      ElasticQty(elasticName: '25mm Black Elastic', quantity: 800),
      ElasticQty(elasticName: '38mm White Waistband', quantity: 1200),
      ElasticQty(elasticName: '20mm Soft Knit Grey', quantity: 500),
    ],
  ),
  shiftDetails: [
    JobShiftDetail(id: 's1', date: '23 Jan 2026', shift: 'DAY', status: 'closed',
        timer: '08:00:00', productionMeters: 148, machineName: 'LM-04',
        machineNoOfHead: 4, operatorName: 'Dinesh Verma', operatorDept: 'weaving',
        elastics: const [HeadElastic(head: 1, elasticName: '25mm Black Elastic')],
        description: '', feedback: ''),
    JobShiftDetail(id: 's2', date: '23 Jan 2026', shift: 'NIGHT', status: 'closed',
        timer: '08:00:00', productionMeters: 152, machineName: 'LM-04',
        machineNoOfHead: 4, operatorName: 'Pradeep Nair', operatorDept: 'weaving',
        elastics: const [HeadElastic(head: 1, elasticName: '25mm Black Elastic')],
        description: '', feedback: ''),
    JobShiftDetail(id: 's3', date: '24 Jan 2026', shift: 'DAY', status: 'closed',
        timer: '08:00:00', productionMeters: 175, machineName: 'LM-05',
        machineNoOfHead: 4, operatorName: 'Sunil Mehta', operatorDept: 'weaving',
        elastics: const [HeadElastic(head: 1, elasticName: '38mm White Waistband')],
        description: '', feedback: ''),
    JobShiftDetail(id: 's5', date: '25 Jan 2026', shift: 'DAY', status: 'running',
        timer: '04:30:00', productionMeters: 82, machineName: 'LM-06',
        machineNoOfHead: 4, operatorName: 'Vikram Joshi', operatorDept: 'weaving',
        elastics: const [HeadElastic(head: 1, elasticName: '20mm Soft Knit Grey')],
        description: '', feedback: ''),
  ],
  wastages: [
    JobWastage(id: 'w1', elasticName: '25mm Black Elastic',
        employeeName: 'Dinesh Verma', quantity: 8.0, penalty: 0,
        reason: 'Yarn break — beam start', date: '23 Jan 2026'),
    JobWastage(id: 'w2', elasticName: '38mm White Waistband',
        employeeName: 'Pradeep Nair', quantity: 12.5, penalty: 120.0,
        reason: 'Tension inconsistency', date: '24 Jan 2026'),
    JobWastage(id: 'w3', elasticName: '38mm White Waistband',
        employeeName: 'Sunil Mehta', quantity: 15.0, penalty: 200.0,
        reason: 'Machine calibration issue', date: '24 Jan 2026'),
    JobWastage(id: 'w4', elasticName: '20mm Soft Knit Grey',
        employeeName: 'Vikram Joshi', quantity: 12.0, penalty: 0,
        reason: 'Yarn colour mismatch — rejected', date: '25 Jan 2026'),
  ],
  packingDetails: [
    JobPacking(id: '6abc1234ef56', elasticName: '25mm Black Elastic',
        employeeName: 'Meena Sharma', checkedBy: 'Rajan Kumar',
        rolls: 24, metersPerRoll: 25, total: 600, joints: 2,
        quantity: 600, weight: 4.80, batch: 'B001',
        status: 'dispatched', date: '26 Jan 2026'),
    JobPacking(id: '6abc5678ab90', elasticName: '38mm White Waistband',
        employeeName: 'Kavita Patel', checkedBy: 'Suresh Iyer',
        rolls: 16, metersPerRoll: 50, total: 800, joints: 1,
        quantity: 800, weight: 7.20, batch: 'B002',
        status: 'ready', date: '27 Jan 2026'),
    JobPacking(id: '6abc9012cd34', elasticName: '20mm Soft Knit Grey',
        employeeName: 'Meena Sharma', checkedBy: null,
        rolls: 6, metersPerRoll: 40, total: 240, joints: 0,
        quantity: 240, weight: 1.92, batch: 'B003',
        status: 'packing', date: '28 Jan 2026'),
  ],
  machineId: '',
  machineName: '',
  machineNoOfHead: 6,
  machineHeadPlan: const [],
);