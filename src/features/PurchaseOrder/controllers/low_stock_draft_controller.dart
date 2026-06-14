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

  const LowStockMaterial({
    required this.id,
    required this.name,
    required this.stock,
    required this.minStock,
    required this.price,
    required this.suggestedQty,
    required this.supplierId,
    required this.supplierName,
  });

  factory LowStockMaterial.fromJson(Map<String, dynamic> j) {
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
  final materials         = <LowStockMaterial>[].obs;
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
      final res = await _dio.get('/low-stock');
      final list = (res.data['materials'] as List?) ?? const [];
      materials.assignAll(
        list.whereType<Map>().map(
              (m) => LowStockMaterial.fromJson(Map<String, dynamic>.from(m)),
            ),
      );
      skippedNoSupplier.value =
          (res.data['skippedNoSupplier'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      errorMsg.value = e.response?.data is Map
          ? (e.response?.data['message'] as String?) ?? 'Failed to load'
          : 'Failed to load';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  /// supplierId → materials. Preserves arrival order, which the
  /// backend sorts ascending by current stock (most-critical first).
  Map<String, List<LowStockMaterial>> get groupedBySupplier {
    final out = <String, List<LowStockMaterial>>{};
    for (final m in materials) {
      out.putIfAbsent(m.supplierId, () => []).add(m);
    }
    return out;
  }

  /// Seed map for `AddPOPage`'s create-mode `seedData`. The
  /// controller's `_prefill` already knows this shape — keys must
  /// match exactly (`supplierId`, `items[].rawMaterialId`).
  Map<String, dynamic> seedDataFor(String supplierId) {
    final rows = materials.where((m) => m.supplierId == supplierId);
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
