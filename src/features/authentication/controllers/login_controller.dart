import 'package:dio/dio.dart';
import 'package:get/get.dart';

import 'package:production/src/features/authentication/controllers/storage_keys.dart';
import 'package:production/src/features/authentication/screens/login.dart';
import 'package:production/src/features/authentication/screens/welcome_screen.dart';

// import 'package:admin/src/features/authentication/screens/home.dart';

import '../models/user.dart';
import '../screens/home.dart';






class LoginController extends GetxController {
  static LoginController get find => Get.find();
  Rx<User> user = User(id: "1", name: "Anu Tapes", role: "admin").obs;





  @override
  void onInit() {
    super.onInit();
    // _handleAutoLogin();
  }






  void tryLogin(String email, String password) async {
    final response = await Dio().post(
      'http://13.233.117.153:2701/api/v2/user/login-user',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 201) {
      // If the server did return a 201 CREATED response,
      // then parse the JSON.
      // await FlutterSessionJwt.saveToken(response.data['token']);




      user.value = User(

        id: response.data['id'],
        name: response.data['username'],
        role: response.data['role'],
      );




    } else {
      // If the server did not return a 201 CREATED response,
      // then throw an exception.
      throw Exception('Failed to Login.');
    }
  }
}
