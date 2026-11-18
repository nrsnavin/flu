import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../../core/features.dart';

// ══════════════════════════════════════════════════════════════
//  UsersController — admin user management.
//  Mirrors the web Administration › Users. GET /user/manage/list,
//  POST /user/manage/create, PUT/DELETE /user/manage/:id.
// ══════════════════════════════════════════════════════════════
class UsersController extends GetxController {
  final users       = <Map<String, dynamic>>[].obs;
  final departments = <String>[].obs;

  /// The server's own feature catalogue, sent with the list. The form
  /// offers these — not this build's copy, which can be behind.
  List<FeatureDef> catalog = kFeatures;
  final loading     = false.obs;
  final errorMsg    = Rxn<String>();

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/user',
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
      final res = await _dio.get('/manage/list');
      users.value =
          List<Map<String, dynamic>>.from(res.data['users'] as List? ?? []);
      departments.value = departmentsFrom(res.data['departments']);
      catalog = catalogFrom(res.data['features']);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load users';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/manage/$id');
      Get.snackbar('Removed', 'User deleted',
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      await fetch();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to delete user';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.solidError,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

/// The shortest password the server takes (prod/utils/passwordPolicy.js).
const kMinPasswordLength = 8;

// ══════════════════════════════════════════════════════════════
//  UserFormController — create (POST) or edit (PUT). Password is
//  required on create, optional on edit (blank = unchanged).
// ══════════════════════════════════════════════════════════════
class UserFormController extends GetxController {
  final Map<String, dynamic>? existing;
  final VoidCallback? onSuccess;

  /// What can be granted and to which departments: the server's answer
  /// when the Users list has it, this build's copy otherwise.
  final List<FeatureDef> catalog;
  final List<String> departments;

  UserFormController({
    this.existing,
    this.onSuccess,
    this.catalog = kFeatures,
    this.departments = kDepartments,
  });

  final formKey = GlobalKey<FormState>();
  final nameCtrl     = TextEditingController();
  final emailCtrl    = TextEditingController();
  final passwordCtrl = TextEditingController();
  final deptCtrl     = TextEditingController();
  final loading = false.obs;

  // Custom per-user feature keys (nav paths).
  final features = <String>[].obs;

  bool get isEdit => existing != null;

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/user',
  );

  @override
  void onInit() {
    super.onInit();
    final e = existing;
    if (e != null) {
      nameCtrl.text  = e['name'] as String? ?? '';
      emailCtrl.text = e['email'] as String? ?? '';
    }
    // The department it is edited under, and the boxes ticked: both
    // worked out in core/features.dart, where they are checked
    // (features_check.dart). A login with no department opens under the
    // one its role names, never as Production with every box unticked.
    deptCtrl.text = departmentOf(e, departments);
    features.assignAll(featuresOnOpen(e, catalog: catalog, departments: departments));
  }

  /// What this department may be given.
  List<String> get scope => featuresForDepartment(deptCtrl.text.trim(), catalog);

  /// A worker's login signs in by phone and PIN and has no email (the
  /// server keeps a placeholder and sends none).
  bool get signsInByPhone =>
      existing?['phoneSignIn'] == true && ((existing?['email'] as String?) ?? '').isEmpty;

  /// A worker's own login: nothing beyond the always-on screens, by design.
  bool get isEmployeeLogin => existing?['selfService'] == true;

  /// Nothing ticked beyond the screens every login has: this login would
  /// open nothing else. Legitimate, but a decision — so it is asked.
  bool get grantsNothing {
    final always = alwaysOnKeys(catalog).toSet();
    final allowed = scope.toSet();
    return features.where(allowed.contains).every(always.contains);
  }

  // Picking a department re-scopes AND re-seeds the checklist to its default.
  void setDepartment(String dept) {
    deptCtrl.text = dept;
    features.assignAll(featuresForDepartment(dept, catalog));
  }

  void toggleFeature(String key) {
    if (features.contains(key)) {
      features.remove(key);
    } else {
      features.add(key);
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    try {
      loading.value = true;
      final pwd = passwordCtrl.text.trim();
      // Never send features outside the role's scope.
      final allowed = scope.toSet();
      final scoped = features.where(allowed.contains).toList();
      if (isEdit) {
        final email = emailCtrl.text.trim();
        final payload = <String, dynamic>{
          'name': nameCtrl.text.trim(),
          if (email.isNotEmpty) 'email': email,
          'department': deptCtrl.text.trim(),
          'features': scoped,
          if (pwd.isNotEmpty) 'password': pwd,
        };
        await _dio.put('/manage/${existing!['_id']}', data: payload);
      } else {
        await _dio.post('/manage/create', data: {
          'name': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'password': pwd,
          'department': deptCtrl.text.trim(),
          'features': scoped,
        });
      }
      Get.snackbar('Saved', isEdit ? 'User updated' : 'User created',
          backgroundColor: ErpColors.solidSuccess,
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to save user';
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
    emailCtrl.dispose();
    passwordCtrl.dispose();
    deptCtrl.dispose();
    super.onClose();
  }
}
