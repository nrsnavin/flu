import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl_standalone.dart'
    if (dart.library.html) 'package:intl/intl_browser.dart';

import 'src/features/auth/controllers/login_controller.dart';
import 'src/features/auth/screens/auth_gate.dart';
import 'src/theme/erp_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting();
  await findSystemLocale();
  runApp(const EmployeeApp());
}

class EmployeeApp extends StatelessWidget {
  const EmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Worker Portal',
      // Wire the login controller eagerly so AuthGate's Obx
      // binding sees its observables on the very first frame.
      initialBinding: BindingsBuilder(() {
        Get.put(LoginController(), permanent: true);
      }),
      theme: ThemeData(
        scaffoldBackgroundColor: ErpColors.bgBase,
        primaryColor: ErpColors.accentBlue,
        appBarTheme: const AppBarTheme(
          backgroundColor: ErpColors.navyDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: ErpColors.accentBlue,
          primary:   ErpColors.accentBlue,
          secondary: ErpColors.accentLight,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
