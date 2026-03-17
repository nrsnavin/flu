
class PurchaseItem {
  String rawMaterialId;
  String name;
  double price;
  double quantity;

  PurchaseItem({
    required this.rawMaterialId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    "rawMaterial": rawMaterialId,
    "price": price,
    "quantity": quantity,
  };
}

class PurchaseOrderModel {
  String supplierId;
  List<PurchaseItem> items;

  PurchaseOrderModel({
    required this.supplierId,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    "supplier": supplierId,
    "items": items.map((e) => e.toJson()).toList(),
  };
}
