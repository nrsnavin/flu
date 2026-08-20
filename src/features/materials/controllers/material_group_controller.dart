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

  /// Stable handle that does NOT move when the name is edited.
  final String code;
  final String kind;
  final String colour;
  final int sortOrder;
  final String defaultUnit;
  final double defaultMinStock;
  final String notes;
  final bool archived;

  /// Live members. Only present when the list was asked withCounts.
  final int? materialCount;

  /// Live PLUS archived members. This — not [materialCount] — is what
  /// decides archive-vs-delete, because an archived material still
  /// names its group. Reading the live count alone made the web's
  /// confirm dialog promise "removed outright" for a group the server
  /// then archived; the same trap is here.
  final int? totalMaterialCount;

  const MaterialGroup({
    required this.id,
    required this.name,
    this.code = '',
    this.kind = 'other',
    this.colour = '',
    this.sortOrder = 0,
    this.defaultUnit = 'kg',
    this.defaultMinStock = 0,
    this.notes = '',
    this.archived = false,
    this.materialCount,
    this.totalMaterialCount,
  });

  factory MaterialGroup.fromJson(Map<String, dynamic> j) => MaterialGroup(
        id: (j['_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        kind: (j['kind'] ?? 'other').toString(),
        colour: (j['colour'] ?? '').toString(),
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        defaultUnit: (j['defaultUnit'] ?? 'kg').toString(),
        defaultMinStock: (j['defaultMinStock'] as num?)?.toDouble() ?? 0,
        notes: (j['notes'] ?? '').toString(),
        archived: j['archived'] == true,
        materialCount: (j['materialCount'] as num?)?.toInt(),
        totalMaterialCount: (j['totalMaterialCount'] as num?)?.toInt(),
      );

  Map<String, dynamic> toValues() => {
        'name': name,
        'kind': kind,
        'sortOrder': sortOrder,
        'colour': colour,
        'defaultUnit': defaultUnit,
        'defaultMinStock': defaultMinStock,
        'notes': notes,
      };

  MaterialGroup copyWith({
    String? name,
    String? kind,
    String? colour,
    int? sortOrder,
    String? defaultUnit,
    double? defaultMinStock,
    String? notes,
  }) =>
      MaterialGroup(
        id: id,
        name: name ?? this.name,
        code: code,
        kind: kind ?? this.kind,
        colour: colour ?? this.colour,
        sortOrder: sortOrder ?? this.sortOrder,
        defaultUnit: defaultUnit ?? this.defaultUnit,
        defaultMinStock: defaultMinStock ?? this.defaultMinStock,
        notes: notes ?? this.notes,
        archived: archived,
        materialCount: materialCount,
        totalMaterialCount: totalMaterialCount,
      );
}

/// Which question a group answers.
///
///   position — where the material sits in the cloth: warp, weft, covering
///   material — what the material IS: rubber, chemicals, yarn
///   other    — neither, or not decided yet
///
/// The two axes shared one field for years, which is why the original
/// list read oddly: three positions and one substance.
const kGroupKinds = <String, ({String label, String hint})>{
  'position': (label: 'Position in the cloth', hint: 'Warp, weft, covering'),
  'material': (label: 'What it is', hint: 'Rubber, chemicals, yarn'),
  'other': (label: 'Other', hint: 'Anything else'),
};

/// The colours this app has always drawn its category chips in, so a
/// group created here looks native rather than an arbitrary hex.
const kGroupSwatches = <String>[
  '#3B82F6', // warp
  '#8B5CF6', // weft
  '#14B8A6', // covering
  '#F59E0B', // rubber
  '#EF4444', // chemicals
  '#10B981',
  '#EC4899',
  '#6B7280',
];

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

  static Future<List<MaterialGroup>> fetch({
    bool includeArchived = false,
    bool withCounts = false,
  }) async {
    final res = await _dio.get('/', queryParameters: {
      if (includeArchived) 'includeArchived': '1',
      // Costs an extra aggregation on the server, so only the settings
      // screen asks for it.
      if (withCounts) 'withCounts': '1',
    });
    return (res.data['groups'] as List? ?? [])
        .map((e) => MaterialGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<MaterialGroup> create(Map<String, dynamic> values) async {
    final res = await _dio.post('/create', data: values);
    return MaterialGroup.fromJson(
        Map<String, dynamic>.from(res.data['group'] as Map));
  }

  /// A rename cascades to every member's category, so the response
  /// says how many materials moved — worth showing, because renaming a
  /// group silently rewriting eighty rows is a surprise.
  static Future<({MaterialGroup group, int materialsRenamed})> update(
    String id,
    Map<String, dynamic> values,
  ) async {
    final res = await _dio.put('/update', data: {'id': id, ...values});
    return (
      group: MaterialGroup.fromJson(
          Map<String, dynamic>.from(res.data['group'] as Map)),
      materialsRenamed: (res.data['materialsRenamed'] as num?)?.toInt() ?? 0,
    );
  }

  /// Archives if the group holds materials, deletes if it never did —
  /// the same rule materials, elastics and customers already follow.
  /// The response says which happened and why.
  static Future<({bool archived, String message})> remove(String id) async {
    final res = await _dio.delete('/$id');
    return (
      archived: res.data['archived'] == true,
      message: (res.data['message'] ?? '').toString(),
    );
  }

  static Future<MaterialGroup> restore(String id) async {
    final res = await _dio.post('/restore', data: {'id': id});
    return MaterialGroup.fromJson(
        Map<String, dynamic>.from(res.data['group'] as Map));
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
