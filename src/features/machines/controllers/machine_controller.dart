import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/machine.dart';


// ══════════════════════════════════════════════════════════════
//  MACHINE API SERVICE
// ══════════════════════════════════════════════════════════════

class MachineApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

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

  static Future<String> updateElastics({
    required String machineCode,
    required List elastics,
  }) async {
    final res = await _dio.put('/machine/updateOrder', data: {
      'id':      machineCode,
      'elastics': elastics,
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
  static Future<Map<String, dynamic>> addServiceLog({
    required String machineId,
    required String type,
    required String description,
    String? technician,
    double cost = 0,
    DateTime? nextServiceDate,
    bool resolved = true,
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
    });
    return res.data as Map<String, dynamic>;
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

  MachineServiceLog({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.technician,
    required this.cost,
    this.nextServiceDate,
    required this.resolved,
  });

  factory MachineServiceLog.fromJson(Map<String, dynamic> j) => MachineServiceLog(
    id:          j['_id']?.toString()          ?? '',
    date:        j['date'] != null
        ? DateTime.parse(j['date'] as String).toLocal()
        : DateTime.now(),
    type:        j['type']?.toString()         ?? 'Other',
    description: j['description']?.toString()  ?? '',
    technician:  j['technician']?.toString()   ?? '',
    cost:        (j['cost'] as num?)?.toDouble() ?? 0,
    nextServiceDate: j['nextServiceDate'] != null
        ? DateTime.parse(j['nextServiceDate'] as String).toLocal()
        : null,
    resolved:    j['resolved'] as bool? ?? true,
  );
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
    try {
      await MachineApiService.addServiceLog(
        machineId:       machineMongoId,
        type:            selectedType.value,
        description:     descCtrl.text.trim(),
        technician:      techCtrl.text.trim(),
        cost:            double.tryParse(costCtrl.text.trim()) ?? 0,
        nextServiceDate: _nextDate,
        resolved:        resolvedFlag.value,
      );
      _snack('Service Log Added', 'Log saved successfully', isError: false);
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? 'Failed to save log';
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