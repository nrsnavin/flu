import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

// ══════════════════════════════════════════════════════════════
//  CATEGORY COLOUR — one resolver, was three switches
//
//  stock_adjust.dart and adjust_screen.dart each held a lowercased
//  `switch`; add_materials_page.dart held a case-SENSITIVE one, so
//  `case 'Rubber'` lost its colour the moment anybody wrote "rubber".
//  All three knew the same five names and nothing else, so a group the
//  mill added was grey everywhere.
//
//  A group's own colour wins when one is set in Settings. The old
//  switch stays as the fallback, folded to lowercase — so the five
//  names this app has always known keep exactly the colours they had,
//  and a group with no colour chosen yet looks the same as yesterday
//  rather than suddenly going grey.
// ══════════════════════════════════════════════════════════════

const Color _kGrey = Color(0xFF6B7280);

/// `#RRGGBB`, `RRGGBB` or `#AARRGGBB` → a Color. Null for anything else,
/// including the empty string a group carries until somebody picks one.
Color? parseHexColour(String raw) {
  var h = raw.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

Color _legacyCategoryColour(String name) => switch (name.toLowerCase()) {
      'warp' => const Color(0xFF3B82F6),
      'weft' => const Color(0xFF8B5CF6),
      'covering' => const Color(0xFF14B8A6),
      'rubber' => const Color(0xFFF59E0B),
      'chemicals' => const Color(0xFFEF4444),
      _ => _kGrey,
    };

/// The colour to draw a category chip in.
///
/// Safe before the store is registered — a screen that renders during
/// startup gets the fallback rather than an exception.
Color categoryColour(String name) {
  if (Get.isRegistered<MaterialGroupStore>()) {
    final g = MaterialGroupStore.to.byName(name);
    if (g != null && g.colour.isNotEmpty) {
      final c = parseHexColour(g.colour);
      if (c != null) return c;
    }
  }
  return _legacyCategoryColour(name);
}

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
