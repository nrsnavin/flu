import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:intl/intl_standalone.dart'
    if (dart.library.html) 'package:intl/intl_browser.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';
import 'package:production/src/features/authentication/screens/home.dart';

import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:production/src/features/authentication/screens/welcome_screen.dart';
// import 'package:production/src/features/customer/screens/AddCustomer.dart';

Future<void> main() async {
  initializeDateFormatting();
  DateTime now = DateTime.now();
  var dateString = DateFormat('dd-MM-yyyy').format(now);
  final String configFileName = 'lastConfig.$dateString.json';

  WidgetsFlutterBinding.ensureInitialized();
  await findSystemLocale();
  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialBinding: BindingsBuilder(() {
        Get.put(LoginController());
      }),


      home:WelcomeScreen(),
    );;
  }
}
