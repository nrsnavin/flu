// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL MODELS
//  File: lib/src/features/rawMaterial/models/raw_material_models.dart
// ══════════════════════════════════════════════════════════════

// ── Material Inward ───────────────────────────────────────────
class MaterialInwardModel {
  final String   id;
  final double   quantity;
  final DateTime inwardDate;
  final String   remarks;
  // PO reference
  final String?  poId;
  final String?  poNo;      // "PO #1045"
  final String?  poStatus;

  const MaterialInwardModel({
    required this.id,
    required this.quantity,
    required this.inwardDate,
    required this.remarks,
    this.poId,
    this.poNo,
    this.poStatus,
  });

  factory MaterialInwardModel.fromJson(Map<String, dynamic> j) {
    final po = j['purchaseOrder'];
    return MaterialInwardModel(
      id:         j['_id']?.toString()      ?? '',
      quantity:   (j['quantity'] as num?)?.toDouble() ?? 0,
      inwardDate: DateTime.tryParse(j['inwardDate']?.toString() ?? '')
          ?? DateTime.now(),
      remarks:    j['remarks']?.toString()  ?? '',
      poId:       po is Map ? po['_id']?.toString() : po?.toString(),
      poNo:       po is Map ? po['poNo']?.toString() : null,
      poStatus:   po is Map ? po['status']?.toString() : null,
    );
  }

  /// Human-readable reference label shown in the UI
  String get referenceLabel {
    if (poNo != null) return 'PO #$poNo';
    if (poId  != null) return 'PO';
    return 'Stock Inward';
  }
}

// ── Material Outward ──────────────────────────────────────────
class MaterialOutwardModel {
  final String   id;
  final double   quantity;
  final DateTime outwardDate;
  final String   type;      // ORDER_APPROVAL | JOB_CONSUMPTION | STOCK_ADJUST
  final String   remarks;
  // Order reference (ORDER_APPROVAL)
  final String?  orderId;
  final String?  orderNo;
  // Job reference (JOB_CONSUMPTION)
  final String?  jobId;
  final String?  jobOrderNo;

  const MaterialOutwardModel({
    required this.id,
    required this.quantity,
    required this.outwardDate,
    required this.type,
    required this.remarks,
    this.orderId,
    this.orderNo,
    this.jobId,
    this.jobOrderNo,
  });

  factory MaterialOutwardModel.fromJson(Map<String, dynamic> j) {
    final order = j['order'];
    final job   = j['job'];
    return MaterialOutwardModel(
      id:          j['_id']?.toString()          ?? '',
      quantity:    (j['quantity'] as num?)?.toDouble() ?? 0,
      outwardDate: DateTime.tryParse(j['outwardDate']?.toString() ?? '')
          ?? DateTime.now(),
      type:        j['type']?.toString()          ?? 'STOCK_ADJUST',
      remarks:     j['remarks']?.toString()        ?? '',
      orderId:     order is Map ? order['_id']?.toString() : order?.toString(),
      orderNo:     order is Map ? order['orderNo']?.toString() : null,
      jobId:       job   is Map ? job['_id']?.toString()   : job?.toString(),
      jobOrderNo:  job   is Map ? job['jobOrderNo']?.toString() : null,
    );
  }

  String get referenceLabel {
    switch (type) {
      case 'ORDER_APPROVAL':
        return orderNo != null ? 'Order #$orderNo' : 'Order Approval';
      case 'JOB_CONSUMPTION':
        return jobOrderNo != null ? 'Job #$jobOrderNo' : 'Job Issue';
      case 'STOCK_ADJUST':
        return 'Stock Adjustment';
      default:
        return type;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'ORDER_APPROVAL':   return 'Order Approval';
      case 'JOB_CONSUMPTION':  return 'Job Issue';
      case 'STOCK_ADJUST':     return 'Adjustment';
      default:                 return type;
    }
  }
}

// ── Price History ────────────────────────────────────────────
class PriceHistoryModel {
  final double   price;       // new price
  final double   oldPrice;    // previous price
  final DateTime changedAt;
  final String   reason;

  const PriceHistoryModel({
    required this.price,
    required this.oldPrice,
    required this.changedAt,
    required this.reason,
  });

  double get change => price - oldPrice;
  bool   get isIncrease => change > 0;

  factory PriceHistoryModel.fromJson(Map<String, dynamic> j) {
    return PriceHistoryModel(
      price:     (j['price']    as num?)?.toDouble() ?? 0,
      oldPrice:  (j['oldPrice'] as num?)?.toDouble() ?? 0,
      changedAt: DateTime.tryParse(j['changedAt']?.toString() ?? '')
          ?? DateTime.now(),
      reason:    j['reason']?.toString() ?? '',
    );
  }
}

// ── Stock Movement (running balance log) ──────────────────────
class StockMovementModel {
  final DateTime date;
  final String   type;
  final double   quantity;
  final double   balance;
  final String?  orderId;
  final String?  orderNo;

  const StockMovementModel({
    required this.date,
    required this.type,
    required this.quantity,
    required this.balance,
    this.orderId,
    this.orderNo,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> j) {
    final order = j['order'];
    return StockMovementModel(
      date:     DateTime.tryParse(j['date']?.toString() ?? '')
          ?? DateTime.now(),
      type:     j['type']?.toString()     ?? '',
      quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
      balance:  (j['balance']  as num?)?.toDouble() ?? 0,
      orderId:  order is Map ? order['_id']?.toString() : order?.toString(),
      orderNo:  order is Map ? order['orderNo']?.toString() : null,
    );
  }

  bool get isInward => type == 'PO_INWARD' ||
      (type == 'STOCK_ADJUST' && quantity > 0);
}

// ── Full Material Detail ──────────────────────────────────────
class RawMaterialDetailModel {
  final String   id;
  final String   name;
  final String   category;
  final double   stock;
  final double   minStock;
  final double   price;
  final String?  supplierName;
  final DateTime? createdAt;

  final List<MaterialInwardModel>  inwards;
  final List<MaterialOutwardModel> outwards;
  final List<StockMovementModel>   stockMovements;
  final List<PriceHistoryModel>    priceHistory;

  const RawMaterialDetailModel({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.minStock,
    required this.price,
    this.supplierName,
    this.createdAt,
    this.inwards        = const [],
    this.outwards       = const [],
    this.stockMovements = const [],
    this.priceHistory   = const [],
  });

  bool get isLowStock => stock <= minStock && minStock > 0;

  double get totalInward =>
      inwards.fold(0, (s, i) => s + i.quantity);
  double get totalOutward =>
      outwards.fold(0, (s, o) => s + o.quantity);

  factory RawMaterialDetailModel.fromJson(Map<String, dynamic> j) {
    final supplier = j['supplier'];
    return RawMaterialDetailModel(
      id:           j['_id']?.toString()            ?? '',
      name:         j['name']?.toString()            ?? '',
      category:     j['category']?.toString()        ?? '',
      stock:        (j['stock']    as num?)?.toDouble() ?? 0,
      minStock:     (j['minStock'] as num?)?.toDouble() ?? 0,
      price:        (j['price']    as num?)?.toDouble() ?? 0,
      supplierName: supplier is Map ? supplier['name']?.toString() : null,
      createdAt:    DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      inwards:  (j['inwards']  as List? ?? [])
          .map((e) => MaterialInwardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      outwards: (j['outwards'] as List? ?? [])
          .map((e) => MaterialOutwardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      stockMovements: (j['stockMovements'] as List? ?? [])
          .map((e) => StockMovementModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      priceHistory: (j['priceHistory'] as List? ?? [])
          .map((e) => PriceHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}