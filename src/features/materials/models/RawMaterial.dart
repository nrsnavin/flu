// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL MODELS — unified single file
// ══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  RawMaterialListItem  (list page card)
//
//  FIX: original RawMaterialListModel had no null guards on
//       any field. If name/category were missing the cast to
//       String throws. Now all fields are null-safe.
//  FIX: no supplierName in list model → added so it can be
//       shown in the card without a separate call.
// ─────────────────────────────────────────────────────────────

class RawMaterialListItem {
  final String id;
  final String name;
  final String category;
  final double stock;
  final double minStock;
  final double price;
  final double totalConsumption;
  final String? supplierName;

  const RawMaterialListItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.minStock,
    required this.price,
    required this.totalConsumption,
    this.supplierName,
  });

  factory RawMaterialListItem.fromJson(Map<String, dynamic> json) {
    final sup = json['supplier'];
    return RawMaterialListItem(
      id:               json['_id']?.toString()              ?? '',
      name:             json['name']?.toString()             ?? '—',
      category:         json['category']?.toString()         ?? '—',
      stock:            (json['stock']            as num?)?.toDouble() ?? 0.0,
      minStock:         (json['minStock']         as num?)?.toDouble() ?? 0.0,
      price:            (json['price']            as num?)?.toDouble() ?? 0.0,
      totalConsumption: (json['totalConsumption'] as num?)?.toDouble() ?? 0.0,
      supplierName:     sup is Map ? sup['name']?.toString() : null,
    );
  }

  bool get isLowStock => stock <= minStock && minStock > 0;
  double get stockPercent =>
      minStock > 0 ? (stock / (minStock * 2)).clamp(0.0, 1.0) : 1.0;
}

// ─────────────────────────────────────────────────────────────
//  RawMaterialDetail  (detail page)
//
//  BUGS FIXED:
//  1. detail_model.dart: `SupplierMiniModel.fromJson(json["supplier"])`
//     crashes when supplier is null (no supplier set) OR an un-
//     populated ObjectId string. Zero null guard.
//  2. model.dart: `supplierId: json['supplier'] ?? ""`  when the
//     detail endpoint populates supplier as {_id,name} object →
//     the string cast returns "[object]".
//  3. Both detail_model.dart and model.dart define separate
//     classes for essentially the same thing — confusing and
//     the detail controller used RawMaterialModel (from model.dart)
//     while RawMaterialDetailModel (detail_model.dart) was defined
//     but never used at all.
//  4. RawMaterial.js schema has NO `price` field — added to
//     schema in the fixed rawMaterial.js. Model now parses it
//     safely with a 0.0 default.
// ─────────────────────────────────────────────────────────────

class RawMaterialDetail {
  final String id;
  final String name;
  final String category;
  final double stock;
  final double minStock;
  final double price;
  final double totalConsumption;
  final SupplierInfo? supplier;
  final List<StockMovement> stockMovements;
  final List<MaterialInward> inwards;
  final List<MaterialOutward> outwards;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RawMaterialDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.minStock,
    required this.price,
    required this.totalConsumption,
    this.supplier,
    required this.stockMovements,
    required this.inwards,
    required this.outwards,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RawMaterialDetail.fromJson(Map<String, dynamic> json) {
    // FIX: supplier may be null, a string ObjectId, or a populated object
    SupplierInfo? supplier;
    final rawSup = json['supplier'];
    if (rawSup is Map) {
      supplier = SupplierInfo.fromJson(rawSup as Map<String, dynamic>);
    }

    return RawMaterialDetail(
      id:               json['_id']?.toString()              ?? '',
      name:             json['name']?.toString()             ?? '—',
      category:         json['category']?.toString()         ?? '—',
      stock:            (json['stock']            as num?)?.toDouble() ?? 0.0,
      minStock:         (json['minStock']         as num?)?.toDouble() ?? 0.0,
      price:            (json['price']            as num?)?.toDouble() ?? 0.0,
      totalConsumption: (json['totalConsumption'] as num?)?.toDouble() ?? 0.0,
      supplier:         supplier,
      stockMovements: (json['stockMovements'] as List? ?? [])
          .map((e) => StockMovement.fromJson(e as Map<String, dynamic>))
          .toList(),
      inwards: (json['inwards'] as List? ?? [])
          .map((e) => MaterialInward.fromJson(e as Map<String, dynamic>))
          .toList(),
      outwards: (json['outwards'] as List? ?? [])
          .map((e) => MaterialOutward.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isLowStock => stock <= minStock && minStock > 0;
  double get stockPercent =>
      minStock > 0 ? (stock / (minStock * 2)).clamp(0.0, 1.0) : 1.0;
}

// ─────────────────────────────────────────────────────────────
//  SupplierInfo
// ─────────────────────────────────────────────────────────────

class SupplierInfo {
  final String id;
  final String name;

  const SupplierInfo({required this.id, required this.name});

  factory SupplierInfo.fromJson(Map<String, dynamic> json) {
    return SupplierInfo(
      id:   json['_id']?.toString()  ?? '',
      name: json['name']?.toString() ?? '—',
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  StockMovement  (embedded in RawMaterial)
// ─────────────────────────────────────────────────────────────

class StockMovement {
  final DateTime date;
  final String type;    // ORDER_APPROVAL | PO_INWARD | ADJUSTMENT
  final String? orderId;
  final int? orderNo;
  final double quantity;
  final double balance;

  const StockMovement({
    required this.date,
    required this.type,
    this.orderId,
    this.orderNo,
    required this.quantity,
    required this.balance,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    return StockMovement(
      date:     DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      type:     json['type']?.toString() ?? '—',
      orderId:  order is Map
          ? order['_id']?.toString()
          : order?.toString(),
      orderNo:  order is Map
          ? (order['orderNo'] as num?)?.toInt()
          : null,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      balance:  (json['balance']  as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Positive = inward, negative = outward
  bool get isInward =>
      type == 'PO_INWARD' || type == 'ADJUSTMENT' && quantity > 0;
}

// ─────────────────────────────────────────────────────────────
//  MaterialInward  (separate MaterialInward collection)
// ─────────────────────────────────────────────────────────────

class MaterialInward {
  final String id;
  final double quantity;
  final DateTime inwardDate;
  final String? remarks;
  final String? poNo;
  final String? poId;

  const MaterialInward({
    required this.id,
    required this.quantity,
    required this.inwardDate,
    this.remarks,
    this.poNo,
    this.poId,
  });

  factory MaterialInward.fromJson(Map<String, dynamic> json) {
    final po = json['purchaseOrder'];
    return MaterialInward(
      id:         json['_id']?.toString() ?? '',
      quantity:   (json['quantity'] as num?)?.toDouble() ?? 0.0,
      inwardDate: DateTime.tryParse(json['inwardDate']?.toString() ?? '') ??
          DateTime.now(),
      remarks:    json['remarks']?.toString(),
      poId:       po is Map ? po['_id']?.toString()  : po?.toString(),
      poNo:       po is Map ? po['poNo']?.toString()  : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MaterialOutward  (separate MaterialOutward collection)
// ─────────────────────────────────────────────────────────────

class MaterialOutward {
  final String id;
  final double quantity;
  final DateTime outwardDate;
  final String? remarks;
  final String? jobId;
  final double? cost;

  const MaterialOutward({
    required this.id,
    required this.quantity,
    required this.outwardDate,
    this.remarks,
    this.jobId,
    this.cost,
  });

  factory MaterialOutward.fromJson(Map<String, dynamic> json) {
    final job = json['job'];
    return MaterialOutward(
      id:          json['_id']?.toString() ?? '',
      quantity:    (json['quantity']   as num?)?.toDouble() ?? 0.0,
      outwardDate: DateTime.tryParse(json['outwardDate']?.toString() ?? '') ??
          DateTime.now(),
      remarks:     json['remarks']?.toString(),
      jobId:       job is Map ? job['_id']?.toString() : job?.toString(),
      cost:        (json['cost'] as num?)?.toDouble(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SupplierDropdownItem  (Add Material / Raise PO dropdowns)
// ─────────────────────────────────────────────────────────────

class SupplierDropdownItem {
  final String id;
  final String name;

  const SupplierDropdownItem({required this.id, required this.name});

  factory SupplierDropdownItem.fromJson(Map<String, dynamic> json) {
    return SupplierDropdownItem(
      id:   json['_id']?.toString()  ?? '',
      name: json['name']?.toString() ?? '—',
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RaisePOPayload  (sent to /raise-po endpoint)
// ─────────────────────────────────────────────────────────────

class RaisePOPayload {
  final String materialId;
  final String supplierId;
  final double quantity;
  final double price;

  const RaisePOPayload({
    required this.materialId,
    required this.supplierId,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'items': [
      {
        'rawMaterial': materialId,
        'quantity':    quantity,
        'price':       price,
      }
    ],
    'supplier': supplierId,
  };
}