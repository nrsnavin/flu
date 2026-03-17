import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════
//  DELIVERY CHALLAN  —  Dart models
// ════════════════════════════════════════════════════════════════

// ── DC item (one line in the challan) ────────────────────────
class DCItem {
  final String? elasticId;
  final String? elasticName; // elastic type
  final String? description; // machine-part type
  final String  unit;
  final double  quantity;
  final double  rate;
  final double  amount;

  const DCItem({
    this.elasticId,
    this.elasticName,
    this.description,
    this.unit     = "m",
    required this.quantity,
    this.rate   = 0,
    this.amount = 0,
  });

  String get displayName => elasticName ?? description ?? "—";

  factory DCItem.fromJson(Map<String, dynamic> j) {
    final raw = j["elastic"];
    String? eId, eName;
    if (raw is Map) {
      eId   = raw["_id"]?.toString();
      eName = raw["name"]?.toString();
    } else {
      eId = raw?.toString();
    }
    eName ??= j["elasticName"]?.toString();

    return DCItem(
      elasticId:   eId,
      elasticName: eName,
      description: j["description"]?.toString(),
      unit:        j["unit"]?.toString()     ?? "m",
      quantity:    (j["quantity"] ?? 0).toDouble(),
      rate:        (j["rate"]     ?? 0).toDouble(),
      amount:      (j["amount"]   ?? 0).toDouble(),
    );
  }
}

// ── DC list card model (no items — used in list view) ─────────
class DCListItem {
  final String  id;
  final String  dcNumber;
  final String  type;
  final String  financialYear;
  final String  customerName;
  final int?    orderNo;
  final String  status;
  final String  dispatchDate;
  final double  totalAmount;
  final double  totalQuantity;

  const DCListItem({
    required this.id,
    required this.dcNumber,
    required this.type,
    required this.financialYear,
    required this.customerName,
    this.orderNo,
    required this.status,
    required this.dispatchDate,
    required this.totalAmount,
    required this.totalQuantity,
  });

  bool get isElastic     => type == "elastic";
  bool get isMachinePart => type == "machine_part";

  factory DCListItem.fromJson(Map<String, dynamic> j) => DCListItem(
    id:            j["_id"].toString(),
    dcNumber:      j["dcNumber"]?.toString()       ?? "—",
    type:          j["type"]?.toString()           ?? "elastic",
    financialYear: j["financialYear"]?.toString()  ?? "",
    customerName:  j["customerName"]?.toString()   ?? "—",
    orderNo:       j["orderNo"] as int?,
    status:        j["status"]?.toString()         ?? "draft",
    dispatchDate:  j["dispatchDate"]?.toString()   ?? "",
    totalAmount:   (j["totalAmount"]   ?? 0).toDouble(),
    totalQuantity: (j["totalQuantity"] ?? 0).toDouble(),
  );
}

// ── DC full detail ────────────────────────────────────────────
class DCDetail {
  final String       id;
  final String       dcNumber;
  final String       type;
  final String       financialYear;
  final int          sequence;
  final int?         orderNo;
  final String       customerName;
  final String       customerPhone;
  final String       customerGstin;
  final String       customerAddress;
  final String       dispatchDate;
  final String       vehicleNo;
  final String       driverName;
  final String       transporter;
  final String       lrNumber;
  final List<DCItem> items;
  final double       totalQuantity;
  final double       totalAmount;
  final String       remarks;
  final String       status;
  final String       createdAt;

  const DCDetail({
    required this.id,
    required this.dcNumber,
    required this.type,
    required this.financialYear,
    required this.sequence,
    this.orderNo,
    required this.customerName,
    required this.customerPhone,
    required this.customerGstin,
    required this.customerAddress,
    required this.dispatchDate,
    required this.vehicleNo,
    required this.driverName,
    required this.transporter,
    required this.lrNumber,
    required this.items,
    required this.totalQuantity,
    required this.totalAmount,
    required this.remarks,
    required this.status,
    required this.createdAt,
  });

  bool get isElastic     => type == "elastic";
  bool get isMachinePart => type == "machine_part";

  factory DCDetail.fromJson(Map<String, dynamic> j) => DCDetail(
    id:              j["_id"].toString(),
    dcNumber:        j["dcNumber"]?.toString()       ?? "—",
    type:            j["type"]?.toString()           ?? "elastic",
    financialYear:   j["financialYear"]?.toString()  ?? "",
    sequence:        (j["sequence"] ?? 0) as int,
    orderNo:         j["orderNo"] as int?,
    customerName:    j["customerName"]?.toString()    ?? "—",
    customerPhone:   j["customerPhone"]?.toString()   ?? "",
    customerGstin:   j["customerGstin"]?.toString()   ?? "",
    customerAddress: j["customerAddress"]?.toString() ?? "",
    dispatchDate:    j["dispatchDate"]?.toString()    ?? "",
    vehicleNo:       j["vehicleNo"]?.toString()       ?? "",
    driverName:      j["driverName"]?.toString()      ?? "",
    transporter:     j["transporter"]?.toString()     ?? "",
    lrNumber:        j["lrNumber"]?.toString()        ?? "",
    items:           (j["items"] as List? ?? [])
        .map((e) => DCItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalQuantity:   (j["totalQuantity"] ?? 0).toDouble(),
    totalAmount:     (j["totalAmount"]   ?? 0).toDouble(),
    remarks:         j["remarks"]?.toString()   ?? "",
    status:          j["status"]?.toString()    ?? "draft",
    createdAt:       j["createdAt"]?.toString() ?? "",
  );
}

// ── Order info from /dc/order-info ────────────────────────────
class OrderInfoForDC {
  final int    orderNo;
  final String customerName;
  final String customerPhone;
  final String customerGstin;
  final String customerContact;
  final List<OrderElasticOption> elastics;

  const OrderInfoForDC({
    required this.orderNo,
    required this.customerName,
    required this.customerPhone,
    required this.customerGstin,
    required this.customerContact,
    required this.elastics,
  });

  factory OrderInfoForDC.fromJson(Map<String, dynamic> j) => OrderInfoForDC(
    orderNo:         (j["orderNo"] ?? 0) as int,
    customerName:    j["customer"]?["name"]?.toString()    ?? "",
    customerPhone:   j["customer"]?["phone"]?.toString()   ?? "",
    customerGstin:   j["customer"]?["gstin"]?.toString()   ?? "",
    customerContact: j["customer"]?["contact"]?.toString() ?? "",
    elastics: (j["elastics"] as List? ?? [])
        .map((e) => OrderElasticOption.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class OrderElasticOption {
  final String elasticId;
  final String elasticName;
  final String weaveType;
  final double orderedQty;

  const OrderElasticOption({
    required this.elasticId,
    required this.elasticName,
    required this.weaveType,
    required this.orderedQty,
  });

  factory OrderElasticOption.fromJson(Map<String, dynamic> j) =>
      OrderElasticOption(
        elasticId:   j["elasticId"]?.toString()   ?? "",
        elasticName: j["elasticName"]?.toString() ?? "",
        weaveType:   j["weaveType"]?.toString()   ?? "",
        orderedQty:  (j["orderedQty"] ?? 0).toDouble(),
      );
}

// ── Editable item row (used in the Add DC form) ───────────────
class EditableDCItem {
  // Set at creation for elastic rows; null for machine-part rows
  final String? elasticId;
  final String? elasticName;

  // User-typed fields
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController qtyCtrl  = TextEditingController();
  final TextEditingController rateCtrl = TextEditingController();
  String unit = "m";

  EditableDCItem.elastic({
    required this.elasticId,
    required this.elasticName,
    double? prefilledQty,
  }) {
    unit = "m";
    if ((prefilledQty ?? 0) > 0) {
      qtyCtrl.text = prefilledQty!.toStringAsFixed(0);
    }
  }

  EditableDCItem.machinePart()
      : elasticId   = null,
        elasticName = null {
    unit = "pcs";
  }

  double get qty    => double.tryParse(qtyCtrl.text)  ?? 0;
  double get rate   => double.tryParse(rateCtrl.text) ?? 0;
  double get amount => qty * rate;

  Map<String, dynamic> toPayload() {
    if (elasticId != null) {
      return {
        "elastic":     elasticId,
        "elasticName": elasticName,
        "unit":        unit,
        "quantity":    qty,
        "rate":        rate,
      };
    }
    return {
      "description": descCtrl.text.trim(),
      "unit":        unit,
      "quantity":    qty,
      "rate":        rate,
    };
  }

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}