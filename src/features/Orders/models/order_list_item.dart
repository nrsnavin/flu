class OrderListItem {
  final String id;
  final int orderNo;
  final String customerName;
  final String status;
  final DateTime date;
  final DateTime supplyDate;

  OrderListItem({
    required this.id,
    required this.orderNo,
    required this.customerName,
    required this.status,
    required this.date,
    required this.supplyDate,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> json) {
    return OrderListItem(
      id: json["_id"],
      orderNo: json["orderNo"],
      customerName: json["customer"]["name"],
      status: json["status"],
      date: DateTime.parse(json["date"]),
      supplyDate: DateTime.parse(json["supplyDate"]),
    );
  }
}
