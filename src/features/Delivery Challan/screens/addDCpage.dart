import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/request_id.dart';
import '../../../core/scan.dart';
import '../../Orders/controllers/add_order_controller.dart' show buildActorPayload;
import '../../PurchaseOrder/services/theme.dart';
import '../models/dc_model.dart';
import '../../../core/app_config.dart';

// ════════════════════════════════════════════════════════════════
//  ADD DC CONTROLLER
// ════════════════════════════════════════════════════════════════
class AddDCController extends GetxController {
  // FIX: was constructing a bare Dio(BaseOptions(...)), which
  // skipped the cookie interceptor in ApiClient.buildClient and
  // produced 401 ("login to continue") on /order/list, /dc/order-info
  // and /dc/create against the gated backend. The factory below
  // attaches the JWT cookie on every request.
  final _dio = ApiClient.buildClient(
    baseUrl: ApiConfig.baseUrl,
    timeout: const Duration(seconds: 15),
  );

  // Idempotency key for the in-flight create (see submit()).
  String? _requestId;
  String? _requestSig;

  // ── Type ───────────────────────────────────────────────────
  final selectedType = 'elastic'.obs; // 'elastic' | 'machine_part'

  // ── Order search ───────────────────────────────────────────
  final orderSearchCtrl  = TextEditingController();
  final orderResults     = <Map<String, dynamic>>[].obs;
  final searchingOrders  = false.obs;
  final selectedOrderId  = Rx<String?>(null);
  final loadingOrder     = false.obs;
  final orderInfo        = Rx<OrderInfoForDC?>(null);

  // ── Customer ───────────────────────────────────────────────
  final nameCtrl    = TextEditingController();
  final phoneCtrl   = TextEditingController();
  final gstinCtrl   = TextEditingController();
  final addressCtrl = TextEditingController();

  // ── Elastic items (keyed by elasticId) ────────────────────
  final selectedIds   = <String>{}.obs;
  final elasticItems  = <String, EditableDCItem>{}.obs;

  // ── Machine-part items (free rows) ────────────────────────
  final machineItems  = <EditableDCItem>[].obs;

  // ── Dispatch ───────────────────────────────────────────────
  late final dispatchDateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final vehicleNoCtrl   = TextEditingController();
  final driverCtrl      = TextEditingController();
  final transporterCtrl = TextEditingController();
  final lrCtrl          = TextEditingController();
  final remarksCtrl     = TextEditingController();

  // ── Validation ─────────────────────────────────────────────
  final errors  = <String, String>{}.obs;
  final loading = false.obs;

  // ── Callback ───────────────────────────────────────────────
  VoidCallback? onSuccess;

  @override
  void onInit() {
    super.onInit();
    machineItems.add(EditableDCItem.machinePart());
  }

  // ─────────────────────────────────────────────────────────
  //  TYPE
  // ─────────────────────────────────────────────────────────
  void setType(String t) {
    selectedType.value = t;
    errors.clear();
  }

  // ─────────────────────────────────────────────────────────
  //  ORDER SEARCH
  // ─────────────────────────────────────────────────────────
  Future<void> searchOrders(String q) async {
    if (q.trim().isEmpty) { orderResults.clear(); return; }
    try {
      searchingOrders.value = true;
      // Search across Open + Approved orders
      final res = await _dio.get('/order/list',
          queryParameters: {'status': 'InProgress'});
      final all = (res.data['orders'] as List)
          .map((e) => e as Map<String, dynamic>)
          .where((o) {
        final no   = (o['orderNo'] ?? '').toString();
        final cust = (o['customer']?['name'] ?? '').toString().toLowerCase();
        return no.contains(q) || cust.contains(q.toLowerCase());
      })
          .take(8)
          .toList();
      orderResults.assignAll(all);
    } catch (_) {
    } finally {
      searchingOrders.value = false;
    }
  }

  /// Put a loaded order onto the form.
  ///
  /// Shared by the search box and the label scanner. Two copies of
  /// "fill the customer in and reset the lines" is how the two paths
  /// drift into producing different challans from the same order.
  void _applyOrder(String orderId, OrderInfoForDC info) {
    orderResults.clear();
    orderSearchCtrl.clear();
    selectedOrderId.value = orderId;
    orderInfo.value = info;
    scannedJob.value = null;

    // Prefill customer
    nameCtrl.text    = info.customerName;
    phoneCtrl.text   = info.customerPhone;
    gstinCtrl.text   = info.customerGstin;
    addressCtrl.text = info.customerContact;

    // Clear any previous elastic selections
    for (final item in elasticItems.values) item.dispose();
    elasticItems.clear();
    selectedIds.clear();
  }

  Future<void> selectOrder(String orderId) async {
    try {
      loadingOrder.value = true;
      // Dismissed on tap, not on arrival: the results list sits over
      // the spinner otherwise, and the tap looks like it did nothing.
      orderResults.clear();
      orderSearchCtrl.clear();
      final res = await _dio.get('/dc/order-info',
          queryParameters: {'id': orderId});
      _applyOrder(orderId,
          OrderInfoForDC.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      Get.snackbar('Error', e.response?.data?['message'] ?? 'Failed to load order',
          backgroundColor: ErpColors.solidError, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loadingOrder.value = false;
    }
  }

  void clearOrder() {
    selectedOrderId.value = null;
    orderInfo.value = null;
    scannedJob.value = null;
    for (final item in elasticItems.values) item.dispose();
    elasticItems.clear();
    selectedIds.clear();
    nameCtrl.clear(); phoneCtrl.clear();
    gstinCtrl.clear(); addressCtrl.clear();
  }

  // ─────────────────────────────────────────────────────────
  //  ORDER BY SCANNED JOB LABEL
  //
  //  Same destination as selectOrder(), reached from the label taped
  //  to the trolley instead of from the search box. The person
  //  raising the challan is standing at the goods; the order number
  //  is one hop away from what is in front of them.
  //
  //  ── The lines are preselected, and it SAYS so ────────────────
  //  A job's elastics are ticked and prefilled with what that job
  //  packed — the figure that describes what is actually on the
  //  trolley, as opposed to what the order asked for. Because that is
  //  a decision the form made rather than the person, the banner
  //  above names the job it came from and offers a way out. A form
  //  that fills itself in silently is a form whose numbers nobody
  //  checks.
  // ─────────────────────────────────────────────────────────

  /// The job label this order was reached from, when it was scanned.
  /// Null when the order was picked from the search box.
  final scannedJob = Rx<ScannedJobOrder?>(null);

  /// Resolve a scanned label and load its order.
  ///
  /// Returns null on success, or a sentence saying what went wrong —
  /// the caller owns the messaging because it has the BuildContext,
  /// and because a snackbar fired from a controller cannot be tested.
  Future<String?> loadOrderFromScan(ScannedJob scanned) async {
    if (scanned.isEmpty) return 'That code is not a job label.';
    try {
      loadingOrder.value = true;
      final res = await _dio.get('/dc/job-order', queryParameters: {
        if (scanned.id != null) 'jobId': scanned.id,
        if (scanned.id == null && scanned.jobNo != null)
          'jobNo': scanned.jobNo.toString(),
      });
      final hit = ScannedJobOrder.fromJson(res.data as Map<String, dynamic>);

      _applyOrder(hit.orderId, hit.order);
      scannedJob.value = hit;
      _preselectFromJob(hit);
      return null;
    } on DioException catch (e) {
      // The server's message is the useful one — it distinguishes "no
      // such job" from "its order was deleted" from "two jobs share
      // that number", and each sends the person somewhere different.
      return e.response?.data?['message']?.toString() ??
          'Could not reach the server to look that job up.';
    } finally {
      loadingOrder.value = false;
    }
  }

  /// Tick this job's elastics and prefill what it packed.
  ///
  /// Lines the job covers but the ORDER does not are skipped rather
  /// than invented: the challan's elastic picker is built from the
  /// order, and a row with no option behind it cannot be edited or
  /// removed by the person looking at it.
  void _preselectFromJob(ScannedJobOrder hit) {
    final byId = {for (final o in hit.order.elastics) o.elasticId: o};
    for (final line in hit.lines) {
      final opt = byId[line.elasticId];
      if (opt == null) continue;
      selectedIds.add(opt.elasticId);
      elasticItems[opt.elasticId] = EditableDCItem.elastic(
        elasticId:   opt.elasticId,
        elasticName: opt.elasticName,
        // What was packed, falling back to what the order asked for
        // when the job has not reached packing. A zero would look like
        // a typed figure; prefilledQty ignores it, leaving the field
        // empty for a person to fill — which is the honest state.
        prefilledQty: line.packedQty > 0 ? line.packedQty : opt.orderedQty,
      );
    }
    elasticItems.refresh();
    errors.remove('elastics');
  }

  /// Drop the scan's preselection but keep the order.
  void clearScanPreselect() {
    scannedJob.value = null;
    for (final item in elasticItems.values) item.dispose();
    elasticItems.clear();
    selectedIds.clear();
  }

  // ─────────────────────────────────────────────────────────
  //  ELASTIC TOGGLE
  // ─────────────────────────────────────────────────────────
  void toggleElastic(OrderElasticOption opt) {
    if (selectedIds.contains(opt.elasticId)) {
      selectedIds.remove(opt.elasticId);
      elasticItems[opt.elasticId]?.dispose();
      elasticItems.remove(opt.elasticId);
    } else {
      selectedIds.add(opt.elasticId);
      elasticItems[opt.elasticId] = EditableDCItem.elastic(
        elasticId:    opt.elasticId,
        elasticName:  opt.elasticName,
        prefilledQty: opt.orderedQty,
      );
      elasticItems.refresh();
    }
    errors.remove('elastics');
  }

  // ─────────────────────────────────────────────────────────
  //  MACHINE ITEMS
  // ─────────────────────────────────────────────────────────
  void addMachineItem()  => machineItems.add(EditableDCItem.machinePart());
  void removeMachineItem(int i) {
    machineItems[i].dispose();
    machineItems.removeAt(i);
  }

  // ─────────────────────────────────────────────────────────
  //  TOTALS
  // ─────────────────────────────────────────────────────────
  double get totalQty => selectedType.value == 'elastic'
      ? elasticItems.values.fold(0, (s, i) => s + i.qty)
      : machineItems.fold(0, (s, i) => s + i.qty);

  double get totalAmount => selectedType.value == 'elastic'
      ? elasticItems.values.fold(0, (s, i) => s + i.amount)
      : machineItems.fold(0, (s, i) => s + i.amount);

  // ─────────────────────────────────────────────────────────
  //  VALIDATION
  // ─────────────────────────────────────────────────────────
  bool _validate() {
    final e = <String, String>{};

    if (nameCtrl.text.trim().isEmpty) e['name'] = 'Customer name is required';

    if (selectedType.value == 'elastic') {
      if (selectedOrderId.value == null) e['order'] = 'Please select an order';
      if (selectedIds.isEmpty) e['elastics'] = 'Select at least one elastic';
      for (final id in selectedIds) {
        if ((elasticItems[id]?.qty ?? 0) <= 0) e['qty_$id'] = 'Enter quantity';
      }
    } else {
      if (machineItems.isEmpty) e['items'] = 'Add at least one item';
      for (var i = 0; i < machineItems.length; i++) {
        if (machineItems[i].descCtrl.text.trim().isEmpty) e['desc_$i'] = 'Required';
        if (machineItems[i].qty <= 0) e['qty_m$i'] = 'Enter quantity';
      }
    }

    errors.assignAll(e);
    return e.isEmpty;
  }

  void clearError(String k) => errors.remove(k);

  // ─────────────────────────────────────────────────────────
  //  SUBMIT
  // ─────────────────────────────────────────────────────────
  Future<void> submit() async {
    if (!_validate()) {
      Get.snackbar('Validation Failed', 'Please fix the errors below.',
          backgroundColor: ErpColors.solidWarning, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final items = selectedType.value == 'elastic'
        ? selectedIds.map((id) => elasticItems[id]!.toPayload()).toList()
        : machineItems.map((i) => i.toPayload()).toList();

    final payload = {
      'type':            selectedType.value,
      'customerName':    nameCtrl.text.trim(),
      'customerPhone':   phoneCtrl.text.trim(),
      'customerGstin':   gstinCtrl.text.trim(),
      'customerAddress': addressCtrl.text.trim(),
      'dispatchDate':    dispatchDateCtrl.text.trim(),
      'vehicleNo':       vehicleNoCtrl.text.trim(),
      'driverName':      driverCtrl.text.trim(),
      'transporter':     transporterCtrl.text.trim(),
      'lrNumber':        lrCtrl.text.trim(),
      'remarks':         remarksCtrl.text.trim(),
      'items':           items,
      if (selectedOrderId.value != null) 'orderId': selectedOrderId.value,
      if (orderInfo.value != null) 'orderNo': orderInfo.value!.orderNo,
    };

    // Idempotency key: stable across retries of the same payload (a
    // timeout may have landed server-side), rotated when values change
    // or after success — a resubmit can't cut a second challan.
    final sig = jsonEncode(payload);
    if (_requestId == null || sig != _requestSig) {
      _requestId = newRequestId();
      _requestSig = sig;
    }

    try {
      loading.value = true;
      // 🪪 Attach logged-in user so the DC_CREATED fingerprint
      //    can attribute the action to a real person.
      await _dio.post('/dc/create', data: {
        ...payload,
        'requestId': _requestId,
        'actor': buildActorPayload(),
      });
      _requestId = null; // next challan is a new business event
      Get.snackbar('Created', 'Delivery Challan created successfully',
          backgroundColor: ErpColors.solidSuccess, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      onSuccess?.call();
    } on DioException catch (ex) {
      Get.snackbar('Error', ex.response?.data?['message'] ?? 'Failed to create DC',
          backgroundColor: ErpColors.solidError, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    orderSearchCtrl.dispose(); nameCtrl.dispose(); phoneCtrl.dispose();
    gstinCtrl.dispose(); addressCtrl.dispose(); dispatchDateCtrl.dispose();
    vehicleNoCtrl.dispose(); driverCtrl.dispose(); transporterCtrl.dispose();
    lrCtrl.dispose(); remarksCtrl.dispose();
    for (final i in elasticItems.values) i.dispose();
    for (final i in machineItems) i.dispose();
    super.onClose();
  }
}

// ════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════
class AddDCPage extends StatefulWidget {
  const AddDCPage({super.key});
  @override
  State<AddDCPage> createState() => _AddDCPageState();
}

class _AddDCPageState extends State<AddDCPage> {
  late final AddDCController c;

  @override
  void initState() {
    super.initState();
    Get.delete<AddDCController>(force: true);
    c = Get.put(AddDCController());
    c.onSuccess = () => Navigator.of(context).pop();
  }

  @override
  void dispose() {
    Get.delete<AddDCController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Delivery Challan', style: ErpTextStyles.pageTitle),
            Text('Dispatch  ›  Create DC',
                style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFF1E3A5F))),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(children: [

              // ── 1. Type ──────────────────────────────────────
              _TypeCard(c: c),
              const SizedBox(height: 12),

              // ── 2. Order (elastic only) ──────────────────────
              Obx(() => c.selectedType.value == 'elastic'
                  ? Column(children: [
                _OrderCard(c: c, context: context),
                const SizedBox(height: 12),
                if (c.orderInfo.value != null) ...[
                  _ElasticPickerCard(c: c),
                  const SizedBox(height: 12),
                ],
              ])
                  : const SizedBox.shrink()),

              // ── 3. Machine-part items ────────────────────────
              Obx(() => c.selectedType.value == 'machine_part'
                  ? Column(children: [
                _MachineItemsCard(c: c),
                const SizedBox(height: 12),
              ])
                  : const SizedBox.shrink()),

              // ── 4. Customer ──────────────────────────────────
              _CustomerCard(c: c),
              const SizedBox(height: 12),

              // ── 5. Dispatch details ──────────────────────────
              _DispatchCard(c: c, context: context),
            ]),
          ),
        ),
        _Footer(c: c),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SECTION WIDGETS
// ════════════════════════════════════════════════════════════════

// ── 1. Type selector ─────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final AddDCController c;
  const _TypeCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => _Card(
      title: 'CHALLAN TYPE', icon: Icons.category_outlined,
      child: Row(children: [
        Expanded(child: _TypeTile(
          label: 'Elastic Delivery',
          sub: 'Prefix: E/FY/No',
          icon: Icons.layers_outlined,
          active: c.selectedType.value == 'elastic',
          color: ErpColors.accentBlue,
          onTap: () => c.setType('elastic'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _TypeTile(
          label: 'Machine Part',
          sub: 'Prefix: M/FY/No',
          icon: Icons.precision_manufacturing_outlined,
          active: c.selectedType.value == 'machine_part',
          color: const Color(0xFF7C3AED),
          onTap: () => c.setType('machine_part'),
        )),
      ]),
    ));
  }
}

class _TypeTile extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TypeTile({required this.label, required this.sub, required this.icon,
    required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.07) : ErpColors.bgMuted,
        border: Border.all(color: active ? color : ErpColors.borderLight, width: active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: active ? color : ErpColors.textMuted),
          const Spacer(),
          if (active) Icon(Icons.check_circle_rounded, size: 14, color: color),
        ]),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: active ? color : ErpColors.textSecondary)),
        Text(sub, style: TextStyle(fontSize: 9, color: ErpColors.textMuted)),
      ]),
    ),
  );
}

// ── 2. Order search ───────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final AddDCController c;
  final BuildContext context;
  const _OrderCard({required this.c, required this.context});

  @override
  Widget build(BuildContext context) {
    return Obx(() => _Card(
      title: 'LINK TO ORDER', icon: Icons.receipt_long_outlined,
      errorText: c.errors['order'],
      child: Column(children: [

        // ── Selected order badge ──────────────────────────────
        if (c.orderInfo.value != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ErpColors.accentBlue.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.receipt_outlined, size: 18, color: ErpColors.accentBlue),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${c.orderInfo.value!.orderNo}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: ErpColors.textPrimary)),
                  Text(c.orderInfo.value!.customerName,
                      style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
                ],
              )),
              GestureDetector(
                onTap: c.clearOrder,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ErpColors.bgMuted,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ErpColors.borderLight),
                  ),
                  child: Icon(Icons.close, size: 14, color: ErpColors.textMuted),
                ),
              ),
            ]),
          ),

          // ── Where these lines came from ─────────────────────
          if (c.scannedJob.value != null) ...[
            const SizedBox(height: 8),
            _ScannedJobBanner(c: c, hit: c.scannedJob.value!),
          ],

          // ── A challan against a closed order ────────────────
          //  Allowed on purpose — the goods still leave, there is
          //  just no promise left to settle. Said out loud because
          //  the usual reason for seeing this is that the wrong
          //  order got picked.
          if (c.orderInfo.value!.isClosed) ...[
            const SizedBox(height: 8),
            _Notice(
              icon: Icons.info_outline_rounded,
              colour: ErpColors.warningAmber,
              text: 'Order #${c.orderInfo.value!.orderNo} is '
                  '${c.orderInfo.value!.orderStatus.toLowerCase()}. The '
                  'despatch will still go through — it just will not '
                  'settle anything the order was owed.',
            ),
          ],
        ]
        else ...[
          // ── Search field, with the scanner beside it ──────
          //
          //  Beside, never instead of. Labels get wet and torn, mill
          //  light defeats autofocus, and phones run flat — a flow
          //  that only works with a working camera is a flow that
          //  stops the loading bay when the camera stops.
          Row(children: [
            Expanded(
              child: TextField(
                controller: c.orderSearchCtrl,
                style: ErpTextStyles.fieldValue,
                onChanged: c.searchOrders,
                decoration: ErpDecorations.formInput(
                  'Search order number or customer…',
                  prefix: c.searchingOrders.value
                      ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ErpColors.accentBlue))
                      : Icon(Icons.search, size: 18, color: ErpColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ScanOrderButton(c: c),
          ]),
          const SizedBox(height: 6),
          Text(
            'Or scan the QR on the job label — it finds the order the '
            'job belongs to.',
            style: TextStyle(fontSize: 10.5, color: ErpColors.textMuted),
          ),

          // ── Results dropdown ──────────────────────────────
          if (c.orderResults.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: ErpColors.bgSurface,
                border: Border.all(color: ErpColors.borderLight),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(children: c.orderResults.map((o) {
                final no = (o['orderNo'] ?? '—').toString();
                final cn = (o['customer']?['name'] ?? '—').toString();
                return InkWell(
                  onTap: () => c.selectOrder(o['_id'].toString()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 15, color: ErpColors.accentBlue),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Order #$no', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                        Text(cn, style: TextStyle(
                            fontSize: 11, color: ErpColors.textSecondary)),
                      ]),
                    ]),
                  ),
                );
              }).toList()),
            ),
          ],
          if (c.loadingOrder.value)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator(
                  color: ErpColors.accentBlue, strokeWidth: 2)),
            ),
        ],
      ]),
    ));
  }
}

// ── 2a. "Scan job label" ─────────────────────────────────────
//
//  The label carries a job; the challan wants an order. The hop is
//  the server's (GET /dc/job-order) so a failed second call can never
//  leave the phone holding an order id it cannot render.
//
//  Every outcome is reported. A label that reads perfectly and names
//  a job whose order was deleted looks, from behind the phone,
//  identical to a camera that did not focus — unless it is spelled
//  out, and the server's message is the one that distinguishes them.
class _ScanOrderButton extends StatelessWidget {
  final AddDCController c;
  const _ScanOrderButton({required this.c});

  Future<void> _run(BuildContext context) async {
    final scanned = await scanJobLabel(context);
    if (scanned == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final failure = await c.loadOrderFromScan(scanned);

    if (failure != null) {
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: ErpColors.solidWarning,
        behavior: SnackBarBehavior.floating,
        content: Text(failure),
      ));
      return;
    }

    final hit = c.scannedJob.value;
    messenger.showSnackBar(SnackBar(
      backgroundColor: ErpColors.solidSuccess,
      behavior: SnackBarBehavior.floating,
      content: Text(hit == null
          ? 'Order loaded'
          : 'Job #${hit.jobOrderNo ?? '—'} → Order '
              '#${hit.order.orderNo}, ${hit.order.customerName}'),
    ));
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: () => _run(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: ErpColors.accentBlue,
            side: BorderSide(color: ErpColors.accentBlue),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, size: 20),
        ),
      );
}

// ── 2b. What the scan filled in, and where it came from ──────
//
//  The form ticked lines and typed quantities that nobody typed. That
//  is only acceptable if it is visible and reversible, so this names
//  the job, says which figure it used, and offers a way out.
class _ScannedJobBanner extends StatelessWidget {
  final AddDCController c;
  final ScannedJobOrder hit;
  const _ScannedJobBanner({required this.c, required this.hit});

  @override
  Widget build(BuildContext context) {
    // Prefilled from packing only when packing has happened. Otherwise
    // the ordered quantity stands in, and saying which is which is the
    // difference between a figure to check and a figure to trust.
    final fromPacking = !hit.nothingPacked;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ErpColors.successGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ErpColors.successGreen.withValues(alpha: 0.28)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.qr_code_2_rounded, size: 18, color: ErpColors.successGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Scanned job #${hit.jobOrderNo ?? '—'}'
              '${hit.jobStatus.isEmpty ? '' : ' · ${hit.jobStatus}'}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: ErpColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              hit.lines.isEmpty
                  ? 'This job has no elastic lines of its own — nothing was '
                      'ticked. Choose from the order below.'
                  : fromPacking
                      ? '${hit.lines.length} line(s) ticked below, filled in '
                          'with what this job PACKED. Check them against the '
                          'trolley before saving.'
                      : 'This job has not been packed yet, so the lines below '
                          'are filled in with the ORDERED quantity. Correct '
                          'them to what is going out.',
              style: TextStyle(
                  fontSize: 10.5, height: 1.35, color: ErpColors.textSecondary),
            ),
            if (hit.lines.isNotEmpty) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: c.clearScanPreselect,
                child: Text(
                  'Clear these and pick by hand',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.accentBlue,
                    decoration: TextDecoration.underline,
                    decorationColor: ErpColors.accentBlue,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── A one-line notice, in a colour that means something ──────
class _Notice extends StatelessWidget {
  final IconData icon;
  final Color    colour;
  final String   text;
  const _Notice({required this.icon, required this.colour, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colour.withValues(alpha: 0.28)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 10.5, height: 1.35,
                    color: ErpColors.textSecondary)),
          ),
        ]),
      );
}

// ── 3a. Elastic picker ───────────────────────────────────────
class _ElasticPickerCard extends StatelessWidget {
  final AddDCController c;
  const _ElasticPickerCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = c.orderInfo.value!;
      return _Card(
        title: 'SELECT ELASTICS & QTY',
        icon: Icons.layers_outlined,
        errorText: c.errors['elastics'],
        child: Column(children: [
          ...info.elastics.map((opt) {
            final sel  = c.selectedIds.contains(opt.elasticId);
            final item = c.elasticItems[opt.elasticId];
            final qErr = c.errors['qty_${opt.elasticId}'];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: sel ? ErpColors.accentBlue.withValues(alpha: 0.04) : ErpColors.bgMuted,
                border: Border.all(color: sel
                    ? ErpColors.accentBlue.withValues(alpha: 0.28) : ErpColors.borderLight),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(children: [
                // ── Row header ──────────────────────────────
                InkWell(
                  onTap: () => c.toggleElastic(opt),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: sel ? ErpColors.accentBlue : Colors.transparent,
                          border: Border.all(
                              color: sel ? ErpColors.accentBlue : ErpColors.borderMid,
                              width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: sel
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.elasticName, style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: sel ? ErpColors.textPrimary : ErpColors.textSecondary)),
                          Text('${opt.weaveType}  •  Order qty: ${opt.orderedQty.toStringAsFixed(0)} m',
                              style: TextStyle(fontSize: 10, color: ErpColors.textMuted)),
                        ],
                      )),
                    ]),
                  ),
                ),
                // ── Qty + Rate inputs (when selected) ────────
                if (sel && item != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(children: [
                      Expanded(child: TextField(
                        controller: item.qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: ErpTextStyles.fieldValue,
                        onChanged: (_) {
                          c.clearError('qty_${opt.elasticId}');
                          c.elasticItems.refresh();
                        },
                        decoration: ErpDecorations.formInput('Qty (m) *',
                          prefix: Icon(Icons.straighten, size: 16, color: ErpColors.textMuted),
                        ).copyWith(
                          errorText: qErr,
                          errorStyle: TextStyle(fontSize: 10, color: ErpColors.errorRed),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: item.rateCtrl,
                        keyboardType: TextInputType.number,
                        style: ErpTextStyles.fieldValue,
                        onChanged: (_) => c.elasticItems.refresh(),
                        decoration: ErpDecorations.formInput('Rate/m (₹)',
                          prefix: Icon(Icons.currency_rupee, size: 16, color: ErpColors.textMuted),
                        ),
                      )),
                    ]),
                  ),
              ]),
            );
          }),

          // ── Totals row ──────────────────────────────────────
          if (c.selectedIds.isNotEmpty) ...[
            Divider(height: 1, color: ErpColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _TotalBadge('${c.totalQty.toStringAsFixed(0)} m',
                    icon: Icons.straighten, color: ErpColors.accentBlue),
                if (c.totalAmount > 0) ...[
                  const SizedBox(width: 8),
                  _TotalBadge('₹${_fmt(c.totalAmount)}',
                      icon: Icons.currency_rupee, color: ErpColors.successGreen),
                ],
              ]),
            ),
          ],
        ]),
      );
    });
  }
  String _fmt(double v) => NumberFormat('#,##0.##').format(v);
}

// ── 3b. Machine-part items ────────────────────────────────────
class _MachineItemsCard extends StatelessWidget {
  final AddDCController c;
  const _MachineItemsCard({required this.c});

  static const _units = ['pcs', 'set', 'kg', 'm', 'nos', 'hr'];

  @override
  Widget build(BuildContext context) {
    return Obx(() => _Card(
      title: 'ITEMS / PARTS',
      icon: Icons.precision_manufacturing_outlined,
      accentColor: const Color(0xFF7C3AED),
      errorText: c.errors['items'],
      child: Column(children: [
        ...List.generate(c.machineItems.length, (i) {
          final item   = c.machineItems[i];
          final descErr = c.errors['desc_$i'];
          final qtyErr  = c.errors['qty_m$i'];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              border: Border.all(color: ErpColors.borderLight),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Item header
              Row(children: [
                Container(
                  width: 22, height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Part / Item',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: ErpColors.textPrimary))),
                if (c.machineItems.length > 1)
                  GestureDetector(
                    onTap: () => c.removeMachineItem(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ErpColors.errorRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.delete_outline, color: ErpColors.errorRed, size: 16),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),

              // Description
              TextField(
                controller: item.descCtrl,
                style: ErpTextStyles.fieldValue,
                onChanged: (_) {
                  c.clearError('desc_$i');
                  c.machineItems.refresh();
                },
                decoration: ErpDecorations.formInput('Description / Part Name *',
                  prefix: Icon(Icons.build_outlined, size: 16, color: ErpColors.textMuted),
                ).copyWith(
                  errorText: descErr,
                  errorStyle: TextStyle(fontSize: 10, color: ErpColors.errorRed),
                ),
              ),
              const SizedBox(height: 8),

              // Qty + Unit + Rate
              Row(children: [
                Expanded(child: TextField(
                  controller: item.qtyCtrl,
                  keyboardType: TextInputType.number,
                  style: ErpTextStyles.fieldValue,
                  onChanged: (_) {
                    c.clearError('qty_m$i');
                    c.machineItems.refresh();
                  },
                  decoration: ErpDecorations.formInput('Qty *').copyWith(
                    errorText: qtyErr,
                    errorStyle: TextStyle(fontSize: 10, color: ErpColors.errorRed),
                  ),
                )),
                const SizedBox(width: 8),

                // Unit dropdown
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: ErpColors.bgMuted,
                    border: Border.all(color: ErpColors.borderLight),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: item.unit,
                      style: ErpTextStyles.fieldValue,
                      dropdownColor: ErpColors.bgSurface,
                      items: _units.map((u) => DropdownMenuItem(
                          value: u, child: Text(u))).toList(),
                      onChanged: (v) {
                        if (v != null) { item.unit = v; c.machineItems.refresh(); }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(child: TextField(
                  controller: item.rateCtrl,
                  keyboardType: TextInputType.number,
                  style: ErpTextStyles.fieldValue,
                  onChanged: (_) => c.machineItems.refresh(),
                  decoration: ErpDecorations.formInput('Rate (₹)',
                    prefix: Icon(Icons.currency_rupee, size: 14, color: ErpColors.textMuted),
                  ),
                )),
              ]),

              if (item.qty > 0 && item.rate > 0) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('= ₹${_fmt(item.amount)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: ErpColors.successGreen)),
                ),
              ],
            ]),
          );
        }),

        // Add item button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: c.addMachineItem,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7C3AED)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF7C3AED)),
            label: const Text('Add Item',
                style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
          ),
        ),

        if (c.totalAmount > 0) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _TotalBadge('₹${_fmt(c.totalAmount)}',
                icon: Icons.currency_rupee, color: ErpColors.successGreen),
          ),
        ],
      ]),
    ));
  }
  String _fmt(double v) => NumberFormat('#,##0.##').format(v);
}

// ── 4. Customer card ──────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final AddDCController c;
  const _CustomerCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => _Card(
      title: 'CUSTOMER DETAILS', icon: Icons.person_outline_rounded,
      child: Column(children: [
        _Field(label: 'Customer Name *', ctrl: c.nameCtrl,
            errorText: c.errors['name'], prefix: Icons.person_outline,
            onChanged: (_) => c.clearError('name')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(label: 'Phone', ctrl: c.phoneCtrl,
              keyboard: TextInputType.phone, prefix: Icons.phone_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _Field(label: 'GSTIN', ctrl: c.gstinCtrl,
              prefix: Icons.badge_outlined)),
        ]),
        const SizedBox(height: 10),
        _Field(label: 'Address / Contact', ctrl: c.addressCtrl,
            maxLines: 2, prefix: Icons.location_on_outlined),
      ]),
    ));
  }
}

// ── 5. Dispatch details ───────────────────────────────────────
class _DispatchCard extends StatelessWidget {
  final AddDCController c;
  final BuildContext context;
  const _DispatchCard({required this.c, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return _Card(
      title: 'DISPATCH DETAILS', icon: Icons.local_shipping_outlined,
      child: Column(children: [
        // Date picker
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2099),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: ErpColors.accentBlue,
                    surface: ErpColors.bgSurface,
                    onSurface: ErpColors.textPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              c.dispatchDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
            }
          },
          child: AbsorbPointer(child: _Field(
            label: 'Dispatch Date', ctrl: c.dispatchDateCtrl,
            prefix: Icons.calendar_today_outlined,
          )),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(label: 'Vehicle No', ctrl: c.vehicleNoCtrl,
              prefix: Icons.local_shipping_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _Field(label: 'Driver Name', ctrl: c.driverCtrl,
              prefix: Icons.person_outline)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(label: 'Transporter', ctrl: c.transporterCtrl,
              prefix: Icons.business_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _Field(label: 'LR Number', ctrl: c.lrCtrl,
              prefix: Icons.tag)),
        ]),
        const SizedBox(height: 10),
        _Field(label: 'Remarks', ctrl: c.remarksCtrl,
            maxLines: 2, prefix: Icons.notes_outlined),
      ]),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final AddDCController c;
  const _Footer({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border(top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, -3))],
      ),
      child: Obx(() => Row(children: [
        Expanded(child: SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: ErpColors.borderMid),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Cancel', style: TextStyle(
                color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: c.loading.value ? null : c.submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              disabledBackgroundColor: ErpColors.accentBlue.withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: c.loading.value
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.receipt_long_outlined, size: 16, color: Colors.white),
            label: Text(c.loading.value ? 'Creating…' : 'Create Challan',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        )),
      ])),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SHARED MINI WIDGETS
// ════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accentColor;
  final String? errorText;
  _Card({required this.title, required this.icon, required this.child,
    Color? accentColor, this.errorText}) : accentColor = accentColor ?? ErpColors.accentBlue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: errorText != null
            ? ErpColors.errorRed.withValues(alpha: 0.4) : ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Container(width: 3, height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: accentColor, borderRadius: BorderRadius.circular(2))),
            Icon(icon, size: 13, color: ErpColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: ErpTextStyles.sectionHeader)),
            if (errorText != null)
              Row(children: [
                Icon(Icons.error_outline, size: 13, color: ErpColors.errorRed),
                const SizedBox(width: 4),
                Text(errorText!, style: TextStyle(
                    fontSize: 10, color: ErpColors.errorRed)),
              ]),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? errorText;
  final TextInputType keyboard;
  final IconData? prefix;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  const _Field({required this.label, required this.ctrl,
    this.errorText, this.keyboard = TextInputType.text,
    this.prefix, this.onChanged, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    maxLines: maxLines,
    style: ErpTextStyles.fieldValue,
    onChanged: onChanged,
    decoration: ErpDecorations.formInput(label,
      prefix: prefix != null ? Icon(prefix, size: 18, color: ErpColors.textMuted) : null,
    ).copyWith(
      errorText: errorText,
      errorStyle: TextStyle(color: ErpColors.errorRed, fontSize: 10),
      enabledBorder: errorText != null ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: ErpColors.errorRed.withValues(alpha: 0.6)),
      ) : null,
    ),
  );
}

class _TotalBadge extends StatelessWidget {
  final String value;
  final IconData icon;
  final Color color;
  const _TotalBadge(this.value, {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}
