class JobListModel {
  final String id;
  final int jobNo;
  final String status;
  final String customerName;
  final String date;
  final String? machineId;

  JobListModel({
    required this.id,
    required this.jobNo,
    required this.status,
    required this.customerName,
    required this.date,
    this.machineId,
  });

  factory JobListModel.fromJson(Map<String, dynamic> json) {
    return JobListModel(
      id: json["_id"],
      jobNo: json["jobOrderNo"],
      status: json["status"],
      customerName: json["customer"]?["name"] ?? "",
      date: json["date"],
      machineId: json["machine"]?["ID"],
    );
  }
}
