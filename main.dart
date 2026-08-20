import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl_standalone.dart'
    if (dart.library.html) 'package:intl/intl_browser.dart';
import 'package:production/src/core/theme/theme_controller.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';
import 'package:production/src/features/authentication/screens/auth_gate.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting();
  await findSystemLocale();
  // Awaited before the first frame on purpose: resolving the stored
  // preference afterwards would paint one frame of light and then snap
  // to dark, which reads as a bug every single launch.
  await ThemeController.ensure();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.to;

    // ── Why the whole app is inside one Obx ──────────────────
    // ErpColors is a set of static getters, and a static read is not
    // something Flutter can watch. Nothing under here would repaint on
    // its own when the palette changes. Rebuilding from above the
    // MaterialApp is what makes a switch reach all 5,500 call sites —
    // expensive exactly once per switch, which is the right place to
    // spend it.
    return Obx(() {
      // Read both so the builder re-runs for a stored-mode change AND
      // for the phone flipping brightness under "match phone".
      theme.mode.value;
      theme.revision.value;

      return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.themeData,
        initialBinding: BindingsBuilder(() {
          Get.put(LoginController());
        }),
        home: const AuthGate(),
      );
    });
  }
}
