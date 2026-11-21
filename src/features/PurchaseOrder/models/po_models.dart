import 'po_tax.dart';

// ─── Lightweight reference model used in dropdowns ─────────
class SupplierMini {
  final String id;
  final String name;
  final String? phone;
  final String? gstin;
  /// regular | composition | unregistered — the last two charge no GST.
  final String? gstRegistration;

  SupplierMini({required this.id, required this.name, this.phone, this.gstin, this.gstRegistration});

  factory SupplierMini.fromJson(Map<String, dynamic> j) => SupplierMini(
    id: j["_id"] ?? "",
    name: j["name"] ?? "",
    phone: j["phoneNumber"],
    gstin: j["gstin"],
    gstRegistration: j["gstRegistration"]?.toString(),
  );
}

class MaterialMini {
  final String id;
  final String name;
  final String? unit;
  final String? defaultSupplierId;
  final String? defaultSupplierName;
  /// What a PO line for it takes unless the line says otherwise.
  final String hsn;
  /// null: the default rate in Settings.
  final double? gstPercent;

  MaterialMini({
    required this.id,
    required this.name,
    this.unit,
    this.defaultSupplierId,
    this.defaultSupplierName,
    this.hsn = "",
    this.gstPercent,
  });

  factory MaterialMini.fromJson(Map<String, dynamic> j) {
    // supplier may arrive populated (Map), as a raw ObjectId string,
    // or absent entirely. Only the populated form gives us a name.
    final sup = j["supplier"];
    String? supId;
    String? supName;
    if (sup is Map) {
      supId   = sup["_id"]?.toString();
      supName = sup["name"]?.toString();
    } else if (sup is String && sup.isNotEmpty) {
      supId = sup;
    }
    return MaterialMini(
      id:                  j["_id"] ?? j["id"] ?? "",
      name:                j["name"] ?? "",
      unit:                j["unit"],
      defaultSupplierId:   supId,
      defaultSupplierName: supName,
      hsn:                 j["hsn"]?.toString() ?? "",
      gstPercent:          (j["gstPercent"] as num?)?.toDouble(),
    );
  }
}

// ─── A single line item inside a PO ─────────────────────────
class POItem {
  final MaterialMini? rawMaterial;
  final double price;
  final double quantity;
  final double receivedQuantity;
  /// The line's GST, as the detail route sends it: the rate it is priced
  /// at (its own, else its material's, else the default) and the tax.
  final String hsn;
  final double? gstPercent;
  final double? taxable;
  final double taxAmount;
  /// The line with its GST; null when the server did not price it.
  final double? amount;

  POItem({
    this.rawMaterial,
    required this.price,
    required this.quantity,
    required this.receivedQuantity,
    this.hsn = "",
    this.gstPercent,
    this.taxable,
    this.taxAmount = 0,
    this.amount,
  });

  double get pendingQuantity => (quantity - receivedQuantity).clamp(0, double.infinity);
  double get totalValue => price * quantity;
  bool get isFullyReceived => receivedQuantity >= quantity;

  factory POItem.fromJson(Map<String, dynamic> j) {
    final rm = j["rawMaterial"];
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return POItem(
      rawMaterial: rm is Map<String, dynamic> ? MaterialMini.fromJson(rm) : null,
      price: (j["price"] ?? 0).toDouble(),
      quantity: (j["quantity"] ?? 0).toDouble(),
      receivedQuantity: (j["receivedQuantity"] ?? 0).toDouble(),
      hsn: j["hsn"]?.toString() ?? "",
      gstPercent: (j["gstPercent"] as num?)?.toDouble(),
      taxable: (j["taxable"] as num?)?.toDouble(),
      taxAmount: n("cgst") + n("sgst") + n("igst"),
      amount: (j["amount"] as num?)?.toDouble(),
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
  // Mongo document version — sent back as expectedVersion on edits so
  // the server can 409 when someone else saved in between.
  final int version;
  /// What it comes to with GST, worked out by the server; null from a
  /// route that does not price it.
  final PoTax? tax;

  POModel({
    required this.id,
    required this.poNo,
    required this.date,
    this.supplier,
    required this.items,
    required this.status,
    this.version = 0,
    this.tax,
  });

  double get totalOrderValue =>
      items.fold(0, (sum, i) => sum + i.totalValue);

  double get totalPendingValue => items.fold(
    0,
        (sum, i) => sum + i.price * i.pendingQuantity,
  );

  factory POModel.fromJson(Map<String, dynamic> j) {
    final sup = j["supplier"];
    final items = (j["items"] as List? ?? []).map((e) => POItem.fromJson(e)).toList();
    final tax = j["tax"];
    // The rate in the labels when every taxed line carries the same one.
    final rates = items.where((i) => (i.taxable ?? 0) > 0 && i.gstPercent != null).map((i) => i.gstPercent!).toSet();
    return POModel(
      id: j["_id"] ?? "",
      poNo: j["poNo"] ?? 0,
      date: DateTime.tryParse(j["date"]?.toString() ?? '') ?? DateTime.now(),
      supplier: sup is Map<String, dynamic> ? SupplierMini.fromJson(sup) : null,
      items: items,
      status: j["status"] ?? "Open",
      version: (j["__v"] as num?)?.toInt() ?? 0,
      tax: tax is Map ? PoTax.fromJson(tax.cast<String, dynamic>(), rate: rates.length == 1 ? rates.first : null) : null,
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
      // The same goods at the same rates, GST included.
      "hsn": i.hsn,
      "gstPercent": i.gstPercent,
    })
        .toList(),
  };

  /// Convert to a map for editing
  Map<String, dynamic> toEditData() => {
    "_id": id,
    "expectedVersion": version,
    "supplierId": supplier?.id,
    "supplierName": supplier?.name,
    "items": items
        .map((i) => {
      "rawMaterialId": i.rawMaterial?.id,
      "rawMaterialName": i.rawMaterial?.name,
      "price": i.price,
      "quantity": i.quantity,
      "receivedQuantity": i.receivedQuantity,
      // Carried through, so saving an edit does not put a typed rate
      // back to the material's.
      "hsn": i.hsn,
      "gstPercent": i.gstPercent,
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
      inwardDate: DateTime.tryParse(j["inwardDate"]?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      remarks: j["remarks"],
    );
  }
}