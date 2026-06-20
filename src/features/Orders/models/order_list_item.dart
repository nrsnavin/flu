class OrderListItem {
  final String id;
  final int orderNo;
  final String customerName;
  final String status;
  final DateTime date;
  final DateTime supplyDate;
  // User fingerprint — populated by the backend audit plugin.
  // Null on legacy rows created before fingerprinting was introduced.
  final String? createdByName;
  final String? createdByRole;
  final String? updatedByName;
  final String? updatedByRole;
  // Approval provenance — populated by the backend on /approve.
  //   "admin"     → approved from the admin app
  //   "whatsapp"  → owner replied APPROVE to a WhatsApp ping
  // Null on orders approved before the field shipped.
  final String? approvalVia;
  final String? approvalWhatsappFrom; // E.164 of the WhatsApp sender

  OrderListItem({
    required this.id,
    required this.orderNo,
    required this.customerName,
    required this.status,
    required this.date,
    required this.supplyDate,
    this.createdByName,
    this.createdByRole,
    this.updatedByName,
    this.updatedByRole,
    this.approvalVia,
    this.approvalWhatsappFrom,
  });

  bool get approvedViaWhatsapp => approvalVia == "whatsapp";

  factory OrderListItem.fromJson(Map<String, dynamic> json) {
    final created = json["createdBy"];
    final updated = json["updatedBy"];
    return OrderListItem(
      id: json["_id"],
      orderNo: json["orderNo"],
      customerName: json["customer"]["name"],
      status: json["status"],
      date:       DateTime.tryParse(json["date"]?.toString() ?? '') ?? DateTime(1970),
      supplyDate: DateTime.tryParse(json["supplyDate"]?.toString() ?? '') ?? DateTime(1970),
      createdByName: created is Map ? created["name"] as String? : null,
      createdByRole: created is Map ? created["role"] as String? : null,
      updatedByName: updated is Map ? updated["name"] as String? : null,
      updatedByRole: updated is Map ? updated["role"] as String? : null,
      approvalVia:          json["approvalVia"]?.toString(),
      approvalWhatsappFrom: json["approvalWhatsappFrom"]?.toString(),
    );
  }
}
