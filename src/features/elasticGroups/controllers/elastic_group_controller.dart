import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  ElasticGroupListController
//  Named bundles of elastics (optionally tied to a customer). Mirrors
//  the web Masters › Elastic Groups. /api/v2/elastic-group.
// ══════════════════════════════════════════════════════════════
class ElasticGroupListController extends GetxController {
  final groups   = <Map<String, dynamic>>[].obs;
  final loading  = false.obs;
  final errorMsg = Rxn<String>();

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/elastic-group',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    try {
      loading.value = true;
      errorMsg.value = null;
      final res = await _dio.get('/');
      groups.value =
          List<Map<String, dynamic>>.from(res.data['groups'] as List? ?? []);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load elastic groups';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/$id');
      Get.snackbar('Removed', 'Elastic group deleted',
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      await fetch();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to delete';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  ElasticGroupFormController — create / edit a bundle: a name, an
//  optional customer, and a set of {elastic, defaultQuantity} items.
// ══════════════════════════════════════════════════════════════
class ElasticGroupFormController extends GetxController {
  final Map<String, dynamic>? existing;
  final VoidCallback? onSuccess;
  ElasticGroupFormController({this.existing, this.onSuccess});

  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();

  final customerId   = Rxn<String>(); // null = global bundle
  final customerName = Rxn<String>();
  // Each item: { 'elastic': <id>, 'name': <label>, 'defaultQuantity': num }
  final items   = <Map<String, dynamic>>[].obs;
  final loading = false.obs;

  final customers       = <Map<String, dynamic>>[].obs;
  final elasticResults  = <Map<String, dynamic>>[].obs;
  final elasticSearching = false.obs;

  final _groupDio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/elastic-group',
  );
  final _customerDio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/customer',
  );
  final _elasticDio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/elastic',
  );

  bool get isEdit => existing != null;

  @override
  void onInit() {
    super.onInit();
    final e = existing;
    if (e != null) {
      nameCtrl.text = e['name'] as String? ?? '';
      final cust = e['customer'];
      if (cust is Map) {
        customerId.value = cust['_id'] as String?;
        customerName.value = cust['name'] as String?;
      }
      final rawItems = e['items'] as List? ?? [];
      items.value = rawItems.map<Map<String, dynamic>>((it) {
        final m = Map<String, dynamic>.from(it as Map);
        final el = m['elastic'];
        final id = el is Map ? el['_id'] as String? : el as String?;
        final name = el is Map ? el['name'] as String? : null;
        return {
          'elastic': id,
          'name': name ?? 'Elastic',
          'defaultQuantity': (m['defaultQuantity'] as num?) ?? 0,
        };
      }).toList();
    }
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    try {
      final res = await _customerDio.get('/all-customers',
          queryParameters: {'page': 1, 'limit': 200, 'search': ''});
      customers.value =
          List<Map<String, dynamic>>.from(res.data['customers'] as List? ?? []);
    } catch (_) {/* non-fatal — customer picker just stays empty */}
  }

  Future<void> searchElastics(String q) async {
    try {
      elasticSearching.value = true;
      final res = await _elasticDio.get('/get-elastics',
          queryParameters: {'search': q, 'page': 1, 'limit': 30});
      elasticResults.value =
          List<Map<String, dynamic>>.from(res.data['elastics'] as List? ?? []);
    } catch (_) {
      elasticResults.clear();
    } finally {
      elasticSearching.value = false;
    }
  }

  void setCustomer(String? id, String? name) {
    customerId.value = id;
    customerName.value = name;
  }

  void addElastic(Map<String, dynamic> elastic) {
    final id = elastic['_id'] as String?;
    if (id == null) return;
    if (items.any((it) => it['elastic'] == id)) return; // no duplicates
    items.add({
      'elastic': id,
      'name': elastic['name'] as String? ?? 'Elastic',
      'defaultQuantity': 0,
    });
  }

  void removeItem(int index) => items.removeAt(index);

  void setQuantity(int index, num qty) {
    final it = Map<String, dynamic>.from(items[index]);
    it['defaultQuantity'] = qty;
    items[index] = it;
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (items.isEmpty) {
      Get.snackbar('Validation', 'Add at least one elastic',
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      loading.value = true;
      final payload = <String, dynamic>{
        'name': nameCtrl.text.trim(),
        'customer': customerId.value,
        'items': items
            .map((it) => {
                  'elastic': it['elastic'],
                  'defaultQuantity': it['defaultQuantity'] ?? 0,
                })
            .toList(),
      };
      if (isEdit) {
        await _groupDio.put('/${existing!['_id']}', data: payload);
      } else {
        await _groupDio.post('/', data: payload);
      }
      Get.snackbar('Saved', isEdit ? 'Group updated' : 'Group created',
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to save group';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    super.onClose();
  }
}
