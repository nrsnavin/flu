import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════════════════
//  ASSIGN MACHINE PAGE
//
//  Shown when a job is in "weaving" status but has no machine assigned yet.
//  This happens automatically after both Warping and Covering are completed
//  (the backend auto-advances the job from "preparatory" → "weaving").
//
//  FLOW:
//    1. Fetch free machines  GET /job/free-machines
//    2. User picks a machine → heads are shown as rows
//    3. Each head gets an elastic assigned from the job's planned elastics
//    4. Submit → POST /job/assign-machine
//    5. On success: Get.back(result: true) → job detail refreshes
//
//  ENTRY POINT (from job detail page):
//    Get.to(
//      () => AssignMachinePage(),
//      arguments: {
//        "jobId":    job.id,
//        "jobNo":    job.jobOrderNo,
//        "elastics": [ { "elasticId": "...", "elasticName": "..." }, ... ],
//      },
//    );
// ══════════════════════════════════════════════════════════════════════════

// ── Colour palette (mirrors rest of ERP app) ──────────────────
class _C {
  static const navyDark     = Color(0xFF0A1628);
  static const navyMid      = Color(0xFF0F2040);
  static const accentBlue   = Color(0xFF1E6FD9);
  static const successGreen = Color(0xFF16A34A);
  static const warningAmber = Color(0xFFD97706);
  static const errorRed     = Color(0xFFDC2626);
  static const bgBase       = Color(0xFFF4F6FA);
  static const bgSurface    = Color(0xFFFFFFFF);
  static const bgMuted      = Color(0xFFF8F9FB);
  static const borderLight  = Color(0xFFE2E8F0);
  static const borderMid    = Color(0xFFCBD5E1);
  static const textPrimary  = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted    = Color(0xFF94A3B8);
}

// ── Data models ────────────────────────────────────────────────
class _FreeMachine {
  final String id;
  final String machineID;
  final String manufacturer;
  final int    noOfHead;

  _FreeMachine({
    required this.id,
    required this.machineID,
    required this.manufacturer,
    required this.noOfHead,
  });

  factory _FreeMachine.fromJson(Map<String, dynamic> j) => _FreeMachine(
    id:           j['id']?.toString()           ?? '',
    machineID:    j['machineID']?.toString()    ?? '-',
    manufacturer: j['manufacturer']?.toString() ?? '',
    noOfHead:     (j['noOfHead'] as num?)?.toInt() ?? 0,
  );
}

class _ElasticOption {
  final String id;
  final String name;
  const _ElasticOption({required this.id, required this.name});
}

// ── Controller ─────────────────────────────────────────────────
class _AssignMachineController extends GetxController {
  final String jobId;
  final int    jobNo;
  final List<_ElasticOption> elasticOptions;

  _AssignMachineController({
    required this.jobId,
    required this.jobNo,
    required this.elasticOptions,
  });

  final _dio = Dio(BaseOptions(
    baseUrl:        'http://13.233.117.153:2701/api/v2',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // State
  final machines       = <_FreeMachine>[].obs;
  final selectedMachine = Rxn<_FreeMachine>();
  final headAssignments = <int, RxnString>{}.obs; // headNo (1-based) → elasticId
  final isLoadingMachines = true.obs;
  final isSubmitting       = false.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchMachines();
  }

  // ── Fetch free machines ───────────────────────────────────────
  Future<void> _fetchMachines() async {
    try {
      isLoadingMachines.value = true;
      final res = await _dio.get('/job/free-machines');
      final list = (res.data['machines'] as List<dynamic>? ?? [])
          .map((m) => _FreeMachine.fromJson(m as Map<String, dynamic>))
          .toList();
      machines.assignAll(list);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to load machines';
      Get.snackbar('Error', msg,
          backgroundColor:  _C.errorRed,
          colorText:         Colors.white,
          snackPosition:     SnackPosition.BOTTOM);
    } finally {
      isLoadingMachines.value = false;
    }
  }

  // ── Pick a machine ────────────────────────────────────────────
  void selectMachine(_FreeMachine m) {
    selectedMachine.value = m;
    // Reset head assignments to match the new machine's head count
    final newMap = <int, RxnString>{};
    for (int h = 1; h <= m.noOfHead; h++) {
      newMap[h] = RxnString();
    }
    headAssignments.value = newMap;
    headAssignments.refresh();
  }

  // ── Assign elastic to a head ──────────────────────────────────
  void assignHead(int headNo, String elasticId) {
    headAssignments[headNo]?.value = elasticId;
    headAssignments.refresh();
  }

  // ── Validation ────────────────────────────────────────────────
  String? _validate() {
    if (selectedMachine.value == null) return 'Please select a machine';
    final unassigned = headAssignments.entries
        .where((e) => e.value.value == null || e.value.value!.isEmpty)
        .length;
    if (unassigned > 0) return '$unassigned head(s) still need an elastic assigned';
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> submit() async {
    final err = _validate();
    if (err != null) {
      Get.snackbar('Validation', err,
          backgroundColor: _C.warningAmber,
          colorText:        Colors.white,
          snackPosition:    SnackPosition.BOTTOM);
      return;
    }

    final elasticsPayload = headAssignments.entries.map((e) => {
      'head':    e.key,
      'elastic': e.value.value,
    }).toList();

    bool success = false;
    try {
      isSubmitting.value = true;
      await _dio.post('/job/assign-machine', data: {
        'jobId':     jobId,
        'machineId': selectedMachine.value!.id,
        'elastics':  elasticsPayload,
      });
      success = true;
      Get.snackbar(
        'Machine Assigned',
        '${selectedMachine.value!.machineID} assigned to Job #$jobNo',
        backgroundColor: _C.successGreen,
        colorText:        Colors.white,
        snackPosition:    SnackPosition.BOTTOM,
        duration:         const Duration(seconds: 2),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Assignment failed';
      Get.snackbar('Error', msg,
          backgroundColor: _C.errorRed,
          colorText:        Colors.white,
          snackPosition:    SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
      if (success) Get.back(result: true);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAGE
// ═══════════════════════════════════════════════════════════════
class AssignMachinePage extends StatelessWidget {
  const AssignMachinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final args       = Get.arguments as Map<String, dynamic>;
    final jobId      = args['jobId']  as String;
    final jobNo      = args['jobNo']  as int;
    final rawElastics = args['elastics'] as List<dynamic>;

    final elasticOptions = rawElastics.map((e) {
      final m = e as Map<String, dynamic>;
      return _ElasticOption(
        id:   m['elasticId']?.toString()   ?? '',
        name: m['elasticName']?.toString() ?? '—',
      );
    }).where((e) => e.id.isNotEmpty).toList();

    Get.delete<_AssignMachineController>(force: true);
    final c = Get.put(_AssignMachineController(
      jobId:          jobId,
      jobNo:          jobNo,
      elasticOptions: elasticOptions,
    ));

    return Scaffold(
      backgroundColor: _C.bgBase,
      appBar: _buildAppBar(jobNo),
      body: Obx(() {
        if (c.isLoadingMachines.value) {
          return const Center(
              child: CircularProgressIndicator(color: _C.accentBlue));
        }
        if (c.machines.isEmpty) {
          return _NoMachinesView(onRetry: c._fetchMachines);
        }
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    // ── Readiness banner ─────────────────────────
                    _ReadinessBanner(),
                    const SizedBox(height: 14),

                    // ── Machine picker ───────────────────────────
                    _SectionLabel(
                        icon: Icons.precision_manufacturing_outlined,
                        text: 'SELECT MACHINE'),
                    const SizedBox(height: 8),
                    _MachineList(c: c),
                    const SizedBox(height: 16),

                    // ── Head assignments ─────────────────────────
                    Obx(() {
                      if (c.selectedMachine.value == null) {
                        return const SizedBox();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                              icon: Icons.cable_outlined,
                              text: 'ASSIGN ELASTICS TO HEADS'),
                          const SizedBox(height: 8),
                          _HeadAssignmentCard(
                              c: c,
                              elasticOptions: elasticOptions),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _SubmitFooter(c: c),
          ],
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(int jobNo) {
    return AppBar(
      backgroundColor: _C.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Assign Machine',
              style: ErpTextStyles.pageTitle),
          Text('Job #$jobNo  ›  Machine Assignment',
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}


// ── Readiness banner ────────────────────────────────────────────
class _ReadinessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color:        _C.successGreen.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.successGreen.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        _C.successGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.task_alt_rounded,
              color: _C.successGreen, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ready for Weaving',
                  style: TextStyle(
                      color:      _C.successGreen,
                      fontWeight: FontWeight.w800,
                      fontSize:   13)),
              SizedBox(height: 2),
              Text('Both warping and covering are complete. '
                  'Assign a machine to begin weaving.',
                  style: TextStyle(
                      color:    _C.textSecondary,
                      fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }
}


// ── Section label ───────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 14,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color:        _C.accentBlue,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Icon(icon, size: 14, color: _C.accentBlue),
      const SizedBox(width: 6),
      Text(text,
          style: const TextStyle(
              fontSize:     11,
              fontWeight:   FontWeight.w800,
              letterSpacing: 0.6,
              color:        _C.accentBlue)),
    ]);
  }
}


// ── Machine list ────────────────────────────────────────────────
class _MachineList extends StatelessWidget {
  final _AssignMachineController c;
  const _MachineList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
      children: c.machines.map((m) {
        final isSelected =
            c.selectedMachine.value?.id == m.id;

        return GestureDetector(
          onTap: () => c.selectMachine(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _C.accentBlue.withOpacity(0.07)
                  : _C.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? _C.accentBlue
                    : _C.borderLight,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              // Machine icon
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _C.accentBlue.withOpacity(0.12)
                      : _C.bgMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.precision_manufacturing_outlined,
                  size:  20,
                  color: isSelected ? _C.accentBlue : _C.textMuted,
                ),
              ),
              const SizedBox(width: 12),

              // Machine info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.machineID,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize:   14,
                            color: isSelected
                                ? _C.accentBlue
                                : _C.textPrimary)),
                    if (m.manufacturer.isNotEmpty)
                      Text(m.manufacturer,
                          style: const TextStyle(
                              color:    _C.textMuted,
                              fontSize: 11)),
                  ],
                ),
              ),

              // Head count chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _C.accentBlue
                      : _C.bgMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? _C.accentBlue
                        : _C.borderMid,
                  ),
                ),
                child: Text(
                  '${m.noOfHead} heads',
                  style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : _C.textSecondary,
                      fontSize:   11,
                      fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(width: 10),
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected ? _C.accentBlue : _C.textMuted,
                size: 20,
              ),
            ]),
          ),
        );
      }).toList(),
    ));
  }
}


// ── Head assignment card ────────────────────────────────────────
class _HeadAssignmentCard extends StatelessWidget {
  final _AssignMachineController c;
  final List<_ElasticOption> elasticOptions;
  const _HeadAssignmentCard({
    required this.c,
    required this.elasticOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final machine = c.selectedMachine.value!;
      return Container(
        decoration: BoxDecoration(
          color:        _C.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.borderLight),
        ),
        child: Column(
          children: [
            // Card header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: const BoxDecoration(
                color: _C.navyDark,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(children: [
                const Icon(Icons.view_list_outlined,
                    size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${machine.machineID}  ·  ${machine.noOfHead} Heads',
                    style: const TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize:   13),
                  ),
                ),
                // Completion badge
                Obx(() {
                  final assigned = c.headAssignments.values
                      .where((rx) =>
                  rx.value != null && rx.value!.isNotEmpty)
                      .length;
                  final total = c.headAssignments.length;
                  final done  = assigned == total && total > 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: done
                          ? _C.successGreen
                          : _C.warningAmber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$assigned / $total',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   11,
                          fontWeight: FontWeight.w800),
                    ),
                  );
                }),
              ]),
            ),

            // Head rows
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: List.generate(machine.noOfHead, (i) {
                  final headNo = i + 1;
                  return _HeadRow(
                    headNo:         headNo,
                    c:              c,
                    elasticOptions: elasticOptions,
                  );
                }),
              ),
            ),
          ],
        ),
      );
    });
  }
}


// ── Single head row ─────────────────────────────────────────────
class _HeadRow extends StatelessWidget {
  final int    headNo;
  final _AssignMachineController c;
  final List<_ElasticOption> elasticOptions;
  const _HeadRow({
    required this.headNo,
    required this.c,
    required this.elasticOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedId   = c.headAssignments[headNo]?.value;
      final isAssigned   = selectedId != null && selectedId.isNotEmpty;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isAssigned
              ? _C.accentBlue.withOpacity(0.04)
              : _C.bgMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAssigned ? _C.accentBlue.withOpacity(0.35) : _C.borderLight,
          ),
        ),
        child: Row(children: [
          // Head badge
          Container(
            width: 30, height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isAssigned
                  ? _C.accentBlue
                  : _C.bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isAssigned ? _C.accentBlue : _C.borderMid,
              ),
            ),
            child: Text(
              '$headNo',
              style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w800,
                  color: isAssigned ? Colors.white : _C.textMuted),
            ),
          ),
          const SizedBox(width: 10),

          // Elastic dropdown
          Expanded(
            child: _ElasticDropdown(
              headNo:         headNo,
              selectedId:     selectedId,
              elasticOptions: elasticOptions,
              onChanged:      (id) => c.assignHead(headNo, id),
            ),
          ),

          // Tick icon when assigned
          if (isAssigned) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle,
                color: _C.successGreen, size: 18),
          ],
        ]),
      );
    });
  }
}


// ── Elastic dropdown ────────────────────────────────────────────
class _ElasticDropdown extends StatelessWidget {
  final int    headNo;
  final String? selectedId;
  final List<_ElasticOption> elasticOptions;
  final void Function(String) onChanged;

  const _ElasticDropdown({
    required this.headNo,
    required this.selectedId,
    required this.elasticOptions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _C.bgSurface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: _C.borderMid),
        ),
        child: Row(children: [
          Expanded(
            child: selectedId != null && selectedId!.isNotEmpty
                ? Text(
                elasticOptions
                    .firstWhereOrNull((e) => e.id == selectedId)
                    ?.name ?? selectedId!,
                style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      _C.textPrimary),
                overflow: TextOverflow.ellipsis)
                : Text(
                'Select elastic for head $headNo',
                style: const TextStyle(
                    color:    _C.textMuted,
                    fontSize: 12)),
          ),
          const Icon(Icons.arrow_drop_down,
              color: _C.textMuted, size: 20),
        ]),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final result = await Get.bottomSheet<_ElasticOption>(
      _ElasticPickerSheet(options: elasticOptions, headNo: headNo),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    if (result != null) onChanged(result.id);
  }
}


// ── Elastic picker bottom sheet ─────────────────────────────────
class _ElasticPickerSheet extends StatefulWidget {
  final List<_ElasticOption> options;
  final int headNo;
  const _ElasticPickerSheet(
      {required this.options, required this.headNo});

  @override
  State<_ElasticPickerSheet> createState() =>
      _ElasticPickerSheetState();
}

class _ElasticPickerSheetState extends State<_ElasticPickerSheet> {
  late List<_ElasticOption> _filtered;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.options);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? List.from(widget.options)
          : widget.options
          .where((e) => e.name.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color:        _C.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        _C.borderMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: _C.borderLight)),
            ),
            child: Row(children: [
              Container(
                width: 3, height: 14,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _C.accentBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text('Select Elastic — Head ${widget.headNo}',
                    style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      _C.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close,
                    color: _C.textMuted, size: 20),
                padding:     EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _ctrl,
                onChanged:  _onSearch,
                style:      const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search elastics…',
                  hintStyle: const TextStyle(
                      color: _C.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: _C.textMuted),
                  filled:     true,
                  fillColor:  _C.bgMuted,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _C.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _C.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: _C.accentBlue, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(children: [
              Text(
                '${_filtered.length} elastic${_filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color:      _C.textMuted,
                    fontSize:   11,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 32, color: _C.textMuted),
                  SizedBox(height: 8),
                  Text('No elastics found',
                      style: TextStyle(
                          color:    _C.textSecondary,
                          fontSize: 14)),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount:        _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final opt = _filtered[i];
                return GestureDetector(
                  onTap: () => Get.back(result: opt),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: _C.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _C.borderLight),
                    ),
                    child: Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: _C.accentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.layers_outlined,
                            size: 18, color: _C.accentBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opt.name,
                            style: const TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w600,
                                color:      _C.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: _C.textMuted),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ── No machines empty state ─────────────────────────────────────
class _NoMachinesView extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoMachinesView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _C.warningAmber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.precision_manufacturing_outlined,
                  size: 34, color: _C.warningAmber),
            ),
            const SizedBox(height: 16),
            const Text('No Free Machines',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize:   18,
                    color:      _C.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'All machines are currently running. '
                  'A machine must be free before it can be assigned.',
              style: TextStyle(
                  color:    _C.textSecondary,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                side:  const BorderSide(color: _C.accentBlue),
                foregroundColor: _C.accentBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Submit footer ───────────────────────────────────────────────
class _SubmitFooter extends StatelessWidget {
  final _AssignMachineController c;
  const _SubmitFooter({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      decoration: BoxDecoration(
        color: _C.bgSurface,
        border: const Border(top: BorderSide(color: _C.borderLight)),
        boxShadow: [
          BoxShadow(
            color:      _C.navyDark.withOpacity(0.06),
            blurRadius: 8,
            offset:     const Offset(0, -3),
          ),
        ],
      ),
      child: Obx(() {
        final machine     = c.selectedMachine.value;
        final totalHeads  = c.headAssignments.length;
        final assignedCnt = c.headAssignments.values
            .where((rx) => rx.value != null && rx.value!.isNotEmpty)
            .length;
        final allAssigned = assignedCnt == totalHeads && totalHeads > 0;
        final canSubmit   = machine != null && allAssigned;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary pill
            if (machine != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (canSubmit ? _C.successGreen : _C.warningAmber)
                      .withOpacity(0.09),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (canSubmit ? _C.successGreen : _C.warningAmber)
                        .withOpacity(0.3),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    canSubmit
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined,
                    size:  16,
                    color: canSubmit ? _C.successGreen : _C.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canSubmit
                          ? '${machine.machineID} — all $totalHeads heads assigned'
                          : '$assignedCnt of $totalHeads heads assigned for ${machine.machineID}',
                      style: TextStyle(
                          color: canSubmit
                              ? _C.successGreen
                              : _C.warningAmber,
                          fontSize:   12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
            ],

            // Confirm button
            SizedBox(
              width:  double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (c.isSubmitting.value || !canSubmit)
                    ? null
                    : c.submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor:        _C.accentBlue,
                  disabledBackgroundColor: _C.accentBlue.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: c.isSubmitting.value
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.precision_manufacturing_outlined,
                    size: 18, color: Colors.white),
                label: Text(
                  c.isSubmitting.value ? 'Assigning…' : 'Confirm Machine Assignment',
                  style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   14),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════
//  ASSIGN MACHINE BUTTON WIDGET
//
//  Drop this into your job detail page. It shows the button only when:
//    • job.status == "weaving"
//    • job.machine == null   (no machine assigned yet)
//
//  Usage in job_detail.dart:
//
//    AssignMachineButton(
//      jobId:     job['id'],
//      jobNo:     job['jobOrderNo'],
//      elastics:  job['plannedElastics'],   // List of { elasticId, elasticName }
//      jobStatus: job['status'],
//      machine:   job['machine'],           // null when not yet assigned
//      onAssigned: () => controller.fetchJobDetail(),
//    )
// ══════════════════════════════════════════════════════════════════════════
class AssignMachineButton extends StatelessWidget {
  final String            jobId;
  final int               jobNo;
  final List<dynamic>     elastics;   // [{elasticId, elasticName}]
  final String            jobStatus;
  final Map<String, dynamic>? machine;
  final VoidCallback      onAssigned;

  const AssignMachineButton({
    super.key,
    required this.jobId,
    required this.jobNo,
    required this.elastics,
    required this.jobStatus,
    required this.machine,
    required this.onAssigned,
  });

  @override
  Widget build(BuildContext context) {
    // Only show when job is in weaving and has no machine
    final showButton = jobStatus == 'weaving' && machine == null;
    if (!showButton) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Waiting-for-machine notice
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color:        _C.warningAmber.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _C.warningAmber.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.pending_outlined,
                  size: 16, color: _C.warningAmber),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Warping & Covering complete. '
                      'Assign a machine to start weaving.',
                  style: TextStyle(
                      color:    _C.warningAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // Assign Machine button
          SizedBox(
            width:  double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Get.to(
                      () => const AssignMachinePage(),
                  arguments: {
                    'jobId':    jobId,
                    'jobNo':    jobNo,
                    'elastics': elastics,
                  },
                );
                if (result == true) onAssigned();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.accentBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 18, color: Colors.white),
              label: const Text(
                'Assign Machine',
                style: TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize:   14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}