import 'package:flutter/material.dart';
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
      departments.value =
          List<String>.from((res.data['departments'] as List? ?? [])
              .map((e) => e.toString()));
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
          backgroundColor: const Color(0xFF16A34A),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      await fetch();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to delete user';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  UserFormController — create (POST) or edit (PUT). Password is
//  required on create, optional on edit (blank = unchanged).
// ══════════════════════════════════════════════════════════════
class UserFormController extends GetxController {
  final Map<String, dynamic>? existing;
  final VoidCallback? onSuccess;
  UserFormController({this.existing, this.onSuccess});

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
      deptCtrl.text  = e['department'] as String? ?? '';
      final dept = deptCtrl.text.trim();
      final allowed = featuresForDepartment(dept).toSet();
      final raw = e['features'];
      if (raw is List && raw.isNotEmpty) {
        // Keep only keys the role can reach — features are a role-scoped subset.
        features.assignAll(raw.map((x) => x.toString()).where(allowed.contains));
      } else {
        features.assignAll(featuresForDepartment(dept));
      }
    } else {
      deptCtrl.text = 'weaving';
      features.assignAll(featuresForDepartment('weaving'));
    }
  }

  // Picking a department re-scopes AND re-seeds the checklist to its default.
  void setDepartment(String dept) {
    deptCtrl.text = dept;
    features.assignAll(featuresForDepartment(dept));
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
      final allowed = featuresForDepartment(deptCtrl.text.trim()).toSet();
      final scoped = features.where(allowed.contains).toList();
      if (isEdit) {
        final payload = <String, dynamic>{
          'name': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
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
          backgroundColor: const Color(0xFF16A34A),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      onSuccess?.call();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to save user';
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
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
