import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../models/user.dart';
import '../screens/home.dart';
import 'storage_keys.dart';

class LoginController extends GetxController {
  static LoginController get find => Get.find();

  Rx<User>  user            = User(id: '', name: '', role: '').obs;
  RxBool    isLoading        = false.obs;
  RxBool    isLoggedIn       = false.obs;
  RxBool    isCheckingAuth   = true.obs;

  Dio get _dio => ApiClient.instance.dio;

  @override
  void onInit() {
    super.onInit();
    _handleAutoLogin();
  }

  // ── Auto-login on cold start ─────────────────────────────────────────────

  Future<void> _handleAutoLogin() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(StorageKeys.token) ?? '';
      if (storedToken.isEmpty) return;

      // The interceptor in ApiClient attaches the cookie automatically.
      final response = await _dio.get(
        '/user/getuser',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final u = response.data['user'];
        user.value = User(
          id:   u['_id']?.toString()       ?? prefs.getString(StorageKeys.id)   ?? '',
          name: (u['name'] ?? u['username'])?.toString()
                                            ?? prefs.getString(StorageKeys.name) ?? '',
          role: u['role']?.toString()       ?? prefs.getString(StorageKeys.role) ?? '',
        );
        isLoggedIn.value = true;
      } else {
        await _clearSession(prefs);
      }
    } catch (_) {
      // Network unavailable — restore from cache so the user isn't locked
      // out when the factory has no connectivity.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(StorageKeys.isLoggedIn) == true &&
          (prefs.getString(StorageKeys.token) ?? '').isNotEmpty) {
        user.value = User(
          id:   prefs.getString(StorageKeys.id)   ?? '',
          name: prefs.getString(StorageKeys.name) ?? '',
          role: prefs.getString(StorageKeys.role) ?? '',
        );
        isLoggedIn.value = true;
      }
    } finally {
      isCheckingAuth.value = false;
    }
  }

  // ── Manual login ──────────────────────────────────────────────────────

  void tryLogin(String email, String password) async {
    isLoading.value = true;
    try {
      final response = await _dio.post(
        '/user/login-user',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 201) {
        final newToken = response.data['token'] ?? '';
        final u = User(
          id:   response.data['id']       ?? '',
          name: response.data['username'] ?? '',
          role: response.data['role']     ?? '',
        );
        await _saveSession(token: newToken, user: u);
        user.value       = u;
        isLoggedIn.value = true;
        Get.offAll(() => Home());
      } else {
        Get.snackbar('Login Failed', 'Unexpected server response.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      String msg = 'Login failed. Please check your credentials.';
      try {
        final dynamic err = e;
        final serverMsg  = err.response?.data?['message'];
        if (serverMsg != null) msg = serverMsg.toString();
      } catch (_) {}
      Get.snackbar('Login Failed', msg, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    user.value       = User(id: '', name: '', role: '');
    isLoggedIn.value = false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> _saveSession({required String token, required User user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.token, token);
    await prefs.setString(StorageKeys.id,    user.id);
    await prefs.setString(StorageKeys.name,  user.name);
    await prefs.setString(StorageKeys.role,  user.role);
    await prefs.setBool(StorageKeys.isLoggedIn, true);
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.id);
    await prefs.remove(StorageKeys.name);
    await prefs.remove(StorageKeys.role);
    await prefs.setBool(StorageKeys.isLoggedIn, false);
  }
}
