import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'theme/theme_controller.dart';

// ══════════════════════════════════════════════════════════════
//  OFFICE SIDE OR EMPLOYEE SIDE
//
//  One app, two sets of screens. The office screens are what a staff
//  login sees; the employee screens (src/employee — the old employee
//  app, moved in) are what a worker's own login sees, and what an
//  office login linked to an employee record opens as "My work".
//
//  This is the one place that knows which is showing, because two
//  things follow from it that the screens themselves cannot do:
//
//    * the theme — the employee screens were built for one light
//      palette, so while any is open the app is drawn light (see
//      ThemeController.employeeSide);
//    * the language — a worker's chosen language applies to their
//      screens, and the office screens stay in English.
// ══════════════════════════════════════════════════════════════

class AppSide extends GetxController {
  static AppSide get to => Get.isRegistered<AppSide>()
      ? Get.find<AppSide>()
      : Get.put(AppSide(), permanent: true);

  /// A worker's own login (phone + PIN, or any login the server calls
  /// self-service): the whole app is the employee side. Set by
  /// LoginController from the session.
  final worker = false.obs;

  /// Employee screens opened from an office login ("My work"), counted
  /// so that two open at once (a transition) never switch back early.
  final _fromStaff = 0.obs;

  bool get employee => worker.value || _fromStaff.value > 0;

  @override
  void onInit() {
    super.onInit();
    everAll([worker, _fromStaff], (_) => _sync());
    ever<bool>(worker, (on) {
      // Back to English for whoever signs in next; a worker's own
      // choice is applied again when their screens open.
      if (!on) setLanguage(const Locale('en'));
    });
    _sync();
  }

  void enterFromStaff() => _fromStaff.value++;

  void leaveFromStaff() {
    if (_fromStaff.value > 0) _fromStaff.value--;
  }

  /// Change the app's language, only when it is a change: every change
  /// rebuilds the whole app.
  static void setLanguage(Locale locale) {
    if (Get.locale?.languageCode == locale.languageCode) return;
    Get.updateLocale(locale);
  }

  void _sync() {
    if (Get.isRegistered<ThemeController>()) {
      ThemeController.to.employeeSide = employee;
    }
  }
}
