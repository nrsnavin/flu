import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../models/user.dart';
import '../screens/home.dart';

class LoginController extends GetxController {
  static LoginController get find => Get.find();

  Rx<User> user = User(id: '', name: '', role: '').obs;
  RxBool isLoading = false.obs;
  // Token kept in memory for the session; use shared_preferences for persistence
  RxString token = ''.obs;

  @override
  void onInit() {
    super.onInit();
  }

  void tryLogin(String email, String password) async {
    isLoading.value = true;
    try {
      final response = await Dio().post(
        'http://13.233.117.153:2701/api/v2/user/login-user',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 201) {
        token.value = response.data['token'] ?? '';
        user.value = User(
          id: response.data['id'],
          name: response.data['username'],
          role: response.data['role'],
        );
        Get.offAll(() => Home());
      } else {
        Get.snackbar(
          'Login Failed',
          'Unexpected server response.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      String msg = 'Login failed. Please check your credentials.';
      // Extract server error message when available
      try {
        final dynamic err = e;
        final serverMsg = err.response?.data?['message'];
        if (serverMsg != null) msg = serverMsg.toString();
      } catch (_) {}
      Get.snackbar(
        'Login Failed',
        msg,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
