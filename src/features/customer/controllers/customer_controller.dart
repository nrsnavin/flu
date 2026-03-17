import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';


// ──────────────────────────────────────────────────────────────
//  Shared base URL
// ──────────────────────────────────────────────────────────────
const _kBase = "http://13.233.117.153:2701/api/v2/customer";

// ══════════════════════════════════════════════════════════════
//  CustomerController — Add customer
// ══════════════════════════════════════════════════════════════
class CustomerController extends GetxController {
  final VoidCallback? onSuccess;
  CustomerController({this.onSuccess});
  // Basic
  final nameCtrl        = TextEditingController();
  final emailCtrl       = TextEditingController();
  final gstinCtrl       = TextEditingController();
  final contactNameCtrl = TextEditingController();
  final phoneCtrl       = TextEditingController();

  // Purchase
  final purchaseNameCtrl   = TextEditingController();
  final purchaseMobileCtrl = TextEditingController();
  final purchaseEmailCtrl  = TextEditingController();

  // Accounts


  final accountNameCtrl   = TextEditingController();
  final accountMobileCtrl = TextEditingController();
  final accountEmailCtrl  = TextEditingController();

  // Merchandiser
  final merchantNameCtrl   = TextEditingController();
  final merchantMobileCtrl = TextEditingController();
  final merchantEmailCtrl  = TextEditingController();

  final status       = "Active".obs;
  final paymentTerms = "30".obs;
  final loading      = false.obs;

  final _dio = Dio(BaseOptions(
    baseUrl: _kBase,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<void> submitCustomer() async {
    try {
      loading.value = true;

      final payload = {
        "name":         nameCtrl.text.trim(),
        "email":        emailCtrl.text.trim(),
        "gstin":        gstinCtrl.text.trim(),
        "status":       status.value,
        "contactName":  contactNameCtrl.text.trim(),
        "phoneNumber":  phoneCtrl.text.trim(),
        "paymentTerms": paymentTerms.value,
        "purchase": {
          "name":   purchaseNameCtrl.text.trim(),
          "mobile": purchaseMobileCtrl.text.trim(),
          "email":  purchaseEmailCtrl.text.trim(),
        },
        "accountant": {
          "name":   accountNameCtrl.text.trim(),
          "mobile": accountMobileCtrl.text.trim(),
          "email":  accountEmailCtrl.text.trim(),
        },
        "merchandiser": {
          "name":   merchantNameCtrl.text.trim(),
          "mobile": merchantMobileCtrl.text.trim(),
          "email":  merchantEmailCtrl.text.trim(),
        },
      };

      final response = await _dio.post("/create", data: payload);

      if (response.statusCode == 201) {
        Get.snackbar(
          "Success", "Customer created successfully",
          backgroundColor: const Color(0xFF16A34A),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM,
        );
        // Pop back to caller (list page)
        onSuccess?.call();

      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to create customer";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [
      nameCtrl, emailCtrl, gstinCtrl, contactNameCtrl, phoneCtrl,
      purchaseNameCtrl, purchaseMobileCtrl, purchaseEmailCtrl,
      accountNameCtrl, accountMobileCtrl, accountEmailCtrl,
      merchantNameCtrl, merchantMobileCtrl, merchantEmailCtrl,
    ]) {
      c.dispose();
    }
    super.onClose();
  }
}

// ══════════════════════════════════════════════════════════════
//  CustomerListController — paginated list + search
// ══════════════════════════════════════════════════════════════
class CustomerListController extends GetxController {
  final customers      = <Map<String, dynamic>>[].obs;
  final loading        = false.obs;
  final isMoreLoading  = false.obs;
  final searchText     = "".obs;

  int  _page    = 1;
  bool _hasMore = true;
  static const _limit = 20;
  Timer? _debounce;

  final _dio = Dio(BaseOptions(
    baseUrl: _kBase,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  void onInit() {
    super.onInit();
    fetchCustomers(reset: true);
  }

  void onSearchChanged(String value) {
    searchText.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      fetchCustomers(reset: true);
    });
  }

  Future<void> fetchCustomers({bool reset = false}) async {
    if (loading.value || isMoreLoading.value) return;

    if (reset) {
      _page    = 1;
      _hasMore = true;
      customers.clear();
    }

    if (!_hasMore) return;

    try {
      _page == 1
          ? loading.value = true
          : isMoreLoading.value = true;

      final res = await _dio.get(
        "/all-customers",
        queryParameters: {
          "page":   _page,
          "limit":  _limit,
          "search": searchText.value,
        },
      );

      final List list = res.data['customers'] ?? [];
      if (list.length < _limit) _hasMore = false;

      customers.addAll(List<Map<String, dynamic>>.from(list));
      _page++;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to load customers";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value       = false;
      isMoreLoading.value = false;
    }
  }

  bool get hasMore => _hasMore;

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}

// ══════════════════════════════════════════════════════════════
//  CustomerDetailController
// ══════════════════════════════════════════════════════════════
class CustomerDetailController extends GetxController {
  final String customerId;
  CustomerDetailController({required this.customerId});

  final loading  = false.obs;
  // FIX: expose as plain Map via a getter so EditPage receives correct type
  final _customer = <String, dynamic>{}.obs;

  Map<String, dynamic> get customerData => _customer;

  final _dio = Dio(BaseOptions(baseUrl: _kBase));

  @override
  void onInit() {
    super.onInit();
    fetchCustomer();
  }

  Future<void> fetchCustomer() async {
    try {
      loading.value = true;
      final res = await _dio.get("/customerDetail?id=$customerId");
      _customer.value = Map<String, dynamic>.from(res.data['customer']);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to load customer";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  /// Soft-delete: sets status=Inactive via PUT /update
  Future<bool> deactivateCustomer() async {
    try {
      final updated = Map<String, dynamic>.from(_customer);
      updated['status'] = 'Inactive';
      await _dio.put("/update", data: updated);
      _customer['status'] = 'Inactive';
      // ignore: invalid_use_of_protected_member
      _customer.refresh();
      return true;
    } catch (_) {
      Get.snackbar("Error", "Failed to deactivate customer",
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  RxMap<String, dynamic> get rxCustomer => _customer;
}

// ══════════════════════════════════════════════════════════════
//  EditCustomerController
// ══════════════════════════════════════════════════════════════
class EditCustomerController extends GetxController {
  // FIX: accept plain Map<String, dynamic> not Map
  final Map<String, dynamic> customer;
  final VoidCallback? onSuccess;
  EditCustomerController({required this.customer, this.onSuccess});

  final formKey = GlobalKey<FormState>();
  final loading = false.obs;

  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController gstinCtrl;
  late TextEditingController contactNameCtrl;
  late TextEditingController phoneCtrl;

  final status       = "Active".obs;
  final paymentTerms = "30".obs;

  final _dio = Dio(BaseOptions(baseUrl: _kBase));

  @override
  void onInit() {
    super.onInit();
    nameCtrl        = TextEditingController(text: customer['name']        ?? "");
    emailCtrl       = TextEditingController(text: customer['email']       ?? "");
    gstinCtrl       = TextEditingController(text: customer['gstin']       ?? "");
    contactNameCtrl = TextEditingController(text: customer['contactName'] ?? "");
    phoneCtrl       = TextEditingController(text: customer['phoneNumber'] ?? "");
    status.value       = customer['status']       ?? "Active";
    paymentTerms.value = customer['paymentTerms'] ?? "30";
  }

  Future<void> updateCustomer() async {
    if (!formKey.currentState!.validate()) return;
    try {
      loading.value = true;

      final payload = {
        "_id":          customer['_id'],
        "name":         nameCtrl.text.trim(),
        "email":        emailCtrl.text.trim(),
        "gstin":        gstinCtrl.text.trim(),
        "contactName":  contactNameCtrl.text.trim(),
        "phoneNumber":  phoneCtrl.text.trim(),
        "status":       status.value,
        "paymentTerms": paymentTerms.value,
      };

      await _dio.put("/update", data: payload);

      Get.snackbar(
        "Updated", "Customer updated successfully",
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      // Pop back to caller (detail page)
      onSuccess?.call();

      // FIX: return result=true so detail page can refresh

    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to update customer";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [
      nameCtrl, emailCtrl, gstinCtrl, contactNameCtrl, phoneCtrl
    ]) {
      c.dispose();
    }
    super.onClose();
  }
}