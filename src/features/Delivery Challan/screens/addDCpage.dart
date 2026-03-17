import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../models/dc_model.dart';

// ════════════════════════════════════════════════════════════════
//  ADD DC CONTROLLER
// ════════════════════════════════════════════════════════════════
class AddDCController extends GetxController {
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://13.233.117.153:2701/api/v2',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

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

  Future<void> selectOrder(String orderId) async {
    try {
      loadingOrder.value = true;
      orderResults.clear();
      orderSearchCtrl.clear();
      selectedOrderId.value = orderId;

      final res = await _dio.get('/dc/order-info',
          queryParameters: {'id': orderId});
      final info = OrderInfoForDC.fromJson(res.data as Map<String, dynamic>);
      orderInfo.value = info;

      // Prefill customer
      nameCtrl.text    = info.customerName;
      phoneCtrl.text   = info.customerPhone;
      gstinCtrl.text   = info.customerGstin;
      addressCtrl.text = info.customerContact;

      // Clear any previous elastic selections
      for (final item in elasticItems.values) item.dispose();
      elasticItems.clear();
      selectedIds.clear();
    } on DioException catch (e) {
      Get.snackbar('Error', e.response?.data?['message'] ?? 'Failed to load order',
          backgroundColor: ErpColors.errorRed, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loadingOrder.value = false;
    }
  }

  void clearOrder() {
    selectedOrderId.value = null;
    orderInfo.value = null;
    for (final item in elasticItems.values) item.dispose();
    elasticItems.clear();
    selectedIds.clear();
    nameCtrl.clear(); phoneCtrl.clear();
    gstinCtrl.clear(); addressCtrl.clear();
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
          backgroundColor: ErpColors.warningAmber, colorText: Colors.white,
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

    try {
      loading.value = true;
      await _dio.post('/dc/create', data: payload);
      Get.snackbar('Created', 'Delivery Challan created successfully',
          backgroundColor: ErpColors.successGreen, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      onSuccess?.call();
    } on DioException catch (ex) {
      Get.snackbar('Error', ex.response?.data?['message'] ?? 'Failed to create DC',
          backgroundColor: ErpColors.errorRed, colorText: Colors.white,
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
        title: const Column(
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
        color: active ? color.withOpacity(0.07) : ErpColors.bgMuted,
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
        Text(sub, style: const TextStyle(fontSize: 9, color: ErpColors.textMuted)),
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
        if (c.orderInfo.value != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ErpColors.accentBlue.withOpacity(0.25)),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.receipt_outlined, size: 18, color: ErpColors.accentBlue),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${c.orderInfo.value!.orderNo}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: ErpColors.textPrimary)),
                  Text(c.orderInfo.value!.customerName,
                      style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
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
                  child: const Icon(Icons.close, size: 14, color: ErpColors.textMuted),
                ),
              ),
            ]),
          )
        else ...[
          // ── Search field ──────────────────────────────────
          TextField(
            controller: c.orderSearchCtrl,
            style: ErpTextStyles.fieldValue,
            onChanged: c.searchOrders,
            decoration: ErpDecorations.formInput(
              'Search order number or customer…',
              prefix: c.searchingOrders.value
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ErpColors.accentBlue))
                  : const Icon(Icons.search, size: 18, color: ErpColors.textMuted),
            ),
          ),

          // ── Results dropdown ──────────────────────────────
          if (c.orderResults.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: ErpColors.bgSurface,
                border: Border.all(color: ErpColors.borderLight),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
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
                      const Icon(Icons.receipt_long_outlined,
                          size: 15, color: ErpColors.accentBlue),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Order #$no', style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                        Text(cn, style: const TextStyle(
                            fontSize: 11, color: ErpColors.textSecondary)),
                      ]),
                    ]),
                  ),
                );
              }).toList()),
            ),
          ],
          if (c.loadingOrder.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator(
                  color: ErpColors.accentBlue, strokeWidth: 2)),
            ),
        ],
      ]),
    ));
  }
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
                color: sel ? ErpColors.accentBlue.withOpacity(0.04) : ErpColors.bgMuted,
                border: Border.all(color: sel
                    ? ErpColors.accentBlue.withOpacity(0.28) : ErpColors.borderLight),
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
                              style: const TextStyle(fontSize: 10, color: ErpColors.textMuted)),
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
                          prefix: const Icon(Icons.straighten, size: 16, color: ErpColors.textMuted),
                        ).copyWith(
                          errorText: qErr,
                          errorStyle: const TextStyle(fontSize: 10, color: ErpColors.errorRed),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: item.rateCtrl,
                        keyboardType: TextInputType.number,
                        style: ErpTextStyles.fieldValue,
                        onChanged: (_) => c.elasticItems.refresh(),
                        decoration: ErpDecorations.formInput('Rate/m (₹)',
                          prefix: const Icon(Icons.currency_rupee, size: 16, color: ErpColors.textMuted),
                        ),
                      )),
                    ]),
                  ),
              ]),
            );
          }),

          // ── Totals row ──────────────────────────────────────
          if (c.selectedIds.isNotEmpty) ...[
            const Divider(height: 1, color: ErpColors.borderLight),
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
                    color: const Color(0xFF7C3AED).withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('Part / Item',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: ErpColors.textPrimary))),
                if (c.machineItems.length > 1)
                  GestureDetector(
                    onTap: () => c.removeMachineItem(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ErpColors.errorRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.delete_outline, color: ErpColors.errorRed, size: 16),
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
                  prefix: const Icon(Icons.build_outlined, size: 16, color: ErpColors.textMuted),
                ).copyWith(
                  errorText: descErr,
                  errorStyle: const TextStyle(fontSize: 10, color: ErpColors.errorRed),
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
                    errorStyle: const TextStyle(fontSize: 10, color: ErpColors.errorRed),
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
                    prefix: const Icon(Icons.currency_rupee, size: 14, color: ErpColors.textMuted),
                  ),
                )),
              ]),

              if (item.qty > 0 && item.rate > 0) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('= ₹${_fmt(item.amount)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
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
                  colorScheme: const ColorScheme.dark(
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
        border: const Border(top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, -3))],
      ),
      child: Obx(() => Row(children: [
        Expanded(child: SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ErpColors.borderMid),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Cancel', style: TextStyle(
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
              disabledBackgroundColor: ErpColors.accentBlue.withOpacity(0.5),
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
  const _Card({required this.title, required this.icon, required this.child,
    this.accentColor = ErpColors.accentBlue, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: errorText != null
            ? ErpColors.errorRed.withOpacity(0.4) : ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
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
                const Icon(Icons.error_outline, size: 13, color: ErpColors.errorRed),
                const SizedBox(width: 4),
                Text(errorText!, style: const TextStyle(
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
      errorStyle: const TextStyle(color: ErpColors.errorRed, fontSize: 10),
      enabledBorder: errorText != null ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: ErpColors.errorRed.withOpacity(0.6)),
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
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.20)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}