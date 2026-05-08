import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../theme/erp_theme.dart';
import '../models/employee_user.dart';
import 'storage_keys.dart';

/// Owns the authenticated session for the employee app.
///
/// Lifecycle:
///   1. Cold start  → `_handleAutoLogin()` reads the JWT cookie out of
///                    SharedPreferences and calls /user/me to validate
///                    + refresh the linked employee fields.
///   2. Login form  → `tryLogin()` posts to /user/login-user, persists
///                    the cookie, then calls /user/me.
///   3. Logout      → clears prefs + Rx state.
///
/// AuthGate watches [isCheckingAuth] + [isLoggedIn] to pick between
/// the splash spinner, the login screen, and the home dashboard.
class LoginController extends GetxController {
  // Lazy registration so any caller (including widgets reached via a
  // deep link) can grab the controller without wiring it through
  // initialBinding.
  static LoginController get find => Get.isRegistered<LoginController>()
      ? Get.find<LoginController>()
      : Get.put(LoginController(), permanent: true);

  Dio get _dio => ApiClient.instance.dio;

  final user           = EmployeeUser.empty.obs;
  final isLoading      = false.obs;
  final isLoggedIn     = false.obs;
  final isCheckingAuth = true.obs;

  @override
  void onInit() {
    super.onInit();
    _handleAutoLogin();
  }

  // ── Auto-login on cold start ─────────────────────────────────
  Future<void> _handleAutoLogin() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(StorageKeys.token) ?? '';
      if (storedToken.isEmpty) return;

      // Try the canonical /me lookup. If the token is still valid the
      // server returns the user + linked employee; otherwise we fall
      // back to the cached fields so the dashboard can still render
      // until the user reconnects.
      try {
        final res = await _dio.get('/user/me');
        final u = EmployeeUser.fromMe(
            (res.data['user'] as Map).cast<String, dynamic>());
        await _persistSession(prefs, u, storedToken);
        user.value     = u;
        isLoggedIn.value = true;
      } on DioException {
        // Offline / expired — render from prefs so the user still sees
        // their dashboard. Re-authenticating fixes the JWT next online.
        if (prefs.getBool(StorageKeys.isLoggedIn) == true) {
          user.value = EmployeeUser(
            userId:       prefs.getString(StorageKeys.userId)     ?? '',
            name:         prefs.getString(StorageKeys.userName)   ?? '',
            email:        prefs.getString(StorageKeys.userEmail)  ?? '',
            role:         prefs.getString(StorageKeys.userRole)   ?? '',
            employeeId:   prefs.getString(StorageKeys.employeeId),
            department:   prefs.getString(StorageKeys.employeeDept),
            employeeRole: prefs.getString(StorageKeys.employeeRole),
            phoneNumber:  prefs.getString(StorageKeys.employeePhone),
            hourlyRate:   prefs.getDouble(StorageKeys.employeeRate),
          );
          isLoggedIn.value = true;
        }
      }
    } finally {
      isCheckingAuth.value = false;
    }
  }

  // ── Login ────────────────────────────────────────────────────
  Future<void> tryLogin(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      _snack('Validation', 'Email and password are required', error: true);
      return;
    }
    isLoading.value = true;
    try {
      final res = await _dio.post('/user/login-user', data: {
        'email':    email.trim(),
        'password': password,
      });
      final body = (res.data as Map).cast<String, dynamic>();
      final token = body['token']?.toString() ?? '';
      if (token.isEmpty) throw 'No token returned';

      // Persist the cookie immediately so the follow-up /me call
      // travels with credentials.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.token, token);

      // Bootstrap the linked employee.
      final me  = await _dio.get('/user/me');
      final u   = EmployeeUser.fromMe(
          (me.data['user'] as Map).cast<String, dynamic>());
      await _persistSession(prefs, u, token);

      user.value       = u;
      isLoggedIn.value = true;

      _snack('Welcome back', u.name.isNotEmpty ? u.name : u.email,
          error: false);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Login failed';
      _snack('Login failed', msg.toString(), error: true);
    } catch (e) {
      _snack('Login failed', e.toString(), error: true);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Logout ───────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.userId);
    await prefs.remove(StorageKeys.userName);
    await prefs.remove(StorageKeys.userEmail);
    await prefs.remove(StorageKeys.userRole);
    await prefs.remove(StorageKeys.employeeId);
    await prefs.remove(StorageKeys.employeeName);
    await prefs.remove(StorageKeys.employeeDept);
    await prefs.remove(StorageKeys.employeeRole);
    await prefs.remove(StorageKeys.employeePhone);
    await prefs.remove(StorageKeys.employeeRate);
    await prefs.setBool(StorageKeys.isLoggedIn, false);
    user.value       = EmployeeUser.empty;
    isLoggedIn.value = false;
  }

  Future<void> _persistSession(
      SharedPreferences prefs, EmployeeUser u, String token) async {
    await prefs.setString(StorageKeys.token, token);
    await prefs.setString(StorageKeys.userId,    u.userId);
    await prefs.setString(StorageKeys.userName,  u.name);
    await prefs.setString(StorageKeys.userEmail, u.email);
    await prefs.setString(StorageKeys.userRole,  u.role);
    if (u.employeeId   != null) await prefs.setString(StorageKeys.employeeId,   u.employeeId!);
    if (u.department   != null) await prefs.setString(StorageKeys.employeeDept, u.department!);
    if (u.employeeRole != null) await prefs.setString(StorageKeys.employeeRole, u.employeeRole!);
    if (u.phoneNumber  != null) await prefs.setString(StorageKeys.employeePhone, u.phoneNumber!);
    if (u.hourlyRate   != null) await prefs.setDouble(StorageKeys.employeeRate,  u.hourlyRate!);
    await prefs.setBool(StorageKeys.isLoggedIn, true);
  }

  void _snack(String title, String msg, {required bool error}) {
    Get.snackbar(
      title,
      msg,
      backgroundColor:
          error ? ErpColors.errorRed : ErpColors.successGreen,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
