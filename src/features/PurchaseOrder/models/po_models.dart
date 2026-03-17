// ─── Lightweight reference model used in dropdowns ─────────
class SupplierMini {
  final String id;
  final String name;
  final String? phone;
  final String? gstin;

  SupplierMini({required this.id, required this.name, this.phone, this.gstin});

  factory SupplierMini.fromJson(Map<String, dynamic> j) => SupplierMini(
    id: j["_id"] ?? "",
    name: j["name"] ?? "",
    phone: j["phoneNumber"],
    gstin: j["gstin"],
  );
}

class MaterialMini {
  final String id;
  final String name;
  final String? unit;

  MaterialMini({required this.id, required this.name, this.unit});

  factory MaterialMini.fromJson(Map<String, dynamic> j) => MaterialMini(
    id: j["_id"] ?? j["id"] ?? "",
    name: j["name"] ?? "",
    unit: j["unit"],
  );
}

// ─── A single line item inside a PO ─────────────────────────
class POItem {
  final MaterialMini? rawMaterial;
  final double price;
  final double quantity;
  final double receivedQuantity;

  POItem({
    this.rawMaterial,
    required this.price,
    required this.quantity,
    required this.receivedQuantity,
  });

  double get pendingQuantity => (quantity - receivedQuantity).clamp(0, double.infinity);
  double get totalValue => price * quantity;
  bool get isFullyReceived => receivedQuantity >= quantity;

  factory POItem.fromJson(Map<String, dynamic> j) {
    final rm = j["rawMaterial"];
    return POItem(
      rawMaterial: rm is Map<String, dynamic> ? MaterialMini.fromJson(rm) : null,
      price: (j["price"] ?? 0).toDouble(),
      quantity: (j["quantity"] ?? 0).toDouble(),
      receivedQuantity: (j["receivedQuantity"] ?? 0).toDouble(),
    );
  }
}

// ─── Full Purchase Order model ───────────────────────────────
class POModel {
  final String id;
  final int poNo;
  final DateTime date;
  final SupplierMini? supplier;
  final List<POItem> items;
  final String status; // Open | Partial | Completed

  POModel({
    required this.id,
    required this.poNo,
    required this.date,
    this.supplier,
    required this.items,
    required this.status,
  });

  double get totalOrderValue =>
      items.fold(0, (sum, i) => sum + i.totalValue);

  double get totalPendingValue => items.fold(
    0,
        (sum, i) => sum + i.price * i.pendingQuantity,
  );

  factory POModel.fromJson(Map<String, dynamic> j) {
    final sup = j["supplier"];
    return POModel(
      id: j["_id"] ?? "",
      poNo: j["poNo"] ?? 0,
      date: j["date"] != null ? DateTime.parse(j["date"]) : DateTime.now(),
      supplier: sup is Map<String, dynamic> ? SupplierMini.fromJson(sup) : null,
      items: (j["items"] as List? ?? []).map((e) => POItem.fromJson(e)).toList(),
      status: j["status"] ?? "Open",
    );
  }

  /// Convert to a map that can be passed as cloneData to AddPO screen
  Map<String, dynamic> toCloneData() => {
    "supplierId": supplier?.id,
    "supplierName": supplier?.name,
    "items": items
        .map((i) => {
      "rawMaterialId": i.rawMaterial?.id,
      "rawMaterialName": i.rawMaterial?.name,
      "price": i.price,
      "quantity": i.quantity,
    })
        .toList(),
  };

  /// Convert to a map for editing
  Map<String, dynamic> toEditData() => {
    "_id": id,
    "supplierId": supplier?.id,
    "supplierName": supplier?.name,
    "items": items
        .map((i) => {
      "rawMaterialId": i.rawMaterial?.id,
      "rawMaterialName": i.rawMaterial?.name,
      "price": i.price,
      "quantity": i.quantity,
      "receivedQuantity": i.receivedQuantity,
    })
        .toList(),
  };
}

// ─── Inward history record ────────────────────────────────────
class InwardRecord {
  final String id;
  final MaterialMini? rawMaterial;
  final double quantity;
  final DateTime inwardDate;
  final String? remarks;

  InwardRecord({
    required this.id,
    this.rawMaterial,
    required this.quantity,
    required this.inwardDate,
    this.remarks,
  });

  factory InwardRecord.fromJson(Map<String, dynamic> j) {
    final rm = j["rawMaterial"];
    return InwardRecord(
      id: j["_id"] ?? "",
      rawMaterial:
      rm is Map<String, dynamic> ? MaterialMini.fromJson(rm) : null,
      quantity: (j["quantity"] ?? 0).toDouble(),
      inwardDate: j["inwardDate"] != null
          ? DateTime.parse(j["inwardDate"])
          : DateTime.now(),
      remarks: j["remarks"],
    );
  }
}