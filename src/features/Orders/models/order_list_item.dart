class OrderListItem {
  final String id;
  final int orderNo;
  final String customerName;
  final String status;
  final DateTime date;
  final DateTime supplyDate;
  final String? createdByName;
  final String? createdByRole;

  OrderListItem({
    required this.id,
    required this.orderNo,
    required this.customerName,
    required this.status,
    required this.date,
    required this.supplyDate,
    this.createdByName,
    this.createdByRole,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> json) {
    final createdBy = json["createdBy"];
    return OrderListItem(
      id:           json["_id"],
      orderNo:      json["orderNo"],
      customerName: json["customer"]["name"],
      status:       json["status"],
      date:         DateTime.parse(json["date"]),
      supplyDate:   DateTime.parse(json["supplyDate"]),
      createdByName: createdBy is Map ? createdBy["name"] as String? : null,
      createdByRole: createdBy is Map ? createdBy["role"] as String? : null,
    );
  }
}
