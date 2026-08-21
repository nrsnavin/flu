import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/PurchaseOrder/services/theme.dart' show ErpColors;
import 'erp_palette.dart';

// ══════════════════════════════════════════════════════════════
//  LIGHT, DARK, OR WHATEVER THE PHONE IS DOING
//
//  Three modes, not two. "System" is the default and is the one most
//  people never change: a mill floor at 6am and the same floor at
//  9pm want different screens, and the phone already knows which it
//  is. Offering only an explicit pair would make everybody choose
//  once and then live with the wrong one half the time.
//
//  ── How a switch actually reaches the screen ───────────────────
//  ErpColors is a set of static getters over a palette, so changing
//  the palette changes what every one of 5,500 call sites returns —
//  but nothing repaints on its own, because a static read is not
//  something Flutter watches. So [mode] is an Rx, the root wraps
//  MaterialApp in an Obx, and a change rebuilds the whole tree from
//  above. That is heavy exactly once per switch, which is the right
//  place to be expensive.
//
//  ── System mode has to keep listening ──────────────────────────
//  Resolving the platform brightness once at boot is not enough: the
//  phone flips at sunset, or the user toggles it in Control Centre,
//  and the app is expected to follow WITHOUT being reopened. So this
//  is also a WidgetsBindingObserver, and didChangePlatformBrightness
//  re-resolves. Forgetting that is the classic way "system" theming
//  half-works and nobody can say why.
//
//  ── The stored value is the MODE, never the palette ────────────
//  Persisting "dark" rather than a resolved palette means a phone
//  left on system that changes overnight comes back correct in the
//  morning. Persisting the resolved answer would freeze it.
// ══════════════════════════════════════════════════════════════

enum ErpThemeMode { system, light, dark }

extension ErpThemeModeLabel on ErpThemeMode {
  String get label => switch (this) {
        ErpThemeMode.system => 'Match phone',
        ErpThemeMode.light => 'Light',
        ErpThemeMode.dark => 'Dark',
      };

  IconData get icon => switch (this) {
        ErpThemeMode.system => Icons.brightness_auto_outlined,
        ErpThemeMode.light => Icons.light_mode_outlined,
        ErpThemeMode.dark => Icons.dark_mode_outlined,
      };
}

class ThemeController extends GetxController with WidgetsBindingObserver {
  static const _prefsKey = 'erp_theme_mode';

  static ThemeController get to => Get.find<ThemeController>();

  /// Register early — main() awaits this before the first frame so the
  /// app never paints light and then snaps to dark.
  static Future<ThemeController> ensure() async {
    if (Get.isRegistered<ThemeController>()) return Get.find<ThemeController>();
    final c = Get.put(ThemeController(), permanent: true);
    await c._restore();
    return c;
  }

  final mode = ErpThemeMode.system.obs;

  /// Bumped on every resolve so the Obx at the root has something to
  /// react to even when only the PLATFORM brightness moved and the
  /// stored mode did not.
  final revision = 0.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangePlatformBrightness() {
    // Only matters in system mode, but re-resolving is cheap and
    // guarding it would just be one more thing to get wrong.
    _apply();
    super.didChangePlatformBrightness();
  }

  bool get isDark => ErpColors.palette.isDark;

  Future<void> setMode(ErpThemeMode m) async {
    if (m == mode.value) return;
    mode.value = m;
    _apply();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, m.name);
  }

  /// What the toggle button does: from wherever you are, go to the
  /// other one. Tapping it while on "match phone" commits to the
  /// opposite of what the phone is currently showing, which is what
  /// somebody reaching for the control means by it.
  Future<void> toggle() =>
      setMode(isDark ? ErpThemeMode.light : ErpThemeMode.dark);

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      mode.value = ErpThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ErpThemeMode.system,
      );
    } catch (_) {
      // A phone that will not give us preferences still gets a theme.
      mode.value = ErpThemeMode.system;
    }
    _apply();
  }

  void _apply() {
    final dark = switch (mode.value) {
      ErpThemeMode.light => false,
      ErpThemeMode.dark => true,
      ErpThemeMode.system =>
        // platformDispatcher, not MediaQuery: this runs outside the
        // widget tree, including before the first frame.
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    final next = dark ? ErpPalette.dark : ErpPalette.light;
    if (identical(next, ErpColors.palette)) return;
    ErpColors.palette = next;
    revision.value++;
  }

  /// The Flutter-side ThemeData, so framework widgets this app does
  /// not style itself — dialogs, snackbars, the date picker, text
  /// selection handles — follow too. Missing this is why an app can
  /// look themed until somebody opens a date picker.
  ThemeData get themeData {
    final p = ErpColors.palette;
    final base = p.isDark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: p.bgBase,
      canvasColor: p.bgSurface,
      dividerColor: p.borderLight,
      colorScheme: (p.isDark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
        primary: p.accentBlue,
        secondary: p.accentLight,
        surface: p.bgSurface,
        error: p.errorRed,
        onSurface: p.textPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bgSurface,
        titleTextStyle: TextStyle(
            color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.bgSurface),
      popupMenuTheme: PopupMenuThemeData(
        color: p.bgSurface,
        textStyle: TextStyle(color: p.textPrimary, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: TextStyle(color: p.textOnDark),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.bgMuted,
        selectedColor: p.accentBlue.withValues(alpha: 0.14),
        labelStyle: TextStyle(color: p.textSecondary),
        side: BorderSide(color: p.borderLight),
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: p.accentBlue),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accentBlue,
        selectionColor: p.accentBlue.withValues(alpha: 0.25),
        selectionHandleColor: p.accentBlue,
      ),
    );
  }
}
