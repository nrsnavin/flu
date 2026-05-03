import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:production/src/core/api_client.dart';
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
  AddOrderController({this.onSuccess});

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
    addElasticRow();
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

  // ── Validation ─────────────────────────────────────────────
  String? validate() {
    if (poCtrl.text.trim().isEmpty) return 'PO Number is required';
    if (selectedCustomerId.value == null) return 'Please select a customer';
    final validRows = elasticRows
        .where((r) =>
    r.elasticId.value != null &&
        (int.tryParse(r.qtyCtrl.text) ?? 0) > 0)
        .toList();
    if (validRows.isEmpty) {
      return 'Add at least one elastic with a valid quantity';
    }
    return null;
  }

  // ── Build payload ──────────────────────────────────────────
  Map<String, dynamic> _buildPayload() => {
    'date':        orderDate.value.toIso8601String(),
    'po':          poCtrl.text.trim(),
    'customer':    selectedCustomerId.value,
    'supplyDate':  supplyDate.value.toIso8601String(),
    'description': descCtrl.text.trim(),
    'elasticOrdered': elasticRows
        .where((r) =>
    r.elasticId.value != null &&
        (int.tryParse(r.qtyCtrl.text) ?? 0) > 0)
        .map((r) => {
      'elastic':  r.elasticId.value,
      'quantity': int.tryParse(r.qtyCtrl.text) ?? 0,
    })
        .toList(),
    // 🪪 Attach logged-in user so the backend records who created it
    'actor': buildActorPayload(),
  };

  // ── Submit ─────────────────────────────────────────────────
  Future<void> submitOrder() async {
    final err = validate();
    if (err != null) {
      _snack('Validation', err, isError: true, amber: true);
      return;
    }

    bool success = false;
    try {
      isSubmitting.value = true;
      await _dio.post('/order/create-order', data: _buildPayload());
      success = true;
      _snack(
        'Order Created',
        'PO \${poCtrl.text} — \${DateFormat('dd MMM').format(orderDate.value)}',
        isError: false,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to create order';
      _snack('Error', msg, isError: true);
    } finally {
      isSubmitting.value = false;
      if (success) onSuccess?.call();
    }
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
        ? const Color(0xFFD97706)
        : isError
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A),
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
    icon: Icon(
      isError ? Icons.error_outline : Icons.check_circle_outline,
      color: Colors.white,
    ),
  );
}
