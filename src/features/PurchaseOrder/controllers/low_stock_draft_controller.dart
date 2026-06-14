import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';

/// One low-stock material as returned by `GET /materials/low-stock`.
/// Kept as a thin record over the raw JSON so we don't drag a new
/// model into the PO graph for a single screen.
class LowStockMaterial {
  final String id;
  final String name;
  final double stock;
  final double minStock;
  final double price;
  final double suggestedQty;
  final String supplierId;
  final String supplierName;

  /// `null` when the material is already below `minStock` (the
  /// reactive `/low-stock` source). Set for predictive entries
  /// from `/projected-stockout` — number of days the current
  /// stock will last at the trailing 30-day consumption rate.
  final double? daysToStockout;

  const LowStockMaterial({
    required this.id,
    required this.name,
    required this.stock,
    required this.minStock,
    required this.price,
    required this.suggestedQty,
    required this.supplierId,
    required this.supplierName,
    this.daysToStockout,
  });

  bool get isPredictive => daysToStockout != null;

  factory LowStockMaterial.fromJson(
    Map<String, dynamic> j, {
    bool predictive = false,
  }) {
    final sup = j['supplier'] as Map?;
    return LowStockMaterial(
      id:           j['_id']?.toString() ?? '',
      name:         j['name']?.toString() ?? '—',
      stock:        (j['stock']        as num?)?.toDouble() ?? 0,
      minStock:     (j['minStock']     as num?)?.toDouble() ?? 0,
      price:        (j['price']        as num?)?.toDouble() ?? 0,
      suggestedQty: (j['suggestedQty'] as num?)?.toDouble() ?? 0,
      supplierId:   sup?['_id']?.toString()  ?? '',
      supplierName: sup?['name']?.toString() ?? '—',
      daysToStockout: predictive
          ? (j['daysToStockout'] as num?)?.toDouble()
          : null,
    );
  }

  double get suggestedValue => price * suggestedQty;

  /// 0.0 = empty, 1.0 = at-or-above (minStock * 2). Mirrors
  /// `RawMaterialListItem.stockPercent` so the bar widget reads
  /// identically across the app.
  double get stockPercent =>
      minStock > 0 ? (stock / (minStock * 2)).clamp(0.0, 1.0) : 1.0;
}

/// Pulls the auto-draft list and groups it by supplier so the page
/// can render one "Draft PO" button per supplier.
class LowStockDraftController extends GetxController {
  /// Materials already below their min-stock floor.
  final materials         = <LowStockMaterial>[].obs;

  /// Materials still above the floor but projected to cross it
  /// inside the trailing horizon. Sourced from /projected-stockout.
  final projected         = <LowStockMaterial>[].obs;

  final skippedNoSupplier = 0.obs;
  final loading           = false.obs;
  final errorMsg          = Rxn<String>();

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/materials',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      // Reactive (already low) and predictive (about to be low) in
      // one round-trip. A failure on either drops just that list.
      final results = await Future.wait([
        _dio.get('/low-stock').catchError((_) => null),
        _dio.get('/projected-stockout').catchError((_) => null),
      ]);

      final lowRes = results[0];
      final projRes = results[1];

      if (lowRes != null) {
        final list = (lowRes.data['materials'] as List?) ?? const [];
        materials.assignAll(
          list.whereType<Map>().map(
                (m) => LowStockMaterial.fromJson(
                    Map<String, dynamic>.from(m)),
              ),
        );
        skippedNoSupplier.value =
            (lowRes.data['skippedNoSupplier'] as num?)?.toInt() ?? 0;
      }

      if (projRes != null) {
        final list = (projRes.data['materials'] as List?) ?? const [];
        projected.assignAll(
          list.whereType<Map>().map(
                (m) => LowStockMaterial.fromJson(
                    Map<String, dynamic>.from(m),
                    predictive: true),
              ),
        );
      }

      if (lowRes == null && projRes == null) {
        errorMsg.value = 'Failed to load';
      }
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  /// supplierId → materials (reactive + predictive merged). Used by
  /// the page's grouped Draft PO buttons so one supplier with both
  /// reactive and predictive rows produces a single combined PO.
  Map<String, List<LowStockMaterial>> get groupedBySupplier {
    final out = <String, List<LowStockMaterial>>{};
    for (final m in materials) {
      out.putIfAbsent(m.supplierId, () => []).add(m);
    }
    for (final m in projected) {
      out.putIfAbsent(m.supplierId, () => []).add(m);
    }
    return out;
  }

  /// Seed map for `AddPOPage`'s create-mode `seedData`. The
  /// controller's `_prefill` already knows this shape — keys must
  /// match exactly (`supplierId`, `items[].rawMaterialId`). Picks
  /// rows from both reactive and predictive lists so one tap
  /// drafts a unified PO per supplier.
  Map<String, dynamic> seedDataFor(String supplierId) {
    final rows = [
      ...materials.where((m) => m.supplierId == supplierId),
      ...projected.where((m) => m.supplierId == supplierId),
    ];
    return {
      'supplierId': supplierId,
      'items': rows
          .map((m) => {
                'rawMaterialId': m.id,
                'price':         m.price,
                'quantity':      m.suggestedQty,
              })
          .toList(),
    };
  }
}
