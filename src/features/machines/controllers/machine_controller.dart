import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// FormData and MultipartFile exist in both packages; the bill upload
// needs Dio's.
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:intl/intl.dart';

import '../models/machine.dart';
import '../models/service_bill.dart';
import '../../../core/api_client.dart';
import '../../../core/app_config.dart';


// ══════════════════════════════════════════════════════════════
//  MACHINE API SERVICE
// ══════════════════════════════════════════════════════════════

class MachineApiService {
  static final Dio _dio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

  static Future<List<MachineListItem>> fetchAll() async {
    final res = await _dio.get('/machine/get-machines');
    return (res.data['machines'] as List)
        .map((e) => MachineListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchDetail(String machineId) async {
    final res = await _dio.get(
      '/machine/get-machine-detail',
      queryParameters: {'id': machineId},
    );
    return res.data['machine'] as Map<String, dynamic>;
  }

  static Future<void> create(MachineCreate payload) async {
    await _dio.post('/machine/create-machine', data: payload.toJson());
  }

  /// Remaps which elastic sits on which head.
  ///
  /// The server refuses with a 409 and `code: HOOKS_EXCEED_MACHINE` when a
  /// product needs more hooks than the machine has. That is a question, not
  /// a failure — the floor sometimes runs a product on a smaller machine
  /// deliberately — so `confirmHooks` is the way through, and it must come
  /// from the operator answering it, never from an automatic retry.
  ///
  /// Nothing calls this yet. The parameter is here so that whoever wires it
  /// up finds the escape hatch rather than a refusal with no way past it.
  static Future<String> updateElastics({
    required String machineCode,
    required List elastics,
    bool confirmHooks = false,
  }) async {
    final res = await _dio.put('/machine/updateOrder', data: {
      'id':      machineCode,
      'elastics': elastics,
      if (confirmHooks) 'confirmHooks': true,
    });
    return res.data['data']?.toString() ?? '';
  }

  /// Updates the head count of a machine.
  /// Backend enforces: machine must be "free" to allow this change.
  static Future<void> updateHeads({
    required String machineId,
    required int noOfHeads,
  }) async {
    await _dio.patch('/machine/update-heads', data: {
      'machineId': machineId,
      'noOfHead':  noOfHeads,
    });
  }

  /// POST /machine/add-service-log
  ///
  /// `setMaintenance` records the job and pulls the machine off the floor
  /// in one save, so a machine can never be left running against a log
  /// that says it is stripped down. A machine mid-job is refused with a
  /// 409 rather than pulled — its job would be left pointing at a machine
  /// that is out of service — and the caller is told to stop the job first.
  static Future<Map<String, dynamic>> addServiceLog({
    required String machineId,
    required String type,
    required String description,
    String? technician,
    double cost = 0,
    DateTime? nextServiceDate,
    bool resolved = true,
    bool setMaintenance = false,
  }) async {
    final res = await _dio.post('/machine/add-service-log', data: {
      'machineId':       machineId,
      'type':            type,
      'description':     description,
      'technician':      technician ?? '',
      'cost':            cost,
      if (nextServiceDate != null)
        'nextServiceDate': nextServiceDate.toIso8601String(),
      'resolved':        resolved,
      'setMaintenance':  setMaintenance,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Service & spare bills ──────────────────────────────────

  /// Every bill for a machine, or just one log's when `serviceLogId` is
  /// given. The file payload is never in this response.
  static Future<ServiceBillList> listBills({
    required String machineId,
    String? serviceLogId,
  }) async {
    final res = await _dio.get('/machine/service-bills', queryParameters: {
      'machineId': machineId,
      if (serviceLogId != null) 'serviceLogId': serviceLogId,
    });
    return ServiceBillList.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<ServiceBill> uploadBill({
    required String machineId,
    required String serviceLogId,
    required String kind,
    required Uint8List bytes,
    required String filename,
    double amount = 0,
    String vendor = '',
    String billNo = '',
    DateTime? billDate,
    String partName = '',
    String notes = '',
  }) async {
    // No content type on the part. Dio defaults every part to
    // application/octet-stream unless one is given, and the class that
    // names one (DioMediaType) does not exist in older Dio releases —
    // so the server resolves an unlabelled part by its extension
    // instead. See resolveBillType in api/machine.js. Which is why the
    // filename below must keep its extension.
    final form = FormData.fromMap({
      'machineId':    machineId,
      'serviceLogId': serviceLogId,
      'kind':         kind,
      'amount':       amount,
      'vendor':       vendor,
      'billNo':       billNo,
      if (billDate != null) 'billDate': billDate.toIso8601String(),
      'partName':     partName,
      'notes':        notes,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/machine/service-bill', data: form);
    return ServiceBill.fromJson(res.data['bill'] as Map<String, dynamic>);
  }

  static Future<Uint8List> billBytes(String billId) async {
    final res = await _dio.get<List<int>>(
      '/machine/service-bill/$billId/file',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  static Future<void> deleteBill(String billId) async {
    await _dio.delete('/machine/service-bill/$billId');
  }

  // Predicted-maintenance health for all machines.
  static Future<List<Map<String, dynamic>>> predictiveHealth() async {
    final res = await _dio.get('/machine/predictive-health');
    return (res.data['machines'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // On-demand AI diagnosis for one machine.
  static Future<String> healthAdvice(String machineId) async {
    final res = await _dio.get('/machine/health-advice/$machineId');
    return (res.data['advice'] ?? '').toString();
  }
}

// ══════════════════════════════════════════════════════════════
//  MACHINE LIST CONTROLLER
//  FIX: was MachineViewController using both http + Dio packages.
//       Now unified with only Dio + proper error handling.
// ══════════════════════════════════════════════════════════════

class MachineListController extends GetxController {
  // ── Data ──────────────────────────────────────────────────
  final allMachines      = <MachineListItem>[].obs;
  final filteredMachines = <MachineListItem>[].obs;

  // ── UI state ──────────────────────────────────────────────
  final isLoading    = true.obs;
  final errorMsg     = Rxn<String>();
  final searchQuery  = ''.obs;
  final statusFilter = 'all'.obs;  // "all" | "free" | "running" | "maintenance"

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    // Reactively re-filter whenever search or status filter changes
    ever(searchQuery,  (_) => _applyFilter());
    ever(statusFilter, (_) => _applyFilter());
    fetchMachines();
  }

  // ── Fetch ─────────────────────────────────────────────────
  /// FIX: original getMachines() had no try/catch → silent failure
  Future<void> fetchMachines() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final data = await MachineApiService.fetchAll();
      allMachines.value = data;
      _applyFilter();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to load machines';
      errorMsg.value = msg;
      _snack('Load Error', msg, isError: true);
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Filter ────────────────────────────────────────────────
  void _applyFilter() {
    var list = allMachines.toList();

    if (statusFilter.value != 'all') {
      list = list.where((m) => m.status == statusFilter.value).toList();
    }
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list.where((m) =>
      m.machineCode.toLowerCase().contains(q) ||
          m.manufacturer.toLowerCase().contains(q)).toList();
    }

    filteredMachines.value = list;
  }

  void setStatusFilter(String f) => statusFilter.value = f;
  void setSearch(String q)       => searchQuery.value  = q;

  // ── Stats helpers ─────────────────────────────────────────
  int get totalCount       => allMachines.length;
  int get runningCount     => allMachines.where((m) => m.isRunning).length;
  int get freeCount        => allMachines.where((m) => m.isFree).length;
  int get maintenanceCount => allMachines.where((m) => m.isMaintenance).length;
}

// ══════════════════════════════════════════════════════════════
//  MACHINE DETAIL CONTROLLER
// ══════════════════════════════════════════════════════════════

class MachineDetailController extends GetxController {
  final String machineId;
  MachineDetailController(this.machineId);

  // ── Data ──────────────────────────────────────────────────
  final machine     = Rxn<MachineDetail>();
  final shifts      = <MachineShiftHistory>[].obs;
  final serviceLogs = <MachineServiceLog>[].obs;

  // ── UI state ──────────────────────────────────────────────
  final isLoading  = true.obs;
  final isUpdating = false.obs;
  final errorMsg   = Rxn<String>();

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  // ── Fetch ─────────────────────────────────────────────────
  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final data = await MachineApiService.fetchDetail(machineId);
      machine.value = MachineDetail.fromJson(data);
      shifts.value  = (data['result'] as List? ?? [])
          .map((e) => MachineShiftHistory.fromJson(e as Map<String, dynamic>))
          .toList();
      serviceLogs.value = (data['serviceLogs'] as List? ?? [])
          .map((e) => MachineServiceLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to load machine details';
      errorMsg.value = msg;
      _snack('Load Error', msg, isError: true);
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Stats (last N shifts) ─────────────────────────────────
  double get avgEfficiency {
    if (shifts.isEmpty) return 0;
    return shifts.fold(0.0, (s, sh) => s + sh.efficiency) / shifts.length;
  }

  double get avgOutput {
    if (shifts.isEmpty) return 0;
    return shifts.fold(0.0, (s, sh) => s + sh.outputMeters) / shifts.length;
  }

  int get totalOutput =>
      shifts.fold(0, (s, sh) => s + sh.outputMeters);

  // ── Update head count (only allowed when machine is free) ──
  Future<void> updateHeads(int newCount) async {
    isUpdating.value = true;
    try {
      await MachineApiService.updateHeads(
        machineId: machineId,
        noOfHeads: newCount,
      );
      _snack('Heads Updated',
          'Head count changed to $newCount', isError: false);
      await fetchDetail(); // refresh so HeroCard shows new count
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to update head count';
      _snack('Update Failed', msg, isError: true);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isUpdating.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ADD MACHINE CONTROLLER
// ══════════════════════════════════════════════════════════════

class AddMachineController extends GetxController {
  final VoidCallback? onSuccess;
  AddMachineController({this.onSuccess});

  final isSaving = false.obs;

  Future<void> addMachine(MachineCreate payload) async {
    isSaving.value = true;
    try {
      await MachineApiService.create(payload);
      _snack('Machine Added',
          '${payload.machineCode} has been registered successfully',
          isError: false);
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Failed to create machine';
      _snack('Save Failed', msg, isError: true);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isSaving.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  MACHINE SERVICE LOG MODEL
// ══════════════════════════════════════════════════════════════

class MachineServiceLog {
  final String id;
  final DateTime date;
  final String type;         // Preventive | Corrective | Breakdown | Inspection | Other
  final String description;
  final String technician;
  final double cost;
  final DateTime? nextServiceDate;
  final bool resolved;

  /// Rolled up by the detail endpoint so the history renders in one
  /// request instead of one per log. The files themselves are fetched
  /// only when a bill is actually opened.
  final int billCount;
  final double billTotal;

  MachineServiceLog({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.technician,
    required this.cost,
    this.nextServiceDate,
    required this.resolved,
    this.billCount = 0,
    this.billTotal = 0,
  });

  factory MachineServiceLog.fromJson(Map<String, dynamic> j) => MachineServiceLog(
    id:          j['_id']?.toString()          ?? '',
    date:        (DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now()).toLocal(),
    type:        j['type']?.toString()         ?? 'Other',
    description: j['description']?.toString()  ?? '',
    technician:  j['technician']?.toString()   ?? '',
    cost:        (j['cost'] as num?)?.toDouble() ?? 0,
    nextServiceDate: DateTime.tryParse(j['nextServiceDate']?.toString() ?? '')?.toLocal(),
    resolved:    j['resolved'] as bool? ?? true,
    billCount:   (j['billCount'] as num?)?.toInt() ?? 0,
    billTotal:   (j['billTotal'] as num?)?.toDouble() ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════
//  SERVICE BILLS CONTROLLER
//
//  Scoped to one service log. Bills are their own collection, so the
//  list is a separate read from the machine — and a machine detail that
//  failed to load its bills is still worth showing.
// ══════════════════════════════════════════════════════════════

class ServiceBillsController extends GetxController {
  final String machineId;
  final String serviceLogId;
  ServiceBillsController({required this.machineId, required this.serviceLogId});

  final bills       = <ServiceBill>[].obs;
  final totalAmount = 0.0.obs;
  final isLoading   = true.obs;
  final isBusy      = false.obs;
  final errorMsg    = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await MachineApiService.listBills(
        machineId: machineId, serviceLogId: serviceLogId,
      );
      bills.value = res.bills;
      totalAmount.value = res.totalAmount;
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load bills';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Returns null on success, or a message to show.
  Future<String?> upload({
    required String kind,
    required Uint8List bytes,
    required String filename,
    double amount = 0,
    String vendor = '',
    String billNo = '',
    DateTime? billDate,
    String partName = '',
    String notes = '',
  }) async {
    if (bytes.length > kBillMaxBytes) {
      return 'That file is ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB — '
          'the limit is ${kBillMaxBytes ~/ (1024 * 1024)} MB';
    }
    isBusy.value = true;
    try {
      await MachineApiService.uploadBill(
        machineId: machineId,
        serviceLogId: serviceLogId,
        kind: kind,
        bytes: bytes,
        filename: filename,
        amount: amount,
        vendor: vendor,
        billNo: billNo,
        billDate: billDate,
        partName: partName,
        notes: notes,
      );
      await fetch();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String? ?? 'Could not upload the bill';
    } catch (e) {
      return e.toString();
    } finally {
      isBusy.value = false;
    }
  }

  Future<String?> remove(String billId) async {
    isBusy.value = true;
    try {
      await MachineApiService.deleteBill(billId);
      await fetch();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String? ?? 'Could not delete the bill';
    } catch (e) {
      return e.toString();
    } finally {
      isBusy.value = false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ADD SERVICE LOG CONTROLLER
// ══════════════════════════════════════════════════════════════

class AddServiceLogController extends GetxController {
  // The Mongo _id of the machine (not the display ID like "LOOM-EL-01")
  final String machineMongoId;
  final VoidCallback? onSuccess;

  AddServiceLogController({required this.machineMongoId, this.onSuccess});

  static const List<String> kTypes = [
    'Preventive', 'Corrective', 'Breakdown', 'Inspection', 'Other',
  ];

  final selectedType   = 'Preventive'.obs;
  final resolvedFlag   = true.obs;
  final isSaving       = false.obs;

  /// Pull the machine off the floor as part of the same save. Recording
  /// the job and taking the machine out of service are one action, not
  /// two — otherwise a machine can be left running against a log that
  /// says it is stripped down.
  final sendToMaintenance = false.obs;

  /// The server's refusal when the machine is mid-job, kept so the form
  /// can explain itself instead of only flashing a snackbar that is gone
  /// by the time the operator looks up.
  final blockedReason = Rxn<String>();

  final descCtrl       = TextEditingController();
  final techCtrl       = TextEditingController();
  final costCtrl       = TextEditingController();
  final nextDateCtrl   = TextEditingController();
  DateTime? _nextDate;

  void setNextDate(DateTime d) {
    _nextDate          = d;
    final fmt          = DateFormat('dd MMM yyyy');
    nextDateCtrl.text  = fmt.format(d);
  }

  void clearNextDate() {
    _nextDate         = null;
    nextDateCtrl.text = '';
  }

  @override
  void onClose() {
    descCtrl.dispose();
    techCtrl.dispose();
    costCtrl.dispose();
    nextDateCtrl.dispose();
    super.onClose();
  }

  Future<void> save() async {
    if (descCtrl.text.trim().isEmpty) {
      _snack('Validation', 'Description is required', isError: true);
      return;
    }
    isSaving.value = true;
    blockedReason.value = null;
    try {
      final res = await MachineApiService.addServiceLog(
        machineId:       machineMongoId,
        type:            selectedType.value,
        description:     descCtrl.text.trim(),
        technician:      techCtrl.text.trim(),
        cost:            double.tryParse(costCtrl.text.trim()) ?? 0,
        nextServiceDate: _nextDate,
        resolved:        resolvedFlag.value,
        setMaintenance:  sendToMaintenance.value,
      );
      _snack(
        'Service Log Added',
        res['statusChanged'] == true
            ? 'Log saved and the machine is now in maintenance'
            : 'Log saved successfully',
        isError: false,
      );
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? 'Failed to save log';
      // 409 is the one refusal the operator can act on: the machine is
      // running a job and has to be stopped first. Nothing was saved, so
      // the reason stays on the form rather than vanishing with the toast.
      if (e.response?.statusCode == 409) blockedReason.value = msg;
      _snack('Save Failed', msg, isError: true);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      isSaving.value = false;
    }
  }
}

// ── Shared snackbar helper ────────────────────────────────────
void _snack(String title, String message, {required bool isError}) {
  Get.snackbar(
    title, message,
    backgroundColor:  isError
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A),
    colorText:        Colors.white,
    snackPosition:    SnackPosition.BOTTOM,
    duration:         const Duration(seconds: 4),
    icon: Icon(
      isError ? Icons.error_outline : Icons.check_circle_outline,
      color: Colors.white,
    ),
  );
}