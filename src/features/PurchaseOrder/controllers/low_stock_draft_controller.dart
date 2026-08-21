import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

/// One flagged material from `GET /materials/replenishment-forecast`.
/// This is the forecast-driven successor to the reactive `/low-stock`
/// list: it factors committed demand from the Open-order pipeline plus
/// a trailing run-rate over a horizon, not just the current floor.
class LowStockMaterial {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double stock;        // on-hand
  final double minStock;
  final double price;
  final double suggestedQty;
  final double estimatedCost;
  final double runRatePerDay;
  final double committedDemand;
  final double projectedStock;
  final String severity;     // "critical" | "warn"
  final String supplierId;
  final String supplierName;

  /// Days until on-hand (net of committed demand) runs out at the
  /// trailing run-rate. `null` when there's no measurable run-rate.
  final double? daysToStockout;

  const LowStockMaterial({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.price,
    required this.suggestedQty,
    required this.estimatedCost,
    required this.runRatePerDay,
    required this.committedDemand,
    required this.projectedStock,
    required this.severity,
    required this.supplierId,
    required this.supplierName,
    this.daysToStockout,
  });

  bool get isCritical => severity == 'critical';

  factory LowStockMaterial.fromJson(Map<String, dynamic> j) {
    final sup = j['supplier'] as Map?;
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return LowStockMaterial(
      id:              j['_id']?.toString() ?? '',
      name:            j['name']?.toString() ?? '—',
      category:        j['category']?.toString() ?? '',
      unit:            j['unit']?.toString() ?? '',
      stock:           d(j['onHand']),
      minStock:        d(j['minStock']),
      price:           d(j['price']),
      suggestedQty:    d(j['suggestedQty']),
      estimatedCost:   d(j['estimatedCost']),
      runRatePerDay:   d(j['runRatePerDay']),
      committedDemand: d(j['committedDemand']),
      projectedStock:  d(j['projectedStock']),
      severity:        j['severity']?.toString() ?? 'warn',
      supplierId:      sup?['_id']?.toString()  ?? '',
      supplierName:    sup?['name']?.toString() ?? '—',
      daysToStockout:  (j['daysToStockout'] as num?)?.toDouble(),
    );
  }

  double get suggestedValue => estimatedCost > 0 ? estimatedCost : price * suggestedQty;

  /// 0.0 = empty, 1.0 = at-or-above (minStock * 2). Mirrors
  /// `RawMaterialListItem.stockPercent` so the bar reads identically.
  double get stockPercent =>
      minStock > 0 ? (stock / (minStock * 2)).clamp(0.0, 1.0) : 1.0;
}

/// Pulls the forecast-driven replenishment list and groups it by
/// supplier so the page can render one "Draft PO" button per supplier.
class LowStockDraftController extends GetxController {
  /// Materials projected to breach their safety floor within the horizon.
  final materials         = <LowStockMaterial>[].obs;

  final skippedNoSupplier = 0.obs;
  final loading           = false.obs;
  final errorMsg          = Rxn<String>();

  // Forecast controls / narrative.
  final horizon    = 14.obs;      // days
  final aiSummary  = Rxn<String>();
  final flaggedN   = 0.obs;
  final criticalN  = 0.obs;
  final suppliersN = 0.obs;
  final estSpend   = 0.0.obs;

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/materials',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  void setHorizon(int days) {
    if (horizon.value == days) return;
    horizon.value = days;
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get(
        '/replenishment-forecast',
        queryParameters: {'horizonDays': horizon.value},
      );
      final data = res.data is Map ? res.data as Map : {};

      final list = (data['materials'] as List?) ?? const [];
      materials.assignAll(
        list.whereType<Map>().map(
              (m) => LowStockMaterial.fromJson(Map<String, dynamic>.from(m)),
            ),
      );
      skippedNoSupplier.value = (data['skippedNoSupplier'] as num?)?.toInt() ?? 0;

      final totals = Map<String, dynamic>.from(data['totals'] ?? {});
      flaggedN.value   = (totals['flagged']  as num?)?.toInt() ?? materials.length;
      criticalN.value  = (totals['critical'] as num?)?.toInt() ?? 0;
      suppliersN.value = (totals['suppliers'] as num?)?.toInt() ?? 0;
      estSpend.value   = (totals['estimatedCost'] as num?)?.toDouble() ?? 0;

      final s = data['aiSummary']?.toString();
      aiSummary.value = (s != null && s.trim().isNotEmpty) ? s.trim() : null;
    } catch (e) {
      errorMsg.value = 'Could not load replenishment forecast';
    } finally {
      loading.value = false;
    }
  }

  /// supplierId → materials. Used by the page's grouped Draft PO buttons.
  Map<String, List<LowStockMaterial>> get groupedBySupplier {
    final out = <String, List<LowStockMaterial>>{};
    for (final m in materials) {
      out.putIfAbsent(m.supplierId, () => []).add(m);
    }
    return out;
  }

  /// Seed map for `AddPOPage`'s create-mode `seedData`. Keys must match
  /// exactly (`supplierId`, `items[].rawMaterialId`).
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
