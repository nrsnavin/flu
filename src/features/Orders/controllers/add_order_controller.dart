import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:production/src/core/api_client.dart';
import 'package:production/src/common_widgets/reason_dialog.dart';
import 'package:production/src/features/Orders/models/elasticLite.dart';
import 'package:production/src/features/Orders/models/order_elastic_row.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';

/// Build the actor blob the backend expects so every fingerprint
/// can be attributed to the logged-in user.
Map<String, dynamic> buildActorPayload() {
  try {
    final u = LoginController.find.user.value;
    return {
      'id':   u.id,
      'name': u.name,
      'role': u.role,
    };
  } catch (_) {
    return {'id': 'unknown', 'name': 'Unknown', 'role': 'unknown'};
  }
}

class AddOrderController extends GetxController {
  final VoidCallback? onSuccess;

  /// When non-null, the form starts in edit mode and submitOrder()
  /// posts to /order/update-order instead of /create-order.
  final String? editingOrderId;

  /// Optional initial values for edit mode. Wired in by the page
  /// before the first build.
  final Map<String, dynamic>? initialOrder;

  AddOrderController({
    this.onSuccess,
    this.editingOrderId,
    this.initialOrder,
  });

  bool get isEditing => editingOrderId != null;

  // Document version the edit is based on (optimistic lock).
  int? _expectedVersion;

  Dio get _dio => ApiClient.instance.dio;

  // ── Dates ──────────────────────────────────────────────────
  final orderDate  = DateTime.now().obs;
  final supplyDate = DateTime.now().add(const Duration(days: 7)).obs;

  // ── Text controllers ───────────────────────────────────────
  final poCtrl   = TextEditingController();
  final descCtrl = TextEditingController();

  // ── Selected customer ──────────────────────────────────────
  final selectedCustomerId   = RxnString();
  final selectedCustomerName = RxnString();

  // ── Elastic rows ───────────────────────────────────────────
  final elasticRows = <OrderElasticRow>[].obs;

  // ── Submit state ───────────────────────────────────────────
  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (initialOrder != null) {
      _hydrateFromOrder(initialOrder!);
    } else {
      addElasticRow();
    }
  }

  /// Pre-fill controllers from an existing order's GET-response
  /// payload (the same `data` blob OrderDetailController.fetchOrderDetail
  /// stores). Called once during onInit when editingOrderId is set.
  void _hydrateFromOrder(Map<String, dynamic> o) {
    poCtrl.text   = (o['po']          ?? '').toString();
    descCtrl.text = (o['description'] ?? '').toString();
    // Capture the document version this edit is based on — sent back as
    // expectedVersion so the server can 409 a stale save.
    _expectedVersion = (o['__v'] as num?)?.toInt();

    final raw = o['date'];
    if (raw != null) {
      try { orderDate.value = DateTime.parse(raw.toString()); } catch (_) {}
    }
    final supply = o['supplyDate'];
    if (supply != null) {
      try { supplyDate.value = DateTime.parse(supply.toString()); } catch (_) {}
    }

    final cust = o['customer'];
    if (cust is Map) {
      selectedCustomerId.value   = cust['_id']?.toString();
      selectedCustomerName.value = cust['name']?.toString();
    }

    // GET /get-orderDetail returns `elastics` (id+name+ordered/produced/...)
    // — use those to pre-fill the rows. Fall back to elasticOrdered.
    final list = (o['elastics'] as List?) ?? (o['elasticOrdered'] as List?) ?? const [];
    elasticRows.clear();
    for (final raw in list) {
      if (raw is! Map) continue;
      final row = OrderElasticRow();
      final id = (raw['id'] ?? raw['elastic'])?.toString();
      final name = raw['name']?.toString();
      final qty = (raw['ordered'] ?? raw['quantity'] ?? 0).toString();
      row.elasticId.value           = id;
      row.selectedElasticName.value = name;
      row.qtyCtrl.text              = qty;
      elasticRows.add(row);
    }
    if (elasticRows.isEmpty) addElasticRow();
  }

  // ── Search customers ────────────────────────────────────────
  Future<List<CustomerLite>> searchCustomers(String query) async {
    try {
      final res = await _dio.get(
        '/customer/all-customers',
        queryParameters: query.trim().isEmpty
            ? <String, dynamic>{}
            : <String, dynamic>{'search': query.trim()},
      );
      final list = res.data['customers'] as List? ?? [];
      return list
          .map((c) => CustomerLite(id: c['_id'] as String, name: c['name'] as String))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to search customers';
      _snack('Search Error', msg, isError: true);
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Search elastics ─────────────────────────────────────────
  Future<List<ElasticLite>> searchElastics(String query) async {
    try {
      final res = await _dio.get(
        '/elastic/get-elastics',
        queryParameters: query.trim().isEmpty
            ? <String, dynamic>{}
            : <String, dynamic>{'search': query.trim()},
      );
      final list = res.data['elastics'] as List? ?? [];
      return list
          .map((e) => ElasticLite(id: e['_id'] as String, name: e['name'] as String))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to search elastics';
      _snack('Search Error', msg, isError: true);
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Elastic row management ─────────────────────────────────
  void addElasticRow() => elasticRows.add(OrderElasticRow());

  void removeElasticRow(int index) {
    elasticRows[index].dispose();
    elasticRows.removeAt(index);
  }

  // Backend stores Number — accept decimals so the form survives
  // round-trips for orders created with fractional quantities.
  static double _parseQty(String s) =>
      double.tryParse(s.trim()) ?? 0;

  // ── Validation ─────────────────────────────────────────────
  String? validate() {
    if (poCtrl.text.trim().isEmpty) return 'PO Number is required';
    if (selectedCustomerId.value == null) return 'Please select a customer';
    final validRows = elasticRows
        .where((r) =>
            r.elasticId.value != null &&
            _parseQty(r.qtyCtrl.text) > 0)
        .toList();
    if (validRows.isEmpty) {
      return 'Add at least one elastic with a valid quantity';
    }
    return null;
  }

  /// The calendar day of [d] as it reads here, "yyyy-MM-dd". A date
  /// loaded from the server is UTC midnight of its day; made local it
  /// is 05:30 on that same day, so the day is right either way.
  static String _day(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  // ── Build payload ──────────────────────────────────────────
  //
  // The two dates go as the day alone ("2026-11-18"), as the web sends
  // them. They went as this phone's clock with no zone, which the
  // server (on UTC) read five and a half hours on: an order taken after
  // 18:30 was dated the next day and promised a day late.
  Map<String, dynamic> _buildPayload() => {
    'date':        _day(orderDate.value),
    'po':          poCtrl.text.trim(),
    'customer':    selectedCustomerId.value,
    'supplyDate':  _day(supplyDate.value),
    'description': descCtrl.text.trim(),
    'elasticOrdered': elasticRows
        .where((r) =>
            r.elasticId.value != null &&
            _parseQty(r.qtyCtrl.text) > 0)
        .map((r) => {
              'elastic':  r.elasticId.value,
              'quantity': _parseQty(r.qtyCtrl.text),
            })
        .toList(),
    // 🪪 Attach logged-in user so the backend records who created it
    'actor': buildActorPayload(),
  };

  // ── Submit ─────────────────────────────────────────────────
  //
  // `creditOverride`: an admin's reason for releasing this one order
  // for a customer on credit hold (set when the first attempt came
  // back CREDIT_HOLD and the admin gave one).
  Future<void> submitOrder({String? creditOverride}) async {
    final err = validate();
    if (err != null) {
      _snack('Validation', err, isError: true, amber: true);
      return;
    }

    bool success = false;
    // Editing an order writes an audit fingerprint — capture a reason first.
    String? editReason;
    if (isEditing) {
      editReason = await showReasonDialog(
        title: 'Reason for edit',
        message: 'Only Open orders can be edited. This is recorded in the audit log.',
        confirmLabel: 'Save changes',
      );
      if (editReason == null) return; // cancelled
    }
    String? holdMessage;   // set when the customer is on credit hold
    try {
      isSubmitting.value = true;
      if (isEditing) {
        await _dio.post('/order/update-order', data: {
          'orderId': editingOrderId,
          ..._buildPayload(),
          'auditReason': editReason,
          // Optimistic lock: server 409s if someone else saved since load.
          if (_expectedVersion != null) 'expectedVersion': _expectedVersion,
        });
        _snack(
          'Order Updated',
          'PO ${poCtrl.text} — ${DateFormat('dd MMM').format(orderDate.value)}',
          isError: false,
        );
      } else {
        final res = await _dio.post('/order/create-order', data: {
          ..._buildPayload(),
          if (creditOverride != null) 'creditOverride': creditOverride,
        });
        final body = res.data is Map ? res.data as Map : const {};
        if (body['duplicate'] == true) {
          // The same order had just been saved (a second tap, or a retry
          // on a bad line): the server answers with that one.
          _snack('Already saved',
              body['message']?.toString() ?? 'This order was already saved.',
              isError: false);
        } else {
          _snack(
            'Order Created',
            'PO ${poCtrl.text} — ${DateFormat('dd MMM').format(orderDate.value)}',
            isError: false,
          );
        }
      }
      success = true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map ? data['code']?.toString() : null;
      final serverSays = data is Map ? data['message']?.toString() : null;
      // Every 409 used to be reported as an edit conflict — including a
      // NEW order refused because the customer is on credit hold, which
      // read "someone else changed this order while you were editing".
      if (e.response?.statusCode == 409 && code == 'CREDIT_HOLD') {
        holdMessage = serverSays ?? 'This customer is on credit hold.';
      } else if (e.response?.statusCode == 409 &&
          (code == 'VERSION_CONFLICT' || (isEditing && code == null))) {
        _snack('Edit conflict',
            'Someone else changed this order while you were editing. Go back, reload it, and apply your change again.',
            isError: true);
      } else if (e.response?.statusCode == 409) {
        _snack('Not saved', serverSays ?? 'The order could not be saved just now. Try again.', isError: true);
      } else {
        final msg = e.response?.data?['message'] ??
            (isEditing ? 'Failed to update order' : 'Failed to create order');
        _snack('Error', msg, isError: true);
      }
    } finally {
      isSubmitting.value = false;
      if (success) onSuccess?.call();
    }
    if (holdMessage != null) await _creditHold(holdMessage);
  }

  /// The customer is on credit hold. An admin may release this one order
  /// with a reason, which the server records on it; anyone else is told
  /// why it was refused. (As raising an invoice already does.)
  Future<void> _creditHold(String message) async {
    bool admin = false;
    try {
      admin = LoginController.find.user.value.role.toLowerCase() == 'admin';
    } catch (_) {}
    if (!admin) {
      await Get.dialog<void>(AlertDialog(
        title: const Text('Customer on credit hold'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('OK'))],
      ));
      return;
    }
    final reason = await showReasonDialog(
      title: 'Customer on credit hold',
      message: '$message\n\nTo release this one order, say why. It is recorded on the order.',
      confirmLabel: 'Release and save',
      // services/creditControl.js takes a reason of 8 characters or more.
      minLength: 8,
    );
    if (reason == null) return;
    await submitOrder(creditOverride: reason);
  }

  @override
  void onClose() {
    poCtrl.dispose();
    descCtrl.dispose();
    for (final r in elasticRows) r.dispose();
    super.onClose();
  }
}

// ── Shared snackbar helper ─────────────────────────────────────
void _snack(
    String title,
    String message, {
      required bool isError,
      bool amber = false,
    }) {
  Get.snackbar(
    title, message,
    backgroundColor: amber
        ? ErpColors.warningAmber
        : isError
        ? ErpColors.errorRed
        : ErpColors.successGreen,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
    icon: Icon(
      isError ? Icons.error_outline : Icons.check_circle_outline,
      color: Colors.white,
    ),
  );
}
