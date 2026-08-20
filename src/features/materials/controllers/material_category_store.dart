import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════════
//  THE FIXED VOCABULARY OF `RawMaterial.category`
//
//  Five values, owned by the system, and separate from material
//  GROUPS — which the mill owns and adds to freely.
//
//  ── Why this file exists ─────────────────────────────────────────
//  The two used to be one field. `category` held the GROUP'S NAME, so
//  this app's add-material screen built its category picker out of
//  MaterialGroupStore.names and posted whatever the mill had called
//  its groups. That was survivable while the server accepted anything.
//  It is not now: the server validates against this list and answers
//  400 with the five names in it, so a phone filing a yarn under
//  "Trim Tape" simply cannot save.
//
//  The deeper reason is the one that was costing money before the
//  validation existed. `category` is what the elastic recipe picker,
//  the MRP sheet and the warp/weft/covering queries are written in —
//  they run `find({ category: "warp" })`. A yarn filed under a group
//  name got a category none of them had heard of and silently vanished
//  from the picker. Nothing errored. It was just not there.
//
//  So:
//    category — WHAT THE SYSTEM NEEDS TO KNOW. Fixed; a new value is a
//               code change, because code would have to learn what to
//               do with it.
//    group    — WHAT THE MILL WANTS TO TRACK. Free, renameable, as
//               many as they like. Nothing branches on it.
//
//  ── Fetched, not hardcoded ───────────────────────────────────────
//  This list lived in eight places across three codebases that did not
//  agree: the web knew four values, this app knew five, and the server
//  matched four literals by exact case. One source now, at
//  GET /materials/categories — the same endpoint the web reads.
// ══════════════════════════════════════════════════════════════════

/// What the server has always held, for when the fetch fails.
///
/// A picker that cannot populate is worse than one showing a slightly
/// stale list: it blocks the screen entirely. These five are the exact
/// strings live data holds — the casing is deliberate and load-bearing,
/// because the recipe picker matches `"Rubber"` as a literal.
const List<String> kMaterialCategories = [
  'warp',
  'weft',
  'covering',
  'Rubber',
  'Chemicals',
];

/// The three that say WHERE in the cloth a material sits, as opposed to
/// WHAT it is. The elastic recipe pickers want only these.
const List<String> kMaterialPositions = ['warp', 'weft', 'covering'];

class MaterialCategoryStore extends GetxService {
  static MaterialCategoryStore get to => Get.find<MaterialCategoryStore>();

  /// Register it if it is not already, and return it.
  ///
  /// Not registered in main.dart, for the same reason MaterialGroupStore
  /// is not: the endpoint sits behind the auth gate, so fetching at app
  /// start would fire a 401 before anybody has logged in.
  static MaterialCategoryStore ensure() =>
      Get.isRegistered<MaterialCategoryStore>()
          ? Get.find<MaterialCategoryStore>()
          : Get.put(MaterialCategoryStore(), permanent: true);

  static final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/materials',
    timeout: const Duration(seconds: 10),
  );

  final _categories = <String>[...kMaterialCategories].obs;
  final _positions  = <String>[...kMaterialPositions].obs;
  final isLoading   = false.obs;

  /// True when the last fetch failed and the list below is the built-in
  /// fallback rather than the server's. Worth surfacing: it is the
  /// difference between "these are the categories" and "these are the
  /// categories as of whenever this app was built".
  final loadFailed = false.obs;

  List<String> get categories => List.unmodifiable(_categories);
  List<String> get positions  => List.unmodifiable(_positions);

  /// The same, with the "All" option a filter needs in front.
  List<String> get categoriesWithAll => ['All', ..._categories];

  /// Match a value to its canonical spelling, case- and
  /// whitespace-insensitively. Null when it is not one of them.
  ///
  /// Folding matters on the way IN as much as on the way out: a
  /// material saved from an older build as "rubber" must still light up
  /// the "Rubber" chip, or the split this whole change exists to end
  /// gets preserved forever.
  String? canonical(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    for (final c in _categories) {
      if (c.toLowerCase() == v) return c;
    }
    return null;
  }

  /// True when [value] is one of the five, in any casing.
  bool isCategory(String? value) => canonical(value) != null;

  bool _loadedOnce = false;

  Future<void> load({bool force = false}) async {
    if (isLoading.value) return;
    if (_loadedOnce && !force) return;
    isLoading.value = true;
    try {
      final res = await _dio.get('/categories');
      final cats = (res.data['categories'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      final pos = (res.data['positions'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      // An empty list from the server is not an answer worth adopting —
      // it would blank every picker in the app. Keep the fallback and
      // say the fetch did not land.
      if (cats.isEmpty) {
        loadFailed.value = true;
      } else {
        _categories.assignAll(cats);
        if (pos.isNotEmpty) _positions.assignAll(pos);
        loadFailed.value = false;
        _loadedOnce = true;
      }
    } catch (_) {
      loadFailed.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }
}
