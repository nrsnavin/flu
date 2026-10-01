import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl_standalone.dart'
    if (dart.library.html) 'package:intl/intl_browser.dart';
import 'package:production/src/core/error_handling.dart';
import 'package:production/src/core/lock/app_lock_controller.dart';
import 'package:production/src/core/theme/theme_controller.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';
import 'package:production/src/features/authentication/screens/auth_gate.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  // Everything runs inside one guarded zone — binding, setup and runApp
  // together, since Flutter expects them in the same zone — so an async
  // error nothing caught is logged and shown as a message rather than
  // closing the app (see src/core/error_handling.dart).
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    installGlobalErrorHandlers();
    try {
      initializeDateFormatting();
      await findSystemLocale();
    } catch (_) {
      // Best-effort, as in the Worker Portal: a failure here must not
      // stop the app from opening; dates fall back to en-US.
    }
    // Awaited before the first frame on purpose: resolving the stored
    // preference afterwards would paint one frame of light and then snap
    // to dark, which reads as a bug every single launch.
    await ThemeController.ensure();
    // Before runApp so the setting is known by the time the first frame
    // is built — a lock that appears a beat AFTER the app has drawn is
    // a lock that showed somebody the screen it was meant to hide.
    await AppLockController.ensure();
    runApp(const MyApp());
  }, reportZoneError);
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
