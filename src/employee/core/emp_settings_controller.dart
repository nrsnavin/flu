import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The employee side's own settings: the language its screens are shown
/// in, kept on this phone.
///
/// The app lock it also had is gone: the app has one lock now, the
/// office screens' (core/lock), and the employee settings page shows
/// that one's switch. Two locks on one app would each think it was the
/// only one.
class EmpSettingsController extends GetxController {
  static const _kLocale = 'app.locale';

  static EmpSettingsController get find =>
      Get.isRegistered<EmpSettingsController>()
          ? Get.find<EmpSettingsController>()
          : Get.put(EmpSettingsController(), permanent: true);

  final locale = const Locale('en').obs;

  /// The stored choice; read before the employee side first draws, so
  /// it opens in the language picked last time.
  Future<Locale> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      locale.value = Locale(p.getString(_kLocale) ?? 'en');
    } catch (_) {
      locale.value = const Locale('en');
    }
    return locale.value;
  }

  Future<void> setLocale(String code) async {
    locale.value = Locale(code);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocale, code);
    Get.updateLocale(Locale(code));
  }
}
