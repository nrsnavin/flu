import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/app_config.dart';
import '../../../core/api_client.dart';

// ══════════════════════════════════════════════════════════════
//  MATERIAL GROUPS — the one list of categories
//
//  This app used to hold the list in SIX places:
//
//    rawMaterial_controller.dart   kCategories, twice
//    list.dart                     kCategories
//    stockAdjustController.dart    categories
//    adjust_history.dart           kCategories
//    stock_adjust.dart / adjust_screen.dart / add_materials_page.dart
//                                  a colour switch each
//
//  and the web held a SEVENTH that was missing 'Chemicals', while the
//  server matched four literal strings by exact case. So a material
//  saved here as "Chemicals" was invisible on the web, and changing
//  the case of "Rubber" anywhere emptied the elastic recipe picker
//  with no error at all.
//
//  The list now comes from the server. It is cached for the session
//  because it changes about as often as the supplier list does, and a
//  picker that refetches on every sheet open is a picker that is empty
//  for the first half-second on a mill's connection.
//
//  ── The fallback matters ─────────────────────────────────────
//  If the fetch fails — no signal in the shed, an older server — the
//  picker falls back to the names this app has always used. An empty
//  category dropdown would stop somebody adding a material at all,
//  which is strictly worse than the imperfect list they had yesterday.
// ══════════════════════════════════════════════════════════════

class MaterialGroup {
  final String id;
  final String name;
  final String kind;
  final String colour;

  const MaterialGroup({
    required this.id,
    required this.name,
    this.kind = 'other',
    this.colour = '',
  });

  factory MaterialGroup.fromJson(Map<String, dynamic> j) => MaterialGroup(
        id: (j['_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        kind: (j['kind'] ?? 'other').toString(),
        colour: (j['colour'] ?? '').toString(),
      );
}

/// What this app shipped with, before the list came from the server.
/// Used only when the fetch fails — see the note above.
const List<String> kFallbackCategories = [
  'warp',
  'weft',
  'covering',
  'Rubber',
  'Chemicals',
];

class MaterialGroupService {
  static final Dio _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/material-group',
    timeout: const Duration(seconds: 12),
  );

  static Future<List<MaterialGroup>> fetch() async {
    final res = await _dio.get('/');
    return (res.data['groups'] as List? ?? [])
        .map((e) => MaterialGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Session-wide cache, shared by every screen that offers a category.
///
/// A `permanent` service rather than a per-screen controller: the list
/// page, the add form, the stock-adjust sheet and the adjust history
/// all want the same list, and four copies of it would be four
/// different lists again — which is the whole thing being fixed.
class MaterialGroupStore extends GetxService {
  static MaterialGroupStore get to => Get.find<MaterialGroupStore>();

  /// Register it if it is not already, and return it.
  ///
  /// Not registered in main.dart on purpose: the endpoint sits behind
  /// the auth gate, so fetching at app start would fire a 401 before
  /// anybody has logged in. Each screen that needs the list asks for it
  /// instead, and the first asker pays for the fetch.
  static MaterialGroupStore ensure() =>
      Get.isRegistered<MaterialGroupStore>()
          ? Get.find<MaterialGroupStore>()
          : Get.put(MaterialGroupStore(), permanent: true);

  final groups = <MaterialGroup>[].obs;
  final isLoading = false.obs;
  final loadFailed = false.obs;

  /// Group names for a dropdown. Falls back to the names this app has
  /// always used rather than returning an empty list.
  List<String> get names => groups.isNotEmpty
      ? groups.map((g) => g.name).toList()
      : List<String>.from(kFallbackCategories);

  /// The same, with the "All" option a filter sheet needs in front.
  List<String> get namesWithAll => ['All', ...names];

  MaterialGroup? byName(String name) {
    final lower = name.toLowerCase();
    for (final g in groups) {
      if (g.name.toLowerCase() == lower) return g;
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (isLoading.value) return;
    if (groups.isNotEmpty && !force) return;
    isLoading.value = true;
    try {
      groups.value = await MaterialGroupService.fetch();
      loadFailed.value = false;
    } catch (_) {
      // Left empty on purpose — `names` falls back, so every picker
      // still offers something rather than nothing.
      loadFailed.value = true;
    } finally {
      isLoading.value = false;
    }
  }
}
