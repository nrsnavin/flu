import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../screens/home.dart';
import 'storage_keys.dart';

class LoginController extends GetxController {
  static LoginController get find => Get.find();

  Rx<User> user = User(id: '', name: '', role: '').obs;
  RxBool isLoading = false.obs;
  RxString token = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(StorageKeys.token) ?? '';
    if (savedToken.isEmpty) return;
    token.value = savedToken;
    user.value = User(
      id:   prefs.getString(StorageKeys.id)   ?? '',
      name: prefs.getString('username')        ?? '',
      role: prefs.getString(StorageKeys.role)  ?? '',
    );
    Get.offAll(() => Home());
  }

  void tryLogin(String email, String password) async {
    isLoading.value = true;
    try {
      final response = await Dio().post(
        'http://13.233.117.153:2701/api/v2/user/login-user',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 201) {
        final t    = response.data['token'] ?? '';
        final id   = response.data['id']   ?? '';
        final name = response.data['username'] ?? '';
        final role = response.data['role']    ?? '';

        token.value = t;
        user.value  = User(id: id, name: name, role: role);

        // Persist to SharedPreferences for auto-login on next launch
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(StorageKeys.token, t);
        await prefs.setString(StorageKeys.id,    id);
        await prefs.setString('username',         name);
        await prefs.setString(StorageKeys.role,   role);
        await prefs.setBool(StorageKeys.isLoggedIn, true);

        Get.offAll(() => Home());
      } else {
        Get.snackbar('Login Failed', 'Unexpected server response.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      String msg = 'Login failed. Please check your credentials.';
      try {
        final dynamic err = e;
        final serverMsg = err.response?.data?['message'];
        if (serverMsg != null) msg = serverMsg.toString();
      } catch (_) {}
      Get.snackbar('Login Failed', msg, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    token.value = '';
    user.value  = User(id: '', name: '', role: '');
  }
}
