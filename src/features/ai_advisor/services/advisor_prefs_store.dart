import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coarse buckets the admin can mute when they don't care about a
/// whole class of signal. Mapped from `AISuggestion.moduleId` by
/// `AIAdvisor._categoryFor` — keeping the categorization on the
/// controller means new rules don't need to know about prefs at all.
enum AdvisorCategory { inventory, people, production, purchasing }

extension AdvisorCategoryLabel on AdvisorCategory {
  String get label {
    switch (this) {
      case AdvisorCategory.inventory:  return 'Inventory';
      case AdvisorCategory.people:     return 'People';
      case AdvisorCategory.production: return 'Production';
      case AdvisorCategory.purchasing: return 'Purchasing';
    }
  }

  String get key => name;
}

/// SharedPreferences-backed store for the user's advisor toggles.
/// Exposes a reactive `disabled` set so the strip can re-render
/// immediately when the admin flips a switch — no advisor refetch
/// needed for the filter to take effect.
class AdvisorPrefsStore extends GetxController {
  static AdvisorPrefsStore get instance =>
      Get.isRegistered<AdvisorPrefsStore>()
          ? Get.find<AdvisorPrefsStore>()
          : Get.put(AdvisorPrefsStore(), permanent: true);

  static const _key = 'advisor_disabled_categories';

  final disabled = <AdvisorCategory>{}.obs;
  final loaded   = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    disabled.assignAll(raw.map(_decode).whereType<AdvisorCategory>());
    loaded.value = true;
  }

  Future<void> toggle(AdvisorCategory c, bool enabled) async {
    if (enabled) {
      disabled.remove(c);
    } else {
      disabled.add(c);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      disabled.map((e) => e.key).toList(),
    );
  }

  bool isEnabled(AdvisorCategory c) => !disabled.contains(c);

  AdvisorCategory? _decode(String s) {
    for (final c in AdvisorCategory.values) {
      if (c.key == s) return c;
    }
    return null;
  }
}
