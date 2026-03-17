class SupplierModel {
  final String? id;
  final String name;
  final String? gstin;
  final String? phone;
  final String? email;
  final String? address;
  final String? state;
  final int paymentTerms;
  final String category;
  final String status;
  final double totalPurchaseValue;
  final double totalPendingAmount;
  final String? remarks;


  SupplierModel({
    this.id,
    required this.name,
    this.gstin,
    this.phone,
    this.email,
    this.address,
    this.state,
    this.paymentTerms = 30,
    this.category = "General",
    this.status = "Active",
    this.totalPurchaseValue = 0,
    this.totalPendingAmount = 0,
    this.remarks,

  });

  /// 🔹 From JSON
  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['_id'],
      name: json['name'] ?? '',
      gstin: json['gstin'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      state: json['state'],
      paymentTerms: json['paymentTerms'] ?? 30,
      category: json['category'] ?? 'General',
      status: json['status'] ?? 'Active',
      totalPurchaseValue:
      (json['totalPurchaseValue'] ?? 0).toDouble(),
      totalPendingAmount:
      (json['totalPendingAmount'] ?? 0).toDouble(),
      remarks: json['remarks'],

    );
  }

  /// 🔹 To JSON (for create / update)
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "gstin": gstin,
      "phone": phone,
      "email": email,
      "address": address,
      "state": state,
      "paymentTerms": paymentTerms,
      "category": category,
      "status": status,
      "remarks": remarks,

    };
  }
}
